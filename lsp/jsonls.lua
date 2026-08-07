-- JSON. Comes from vscode-langservers-extracted (npm). A handful of
-- schemas declared inline rather than pulling in a schemastore plugin.

return {
  settings = {
    json = {
      validate = { enable = true },
      format = { enable = false }, -- prettier handles this
      schemas = {
        { fileMatch = { "package.json" },
          url = "https://json.schemastore.org/package.json" },
        { fileMatch = { "tsconfig*.json" },
          url = "https://json.schemastore.org/tsconfig.json" },
        { fileMatch = { ".eslintrc", ".eslintrc.json" },
          url = "https://json.schemastore.org/eslintrc.json" },
        { fileMatch = { ".prettierrc", ".prettierrc.json" },
          url = "https://json.schemastore.org/prettierrc.json" },
        { fileMatch = { "*.tfstate", "*.tfstate.backup" },
          url = "https://json.schemastore.org/base.json" },
      },
    },
  },
}
