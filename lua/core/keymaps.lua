-- Keymaps. Leader comes from settings.leader.

local config = require("core.config")
local map = vim.keymap.set

-- ── Tabs ──────────────────────────────────────────────────────────────
map("n", "<Leader>n", "<Cmd>tabnext<CR>", { desc = "tab: next" })
map("n", "<Leader>p", "<Cmd>tabprevious<CR>", { desc = "tab: prev" })
map("n", "<Leader>t", "<Cmd>tabnew<CR>", { desc = "tab: new" })
map("n", "<Leader><Tab>", "<Cmd>tabnext<CR>", { desc = "tab: next" })
map("n", "<Leader>T", "<Cmd>tabclose<CR>", { desc = "tab: close" })
map("n", "<Leader>B", "<Cmd>TabsToggle<CR>", { desc = "tab: stacked sidebar / top tabline" })

-- ── Clipboard ─────────────────────────────────────────────────────────
-- settings.clipboard = "system" makes plain y/p use the system clipboard
-- instead, in which case there's nothing to map here.
if config.clipboard == "explicit" then
  local p = config.clipboard_prefix
  map({ "n", "x" }, p .. "y", '"+y', { desc = "yank to system clipboard" })
  map("n", p .. "yy", '"+yy', { desc = "yank line to system clipboard" })
  map("n", p .. "Y", '"+yg_', { desc = "yank to EOL to system clipboard" })
  -- Visual mode has no "to end of line" motion to apply, so Y here is just
  -- y. Mapped anyway: without it, prefix+Y falls through to plain Y and
  -- yanks to the unnamed register, which looks like it worked.
  map("x", p .. "Y", '"+y', { desc = "yank selection to system clipboard" })
  map({ "n", "x" }, p .. "p", '"+p', { desc = "paste from system clipboard" })
  map({ "n", "x" }, p .. "P", '"+P', { desc = "paste before from system clipboard" })
end

-- ── File explorer ─────────────────────────────────────────────────────
map("n", "<C-n>", "<Cmd>Oil<CR>", { desc = "file explorer" })

-- ── Pickers ───────────────────────────────────────────────────────────
local function fzf(fn, opts)
  return function()
    local ok, m = pcall(require, "fzf-lua")
    if ok then m[fn](opts) else vim.notify("fzf-lua not available", vim.log.levels.WARN) end
  end
end
map("n", "<Leader>f", fzf("files"), { desc = "find files" })
map("n", "<Leader>g", fzf("live_grep"), { desc = "grep project" })
map("n", "<Leader>b", fzf("buffers"), { desc = "buffers" })
map("n", "<Leader>d", fzf("diagnostics_document"), { desc = "diagnostics: buffer" })
map("n", "<Leader>D", fzf("diagnostics_workspace"), { desc = "diagnostics: project" })
map("n", "<Leader>s", fzf("lsp_document_symbols"), { desc = "symbols: buffer" })
map("n", "<Leader>S", fzf("lsp_live_workspace_symbols"), { desc = "symbols: project" })
map("n", "<Leader>/", fzf("blines"), { desc = "search in buffer" })
map("n", "<Leader>h", fzf("helptags"), { desc = "help" })
map("n", "<Leader>r", fzf("resume"), { desc = "resume last picker" })
map("n", "<Leader>*", fzf("grep_cword"), { desc = "grep word under cursor" })

-- ── Windows ───────────────────────────────────────────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "window: left" })
map("n", "<C-j>", "<C-w>j", { desc = "window: down" })
map("n", "<C-k>", "<C-w>k", { desc = "window: up" })
map("n", "<C-l>", "<C-w>l", { desc = "window: right" })
map("n", "<Leader>-", "<Cmd>split<CR>", { desc = "split horizontal" })
map("n", "<Leader>|", "<Cmd>vsplit<CR>", { desc = "split vertical" })
map("n", "<Leader>=", "<C-w>=", { desc = "equalise splits" })

-- Note: <C-h/j/k/l> are NOT mapped in terminal mode on purpose. <C-l> is
-- clear-screen and <C-k> is kill-line in every common shell; stealing
-- them costs more than it saves. Escape terminal mode first.

-- ── Git ───────────────────────────────────────────────────────────────
-- Hunk-level bindings are set per-buffer by gitsigns (see plugins.lua).
map("n", "<Leader>vl", fzf("git_commits"), { desc = "git log" })
map("n", "<Leader>vs", fzf("git_status"), { desc = "git status" })
map("n", "<Leader>vb", fzf("git_branches"), { desc = "git branches" })

-- ── Quickfix ──────────────────────────────────────────────────────────
map("n", "<Leader>q", "<Cmd>copen<CR>", { desc = "quickfix open" })
map("n", "<Leader>Q", "<Cmd>cclose<CR>", { desc = "quickfix close" })
-- ]q [q ]l [l ]d [d are native in 0.11+; ]c [c come from gitsigns

-- ── Small comforts ────────────────────────────────────────────────────
map("n", "<Esc>", "<Cmd>nohlsearch<CR>", { desc = "clear search highlight" })
map("n", "<Leader>w", "<Cmd>write<CR>", { desc = "write" })
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })
map("x", "<", "<gv", { desc = "outdent, keep selection" })
map("x", ">", ">gv", { desc = "indent, keep selection" })
map("x", "J", ":move '>+1<CR>gv=gv", { silent = true, desc = "move selection down" })
map("x", "K", ":move '<-2<CR>gv=gv", { silent = true, desc = "move selection up" })

-- Commenting is native since 0.10: gcc, gc{motion}, gbc. Nothing to map.
