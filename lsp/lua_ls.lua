-- Lua, scoped to editing this config. Neovim 0.11+ can tell lua_ls where
-- its own runtime files are, so vim.* resolves without the
-- neodev/lazydev plugin.

return {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = {
        checkThirdParty = false,
        library = vim.api.nvim_get_runtime_file("lua", true),
      },
      diagnostics = { globals = { "vim" } },
      telemetry = { enable = false },
      hint = { enable = true },
      format = { enable = false }, -- stylua
    },
  },
}
