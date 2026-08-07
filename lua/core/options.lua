-- Editor options.

local config = require("core.config")
local o = vim.opt

-- ── Indentation ───────────────────────────────────────────────────────
-- Global default from settings.indent. Per-language overrides live in
-- after/ftplugin/ — that's the native mechanism, and it's why there's no
-- indent-detection plugin here.
o.tabstop = config.indent.width
o.softtabstop = 0
o.shiftwidth = config.indent.width
o.expandtab = config.indent.expandtab
o.autoindent = true
o.smartindent = true
o.shiftround = true
o.breakindent = true

-- ── UI ────────────────────────────────────────────────────────────────
o.number = true
o.ruler = true
o.cursorline = true
o.signcolumn = "yes"      -- stops the gutter jittering as diagnostics arrive
o.showmatch = false
o.splitbelow = true
o.splitright = true
o.scrolloff = 4
o.sidescrolloff = 8
o.laststatus = 3          -- one statusline for all splits
o.showmode = false        -- the statusline shows it
o.winborder = "rounded"   -- default border for all floats
o.mouse = "a"
o.list = true
o.listchars = { tab = "| ", trail = "·", nbsp = "␣", extends = "›", precedes = "‹" }

-- ── Files, undo, backup ───────────────────────────────────────────────
-- Under stdpath("state"), not /tmp: macOS and many Linux distros clear
-- /tmp periodically, which silently discards undo history.
local state = vim.fn.stdpath("state")
o.backup = true
o.backupdir = state .. "/backup//"
o.directory = state .. "/swap//"
o.undofile = true
o.undodir = state .. "/undo//"
o.undolevels = 10000
o.autoread = true
o.confirm = true
o.hidden = true

for _, dir in ipairs({ "/backup", "/swap", "/undo" }) do
  vim.fn.mkdir(state .. dir, "p")
end

-- ── Completion ────────────────────────────────────────────────────────
-- 'popup' shows LSP docs beside the menu; 'fuzzy' makes the native menu
-- match subsequences, which is most of what a completion plugin adds.
o.completeopt = { "menuone", "noselect", "popup", "fuzzy" }
o.pumheight = 12
o.wildmode = "longest:full,full"
o.wildoptions = "pum,fuzzy"

-- ── Search ────────────────────────────────────────────────────────────
o.ignorecase = true
o.smartcase = true
o.hlsearch = true
o.incsearch = true
o.inccommand = "split"    -- live preview of :s///

if vim.fn.executable("rg") == 1 then
  o.grepprg = "rg --vimgrep --smart-case --hidden --glob '!.git'"
  o.grepformat = "%f:%l:%c:%m"
end

-- ── Timing ────────────────────────────────────────────────────────────
-- 300ms is what makes a printable leader feel instant rather than laggy.
-- At the 1000ms default, every bare leader press feels like a hang.
o.timeoutlen = 300
o.ttimeoutlen = 10
o.updatetime = 250

-- ── Misc ──────────────────────────────────────────────────────────────
-- clipboard=unnamedplus only when settings.clipboard is "system";
-- "explicit" keeps y/p register-local with prefixed system variants.
o.clipboard = config.clipboard == "system" and "unnamedplus" or ""
o.spelllang = config.spell
o.encoding = "utf-8"
o.fileencoding = "utf-8"
o.jumpoptions = "stack,view"
o.virtualedit = "block"
o.diffopt:append({ "linematch:60" })
o.foldlevel = 99
o.foldtext = ""
o.shortmess:append("cI")

-- Yank highlight — native, no plugin needed.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("core.yank", { clear = true }),
  callback = function() vim.hl.on_yank({ timeout = 150 }) end,
})

-- Reopen files at the last cursor position.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("core.lastpos", { clear = true }),
  callback = function(ev)
    if vim.bo[ev.buf].filetype == "gitcommit" then return end
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
