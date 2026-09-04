-- :Reload — re-read lua/settings.lua and the core modules without
-- restarting.
--
-- Lua caches every module in package.loaded, so editing settings.lua does
-- nothing to a running Neovim until the cache is dropped. This drops the
-- safe subset and requires it back.
--
-- ┌────────────────────────────────────────────────────────────────────┐
-- │  Deliberately NOT reloaded, because a restart is cheaper than the  │
-- │  failure mode:                                                     │
-- │                                                                    │
-- │    core.plugins   vim.pack.add() would re-run against plugins that │
-- │                   are already loaded                               │
-- │    core.lsp       vim.lsp.enable() would restart every client and   │
-- │                   lose their state mid-edit                        │
-- │    core.shell     caches resolved shell paths that core.terminal   │
-- │                   holds live jobs against                          │
-- │    core.terminal  its module locals ARE the terminal slots; a new  │
-- │                   incarnation can't see the running jobs           │
-- │                                                                    │
-- │  Change any of those four and quit properly.                       │
-- └────────────────────────────────────────────────────────────────────┘
--
-- A module that owns windows, buffers or jobs can define M.unload(). It's
-- called before that module is discarded, so it can tear down what the
-- next incarnation would otherwise be unable to see — which is how you
-- end up with two sidebars instead of one.

-- Dropped from the cache. settings/config are listed but not required
-- back directly: the modules below pull them in, freshly, on their own.
local purge = {
  "settings",
  "settings_local",
  "core.config",
  "core.options",
  "core.keymaps",
  "core.termcolors",
  "core.theme",
  "core.claude",
  "core.statusline",
  "core.tabs",
  "core.sidebar",
  "core.stack",
  "core.iterm",
  "core.format",
  -- Not in `load` below: nothing requires it at startup, $EDITOR pulls it
  -- in on demand. It still has to be purged, or an nvim that has run one
  -- git commit keeps the old copy for the rest of its life.
  "core.remote",
  -- This file. Without it :Reload forever runs the copy loaded at STARTUP,
  -- which means the two lists here are frozen at whatever they said when
  -- the session began — so adding a module to them and reloading picks up
  -- every OTHER changed file but never the new module itself. That failure
  -- is quiet and confusing: keymaps.lua comes back naming commands that the
  -- module which defines them was never loaded to create.
  "core.reload",
}

-- Required back, in dependency order. core.sidebar is absent on purpose:
-- core.tabs pulls it in, and only when the sidebar is the active view.
local load = {
  "core.options",
  "core.keymaps",
  -- Before core.theme: it installs the ColorScheme hook that builds the
  -- terminal palette, and core.theme applies a colorscheme as it loads.
  "core.termcolors",
  "core.theme",
  -- Before core.statusline, which requires it.
  "core.claude",
  "core.statusline",
  "core.tabs",
  -- After core.tabs: both read its model, and core.stack re-adopts the
  -- stacks the previous incarnation left tagged.
  "core.stack",
  "core.iterm",
  "core.format",
  -- Last, and safe to re-run: nvim_create_user_command overwrites :Reload
  -- rather than erroring, and the callback currently executing keeps its
  -- own upvalues. If this require fails, the old command simply survives.
  "core.reload",
}

-- core.options is nothing but :set, and :set writes to the *current* window
-- and buffer. Reload from the sidebar and it would stamp number, list and
-- signcolumn onto it — ensure_win() only dresses a sidebar window it creates,
-- so those stick until the sidebar is closed and reopened. Stand in a normal
-- file window instead, if the tabpage has one.
local function normal_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "" and vim.bo[buf].modifiable then
      return win
    end
  end
  return nil
end

-- Only core.options gets that treatment: core.tabs and core.sidebar do their
-- own window juggling, and running them under nvim_win_call would change what
-- they think the current window is.
local function load_module(name)
  local win = name == "core.options" and normal_win() or nil
  return xpcall(function()
    if win then
      vim.api.nvim_win_call(win, function() require(name) end)
    else
      require(name)
    end
  end, debug.traceback)
end

vim.api.nvim_create_user_command("Reload", function()
  for _, name in ipairs(purge) do
    local mod = package.loaded[name]
    if type(mod) == "table" and type(mod.unload) == "function" then
      pcall(mod.unload)
    end
  end

  for _, name in ipairs(purge) do
    package.loaded[name] = nil
  end

  local failed = {}
  for _, name in ipairs(load) do
    local ok, err = load_module(name)
    if not ok then
      -- With the traceback, "E21 at vim/_core/options:713" is followed by the
      -- line in our own config that asked for it. Indent every line of it so
      -- several failed modules stay tellable apart.
      local trace = tostring(err):gsub("\n", "\n    ")
      table.insert(failed, ("  %s\n    %s"):format(name, trace))
    end
  end

  if #failed > 0 then
    -- Partially reloaded is a real state, and a confusing one to debug
    -- from a one-line message. Name every module that didn't come back.
    vim.notify(
      ("reload failed (%d module(s)) — restart to be sure:\n%s")
        :format(#failed, table.concat(failed, "\n")),
      vim.log.levels.ERROR
    )
  else
    vim.notify("config reloaded", vim.log.levels.INFO)
  end
end, { desc = "reload settings.lua and the core modules" })
