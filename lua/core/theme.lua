-- Colorschemes: a list you cycle, and automatic light/dark following the OS.
--
-- The light/dark chain, with no polling and no plugin doing the switching:
--
--   OS appearance setting (incl. its sunrise/sunset schedule)
--     -> terminal swaps its palette and emits OSC 11
--       -> Neovim reads the response and flips 'background' itself
--         -> the autocmd below reloads the current colorscheme
--
-- ╭─ THE ONE RULE ────────────────────────────────────────────────────╮
-- │ Never `set background=...` in your config. Assigning it           │
-- │ explicitly makes Neovim delete its own OSC 11 detection autocmd,  │
-- │ and the whole chain above goes dead silently.                     │
-- ╰───────────────────────────────────────────────────────────────────╯
--
-- Needs a terminal that reports its background: Ghostty, WezTerm, kitty,
-- Alacritty. Under tmux also set `allow-passthrough on`. For terminals
-- that stay silent, see the fallback note at the bottom.
--
-- Two kinds of colorscheme, and the difference matters:
--
--   options = {...}   set as vim.g.<key> BEFORE :colorscheme. The sainnhe
--                     family (gruvbox-material) is configured this way.
--   setup   = {...}   passed to require(module).setup(). Lua-configured
--                     themes (monokai-nightasty) need this, and need it
--                     before :colorscheme, not after.

local config = require("core.config")
local theme = config.theme
local themes = theme.themes or {}

local M = {}

-- Where the cycled choice is remembered between sessions. Under
-- stdpath("state") rather than the repo: it's this machine's preference,
-- not configuration to commit.
local state_file = vim.fs.joinpath(vim.fn.stdpath("state"), "theme")

local current = 1

local function index_of(name)
  for i, t in ipairs(themes) do
    if t.colorscheme == name then return i end
  end
end

local function remembered()
  if not theme.remember then return nil end
  local ok, lines = pcall(vim.fn.readfile, state_file)
  if not ok or not lines or not lines[1] then return nil end
  -- By name, not index: reordering the list in settings.lua shouldn't
  -- silently hand you a different theme.
  return index_of(lines[1])
end

local function remember(index)
  if not theme.remember then return end
  pcall(vim.fn.writefile, { themes[index].colorscheme }, state_file)
end

--- Which colorscheme name to use for this background. Most modern themes
--- read 'background' themselves, so light/dark are only needed for the
--- ones that ship as two separately-named schemes.
local function name_for(t, background)
  if background == "light" and t.light then return t.light end
  if background == "dark" and t.dark then return t.dark end
  return t.colorscheme
end

local function apply()
  local t = themes[current]
  if not t then return end

  for key, value in pairs(t.options or {}) do
    vim.g[key] = value
  end

  -- The sainnhe convention. Harmless on themes that don't read it; those
  -- express transparency in their own `setup` table instead.
  if theme.transparent then
    vim.g[t.colorscheme:gsub("%-", "_") .. "_transparent_background"] = 1
  end

  if t.setup then
    local ok, mod = pcall(require, t.module or t.colorscheme)
    if ok and type(mod) == "table" and type(mod.setup) == "function" then
      pcall(mod.setup, t.setup)
    else
      vim.notify(
        ("theme %q has a `setup` table but require(%q) has no setup()"):
          format(t.colorscheme, t.module or t.colorscheme),
        vim.log.levels.WARN
      )
    end
  end

  local name = name_for(t, vim.o.background)
  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok then
    vim.notify(
      ("colorscheme %q failed to load (%s).\nCheck theme.themes in lua/settings.lua."):format(name, err),
      vim.log.levels.WARN
    )
    pcall(vim.cmd.colorscheme, "default")
  end
end

--- Switch to a theme by list index, remembering it.
function M.set(index, notify)
  if not themes[index] then return end
  current = index
  apply()
  remember(index)
  if notify then
    vim.notify(("%s  (%d/%d)"):format(themes[index].colorscheme, index, #themes))
  end
end

--- The next theme in the list, wrapping.
function M.next()
  M.set(current % #themes + 1, true)
end

function M.current()
  return themes[current]
end

--- Called by :Reload before this module is discarded, so the freshly
--- required copy starts from what's actually on screen rather than
--- resetting you to the first entry in the list.
function M.unload()
  remember(current)
end

--- Clone any theme added to settings.lua since startup.
---
--- core.plugins runs once, and :Reload skips it on purpose — re-running
--- vim.pack.add over already-loaded plugins, and every plugin's setup()
--- with it, is not worth the risk. A colorscheme is inert until applied,
--- though, so fetching just those is safe, and it's what makes "add a
--- theme, :Reload" work instead of "add a theme, quit, relaunch".
local function ensure_installed()
  local missing = {}
  for _, t in ipairs(themes) do
    if t.plugin and #vim.fn.getcompletion(t.colorscheme, "color") == 0 then
      table.insert(missing, t.plugin)
    end
  end
  if #missing == 0 then return end
  local ok, err = pcall(vim.pack.add, missing)
  if not ok then
    vim.notify(("could not install %d theme(s): %s"):format(#missing, tostring(err)),
      vim.log.levels.WARN)
  end
end

if #themes == 0 then
  vim.notify("theme.themes is empty in lua/settings.lua — using the default colorscheme",
    vim.log.levels.WARN)
else
  ensure_installed()
  current = remembered() or 1
  apply()
end

if theme.follow_system then
  vim.api.nvim_create_autocmd("OptionSet", {
    group = vim.api.nvim_create_augroup("core.theme", { clear = true }),
    pattern = "background",
    callback = apply,
  })
end

-- ── Commands ──────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("ThemesToggle", function()
  M.next()
end, { desc = "Cycle to the next colorscheme in theme.themes" })

vim.api.nvim_create_user_command("Theme", function(o)
  if o.args == "" then
    vim.notify(("%s  (%d/%d)"):format(themes[current].colorscheme, current, #themes))
    return
  end
  local i = index_of(o.args)
  if not i then
    vim.notify(("no such theme %q in theme.themes"):format(o.args), vim.log.levels.WARN)
    return
  end
  M.set(i, true)
end, {
  nargs = "?",
  complete = function()
    return vim.tbl_map(function(t) return t.colorscheme end, themes)
  end,
  desc = "Show or select a colorscheme by name",
})

-- Manual light/dark override, for when the room disagrees with the clock.
-- Note this assigns 'background', which stops OSC 11 following until
-- restart — that's the documented tradeoff, not a bug.
vim.api.nvim_create_user_command("ThemeToggle", function()
  vim.o.background = vim.o.background == "dark" and "light" or "dark"
  local suffix = theme.follow_system and " (OS following now off until restart)" or ""
  vim.notify("background = " .. vim.o.background .. suffix)
end, { desc = "Toggle light/dark manually" })

vim.keymap.set("n", "<Leader>tt", "<Cmd>ThemeToggle<CR>", { desc = "toggle light/dark" })
vim.keymap.set("n", "<Leader>tn", "<Cmd>ThemesToggle<CR>", { desc = "next colorscheme" })

return M

-- ── If your terminal doesn't speak OSC 11 ─────────────────────────────
-- Add f-person/auto-dark-mode.nvim to settings.extra_plugins, then in
-- lua/settings_local.lua or a file of your own:
--
--   require("auto-dark-mode").setup({
--     update_interval = 3000,
--     fallback = "dark",
--     set_dark_mode  = function() vim.o.background = "dark"  end,
--     set_light_mode = function() vim.o.background = "light" end,
--   })
--
-- It polls the OS every few seconds. It works; it just isn't free.
