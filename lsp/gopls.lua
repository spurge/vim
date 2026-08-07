-- Go. Your old config had eleven vim-go highlight flags; treesitter
-- covers all of that now, so this is purely about gopls behaviour.

return {
  settings = {
    gopls = {
      gofumpt = true,
      usePlaceholders = true,
      completeUnimported = true,
      staticcheck = true,
      semanticTokens = true,
      analyses = {
        unusedparams = true,
        unusedwrite = true,
        nilness = true,
        shadow = true,
        useany = true,
      },
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
      codelenses = { generate = true, test = true, tidy = true },
      directoryFilters = { "-.git", "-node_modules", "-vendor" },
    },
  },
}
