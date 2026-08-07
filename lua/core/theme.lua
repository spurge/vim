-- Colorscheme, and automatic light/dark following the OS.
--
-- The chain, with no polling and no plugin doing the switching:
--
--   OS appearance setting (incl. its sunrise/sunset schedule)
--     -> terminal swaps its palette and emits OSC 11
--       -> Neovim reads the response and flips 'background' itself
--         -> the autocmd below reloads the colorscheme
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

local config = require("core.config")
local theme = config.theme

-- Theme-specific globals, from settings.theme.options.
for key, value in pairs(theme.options or {}) do
  vim.g[key] = value
end
if theme.transparent then
  vim.g[theme.colorscheme:gsub("%-", "_") .. "_transparent_background"] = 1
end

--- Pick the right colorscheme name for the current background.
--- Most modern themes read 'background' themselves, so settings.theme
--- .light/.dark are only needed for themes that ship as separate names.
local function name_for(background)
  if background == "light" and theme.light then return theme.light end
  if background == "dark" and theme.dark then return theme.dark end
  return theme.colorscheme
end

local function apply()
  local name = name_for(vim.o.background)
  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok then
    vim.notify(
      ("colorscheme %q failed to load (%s).\nCheck settings.theme in lua/settings.lua."):format(name, err),
      vim.log.levels.WARN
    )
    pcall(vim.cmd.colorscheme, "default")
  end
end

apply()

if theme.follow_system then
  vim.api.nvim_create_autocmd("OptionSet", {
    group = vim.api.nvim_create_augroup("core.theme", { clear = true }),
    pattern = "background",
    callback = apply,
  })
end

-- Manual override, for when the room disagrees with the clock. Note this
-- assigns 'background', which stops OSC 11 following until restart —
-- that's the documented tradeoff, not a bug.
vim.api.nvim_create_user_command("ThemeToggle", function()
  vim.o.background = vim.o.background == "dark" and "light" or "dark"
  local suffix = theme.follow_system and " (OS following now off until restart)" or ""
  vim.notify("background = " .. vim.o.background .. suffix)
end, { desc = "Toggle light/dark manually" })

vim.keymap.set("n", "<Leader>tt", "<Cmd>ThemeToggle<CR>", { desc = "toggle light/dark" })

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
