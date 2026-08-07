-- YAML. yaml-language-server has SchemaStore support built in, so the
-- b0o/schemastore.nvim plugin is unnecessary — one less dependency.

return {
  settings = {
    yaml = {
      schemaStore = { enable = true, url = "https://www.schemastore.org/api/json/catalog.json" },
      validate = true,
      format = { enable = false }, -- prettier handles this, see format.lua
      keyOrdering = false,
      -- Schemas the store won't infer from filename alone.
      schemas = {
        ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
        ["https://json.schemastore.org/github-action.json"] = "/.github/action.{yml,yaml}",
        ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "*docker-compose*.{yml,yaml}",
        ["https://json.schemastore.org/gitlab-ci.json"] = "*gitlab-ci*.{yml,yaml}",
      },
    },
    redhat = { telemetry = { enabled = false } },
  },
}
