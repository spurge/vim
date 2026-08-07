-- A small, hand-rolled Neovim configuration.
--
-- Eight plugins, no framework. Requires Neovim 0.12+ for vim.pack (the
-- built-in plugin manager) and native lsp/ directory discovery.
--
-- ┌────────────────────────────────────────────────────────────────────┐
-- │  Everything you'd want to change lives in lua/settings.lua.        │
-- │  You should not need to edit any file under lua/core/.             │
-- └────────────────────────────────────────────────────────────────────┘

if vim.fn.has("nvim-0.12") == 0 then
  local msg = ("This config needs Neovim 0.12+ (found %s)"):format(tostring(vim.version()))
  vim.notify(msg, vim.log.levels.ERROR)
  return
end

local config = require("core.config")

-- Leader must be set before any mapping is defined.
vim.g.mapleader = config.leader
vim.g.maplocalleader = config.localleader

require("core.plugins")     -- vim.pack.add + setup calls
require("core.options")     -- editor options
require("core.keymaps")     -- keymaps
require("core.theme")       -- colorscheme + OS light/dark following
require("core.shell")       -- which shell for :terminal vs for system()
require("core.lsp")         -- native vim.lsp
require("core.terminal")    -- terminal mode escape, nesting, agent splits
require("core.format")      -- format on save
require("core.statusline")  -- native statusline
require("core.tabs")        -- tabline / stacked sidebar, one model both ways
require("core.reload")      -- :Reload, for settings changes without a restart
