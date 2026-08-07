-- Plugins, via Neovim 0.12's built-in vim.pack.
--
-- Nine, plus whatever you list in settings.extra_plugins. Each one exists
-- because there is no native equivalent; the comment says what it replaces.
--
-- vim.pack writes a lockfile — commit it. Update with :lua vim.pack.update()

local config = require("core.config")

local plugins = {
  -- Theme, from settings.theme.plugin
  config.theme.plugin,

  -- Used as a DATA SOURCE only. It ships lsp/*.lua specs that
  -- vim.lsp.enable() reads directly; we never call lspconfig.setup().
  "https://github.com/neovim/nvim-lspconfig",

  -- Grammars + highlighting. Replaces per-language syntax plugins.
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },

  -- Directory-as-buffer file explorer. Replaces netrw/nerdtree/ranger.
  "https://github.com/stevearc/oil.nvim",

  -- Fuzzy finder. The one plugin here with no native peer.
  "https://github.com/ibhagwan/fzf-lua",

  -- Git signs in the gutter, hunk staging.
  "https://github.com/lewis6991/gitsigns.nvim",

  -- Formatting. Runs before the write, in-process, preserving the cursor.
  "https://github.com/stevearc/conform.nvim",

  -- Surround: ys / cs / ds, remapped below to tpope's grammar.
  "https://github.com/echasnovski/mini.surround",
}

vim.list_extend(plugins, config.extra_plugins or {})
vim.pack.add(plugins)

-- Deliberately absent, because Neovim now does it natively:
--   plugin manager      -> vim.pack
--   LSP client wrapper  -> vim.lsp
--   completion engine   -> vim.lsp.completion, autotrigger
--   linting framework   -> vim.diagnostic
--   statusline plugin   -> lua/core/statusline.lua, ~110 lines
--   indent guides       -> 'list' + 'listchars'
--   commenting          -> gcc / gc{motion} / gbc, built in since 0.10
--   indent detection    -> after/ftplugin/*.lua, explicit beats guessing
--   LSP installer       -> your system package manager (see Brewfile)

-- ── treesitter ────────────────────────────────────────────────────────
local ok_ts, ts = pcall(require, "nvim-treesitter")
if ok_ts then
  pcall(ts.install, config.parsers())

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("core.treesitter", { clear = true }),
    callback = function(ev)
      if not pcall(vim.treesitter.start, ev.buf) then
        return -- no parser for this filetype; native syntax stays
      end
      vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
      vim.wo.foldmethod = "expr"
    end,
  })
end

-- ── oil ───────────────────────────────────────────────────────────────
require("oil").setup({
  default_file_explorer = true,
  view_options = { show_hidden = true },
  keymaps = {
    ["<C-n>"] = { "actions.close", mode = "n" },
    ["q"] = { "actions.close", mode = "n" },
    ["-"] = { "actions.parent", mode = "n" },
  },
})

-- ── fzf-lua ───────────────────────────────────────────────────────────
require("fzf-lua").setup({
  "border-fused",
  winopts = { height = 0.8, width = 0.9, preview = { layout = "vertical" } },
  fzf_colors = true, -- inherit the colorscheme, including on light/dark flip
})

-- ── gitsigns ──────────────────────────────────────────────────────────
require("gitsigns").setup({
  signs = {
    add = { text = "+" },
    change = { text = "~" },
    delete = { text = "_" },
    topdelete = { text = "‾" },
    changedelete = { text = "~" },
  },
  on_attach = function(buf)
    local gs = require("gitsigns")
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
    end
    map("n", "]c", function() gs.nav_hunk("next") end, "next hunk")
    map("n", "[c", function() gs.nav_hunk("prev") end, "prev hunk")
    map("n", "<Leader>hp", gs.preview_hunk, "preview hunk")
    map("n", "<Leader>hs", gs.stage_hunk, "stage hunk")
    map("n", "<Leader>hr", gs.reset_hunk, "reset hunk")
    map("n", "<Leader>hb", function() gs.blame_line({ full = true }) end, "blame line")
  end,
})

-- ── mini.surround ─────────────────────────────────────────────────────
-- Remapped to tpope's grammar, so ysiw" / cs"' / ds" work as muscle
-- memory expects.
require("mini.surround").setup({
  mappings = {
    add = "ys",
    delete = "ds",
    replace = "cs",
    find = "",
    find_left = "",
    highlight = "",
    update_n_lines = "",
  },
  search_method = "cover_or_next",
})
-- mini.surround claims `ys` in visual mode too, which shadows nothing
-- useful but isn't tpope's behaviour. pcall because the mapping only
-- exists if setup succeeded.
pcall(vim.keymap.del, "x", "ys")
vim.keymap.set("x", "S", [[:<C-u>lua MiniSurround.add('visual')<CR>]],
  { silent = true, desc = "surround selection" })
