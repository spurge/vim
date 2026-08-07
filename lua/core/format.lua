-- Formatting on save, via conform.
--
-- Which formatters run is derived from settings.languages — see
-- lua/core/languages.lua. Turn the whole thing off with
-- settings.format_on_save = false.

local config = require("core.config")
local ok, conform = pcall(require, "conform")
if not ok then return end

local util = require("conform.util")

conform.setup({
  formatters_by_ft = config.formatters(),

  formatters = {
    -- conform's terraform_fmt won't touch terragrunt.hcl; terragrunt has
    -- its own subcommand for it.
    terragrunt_fmt = {
      command = "terragrunt",
      args = { "hcl", "fmt", "--file", "$FILENAME" },
      stdin = false,
      cwd = util.root_file({ "root.hcl", "terragrunt.hcl", ".git" }),
    },
    shfmt = {
      prepend_args = { "-i", tostring(config.indent.width), "-ci", "-bn" },
    },
  },

  format_on_save = config.format_on_save and function(bufnr)
    if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
      return
    end
    -- Never reformat code you don't own.
    local path = vim.api.nvim_buf_get_name(bufnr)
    for _, skip in ipairs({ "/node_modules/", "/vendor/", "/%.terraform/", "/%.git/" }) do
      if path:match(skip) then return end
    end
    return { timeout_ms = 3000, lsp_format = "fallback" }
  end or nil,

  default_format_opts = { lsp_format = "fallback" },
})

vim.keymap.set({ "n", "x" }, "<Leader>F", function()
  conform.format({ async = true, lsp_format = "fallback" })
end, { desc = "format buffer/selection" })

vim.api.nvim_create_user_command("FormatOff", function(args)
  if args.bang then
    vim.b.disable_autoformat = true
    vim.notify("format on save: off (this buffer)")
  else
    vim.g.disable_autoformat = true
    vim.notify("format on save: off (global)")
  end
end, { bang = true, desc = "Disable format on save" })

vim.api.nvim_create_user_command("FormatOn", function()
  vim.b.disable_autoformat = false
  vim.g.disable_autoformat = false
  vim.notify("format on save: on")
end, { desc = "Enable format on save" })

vim.api.nvim_create_user_command("FormatInfo", function()
  local names = vim.tbl_map(function(f) return f.name end, conform.list_formatters(0))
  vim.notify(("%s: %s"):format(
    vim.bo.filetype,
    #names > 0 and table.concat(names, ", ") or "none (LSP fallback)"
  ))
end, { desc = "Show formatters for this buffer" })
