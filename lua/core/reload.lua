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
  "core.theme",
  "core.statusline",
  "core.tabs",
  "core.sidebar",
  "core.format",
  -- Not in `load` below: nothing requires it at startup, $EDITOR pulls it
  -- in on demand. It still has to be purged, or an nvim that has run one
  -- git commit keeps the old copy for the rest of its life.
  "core.remote",
}

-- Required back, in dependency order. core.sidebar is absent on purpose:
-- core.tabs pulls it in, and only when the sidebar is the active view.
local load = {
  "core.options",
  "core.keymaps",
  "core.theme",
  "core.statusline",
  "core.tabs",
  "core.format",
}

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
    local ok, err = pcall(require, name)
    if not ok then
      table.insert(failed, ("  %s\n    %s"):format(name, tostring(err)))
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
