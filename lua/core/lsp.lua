-- LSP, entirely native.
--
-- There is no lspconfig.setup() call in this config. Since 0.11, Neovim
-- auto-discovers lsp/<name>.lua from every directory on the runtimepath,
-- and nvim-lspconfig v2 ships exactly those files. So it acts as a
-- database of sane cmd/root_markers/settings, and vim.lsp.enable() reads
-- it. This repo's own lsp/ sits later on the runtimepath, so files there
-- merge over the top — that's how awkward servers get fixed without
-- forking anything.
--
-- Which servers start is derived from settings.languages. Servers are
-- installed with your system package manager, not from inside the
-- editor: `make verify` reports what's missing.

local config = require("core.config")

-- ── Defaults applied to every server ──────────────────────────────────
vim.lsp.config("*", {
  root_markers = { ".git" },
  capabilities = {
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = true,
          resolveSupport = {
            properties = { "documentation", "detail", "additionalTextEdits" },
          },
        },
      },
    },
    workspace = {
      didChangeWatchedFiles = { dynamicRegistration = true },
    },
  },
})

vim.lsp.enable(config.servers())

-- ── Diagnostics ───────────────────────────────────────────────────────
vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  virtual_text = {
    current_line = true, -- only the line you're on, so it stays quiet
    prefix = "»",
    spacing = 2,
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "e»",
      [vim.diagnostic.severity.WARN] = "w»",
      [vim.diagnostic.severity.INFO] = "i»",
      [vim.diagnostic.severity.HINT] = "h»",
    },
  },
  float = { border = "rounded", source = true, header = "" },
  jump = { float = true },
})

-- ── On attach ─────────────────────────────────────────────────────────
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("core.lsp", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then return end
    local buf = ev.buf

    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = "lsp: " .. desc })
    end

    -- Native autocompletion. This is why there's no completion plugin.
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, buf, { autotrigger = true })
      -- <C-Space> is the terminal escape by default, so completion is on
      -- <C-e> to avoid the collision.
      map("i", "<C-e>", function() vim.lsp.completion.get() end, "complete")
    end

    if client:supports_method("textDocument/inlayHint") then
      map("n", "<Leader>i", function()
        local on = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
        vim.lsp.inlay_hint.enable(not on, { bufnr = buf })
      end, "toggle inlay hints")
    end

    -- Highlight other occurrences of the symbol under the cursor.
    if client:supports_method("textDocument/documentHighlight") then
      local hl = vim.api.nvim_create_augroup("core.lsp.highlight." .. buf, { clear = true })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = hl, buffer = buf, callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = hl, buffer = buf, callback = vim.lsp.buf.clear_references,
      })
    end

    -- ── Follow references and inline docs ─────────────────────────────
    -- 0.11+ already provides, with no configuration:
    --
    --   K     hover documentation        grn   rename
    --   grr   references                 gra   code action
    --   gri   implementations            grt   type definition
    --   gO    document symbols           <C-s> signature help (insert)
    --   ]d [d next/prev diagnostic       <C-]> / <C-t> tag-style jump
    --
    -- Only the gaps are filled in below.
    map("n", "gd", vim.lsp.buf.definition, "definition")
    map("n", "gD", vim.lsp.buf.declaration, "declaration")
    map("n", "<Leader>k", vim.diagnostic.open_float, "line diagnostics")

    -- grr and gri default to the quickfix list. A picker with a preview
    -- is better for actually following references.
    local ok, fzf = pcall(require, "fzf-lua")
    if ok then
      map("n", "grr", fzf.lsp_references, "references")
      map("n", "gri", fzf.lsp_implementations, "implementations")
      map("n", "grt", fzf.lsp_typedefs, "type definition")
      map("n", "gO", fzf.lsp_document_symbols, "document symbols")
    end

    map("n", "<Leader>gd", function()
      vim.cmd.vsplit()
      vim.lsp.buf.definition()
    end, "definition in split")
  end,
})

-- Stop orphaned servers when their last buffer closes, so a long session
-- across many repos doesn't accumulate a dozen language server processes.
vim.api.nvim_create_autocmd("LspDetach", {
  group = vim.api.nvim_create_augroup("core.lsp.detach", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and vim.tbl_isempty(client.attached_buffers or {}) then
      vim.defer_fn(function()
        if client and not client:is_stopped()
          and vim.tbl_isempty(client.attached_buffers or {}) then
          client:stop()
        end
      end, 5000)
    end
  end,
})

vim.keymap.set("n", "<Leader>li", "<Cmd>checkhealth vim.lsp<CR>", { desc = "lsp: health" })
