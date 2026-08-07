-- Language registry.
--
-- One entry per language. Everything downstream derives from this: which
-- LSP servers start (lua/core/lsp.lua), which treesitter parsers install
-- (lua/core/plugins.lua), which formatters register (lua/core/format.lua),
-- and what `make verify` looks for on PATH (scripts/verify.lua).
--
-- To add a language: add an entry here, then add its name to
-- `languages` in lua/settings.lua. Nothing else.
--
-- Fields, all optional:
--   servers     LSP server names. Must match an lsp/<name>.lua on the
--               runtimepath — nvim-lspconfig ships most of them; local
--               overrides live in this repo's lsp/ directory.
--   parsers     treesitter parser names.
--   formatters  filetype -> formatter list, passed to conform.
--   tools       { binary, purpose, install hint } for verify.
--   optional    tools that verify reports as a warning, not a failure.

return {
  go = {
    servers = { "gopls" },
    parsers = { "go", "gomod", "gosum", "gowork", "gotmpl" },
    formatters = {
      go = { "goimports", "gofmt" },
      gomod = { "gofmt" },
    },
    tools = {
      { "gopls", "Go LSP", "mise install  |  go install golang.org/x/tools/gopls@latest" },
      { "goimports", "Go imports", "go install golang.org/x/tools/cmd/goimports@latest" },
    },
  },

  typescript = {
    servers = { "vtsls", "eslint" },
    parsers = { "javascript", "typescript", "tsx", "jsdoc" },
    formatters = {
      javascript = { "prettierd", "prettier", stop_after_first = true },
      javascriptreact = { "prettierd", "prettier", stop_after_first = true },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      typescriptreact = { "prettierd", "prettier", stop_after_first = true },
    },
    tools = {
      { "vtsls", "TypeScript LSP", "npm i -g @vtsls/language-server typescript" },
      { "vscode-eslint-language-server", "ESLint LSP", "npm i -g vscode-langservers-extracted" },
      { "prettierd", "JS/TS formatter", "npm i -g @fsouza/prettierd" },
    },
  },

  ruby = {
    servers = { "ruby_lsp" },
    parsers = { "ruby" },
    formatters = { ruby = { "rubocop" }, eruby = { "erb_format" } },
    tools = {
      { "ruby-lsp", "Ruby LSP", "gem install ruby-lsp" },
      { "rubocop", "Ruby formatter", "gem install rubocop" },
    },
  },

  terraform = {
    servers = { "terraformls", "tflint" },
    parsers = { "terraform", "hcl" },
    formatters = {
      terraform = { "tofu_fmt" },
      ["terraform-vars"] = { "tofu_fmt" },
    },
    tools = {
      { "terraform-ls", "Terraform/OpenTofu LSP", "brew install hashicorp/tap/terraform-ls" },
      { "tofu", "OpenTofu CLI + fmt", "brew install opentofu" },
    },
    optional = {
      { "tflint", "Terraform linter", "brew install tflint" },
      { "tofu-ls", "OpenTofu LSP fork (preferred if present)", "go install github.com/gamunu/opentofu-ls@latest" },
    },
  },

  terragrunt = {
    servers = { "terragrunt_ls" },
    parsers = { "hcl" },
    formatters = { hcl = { "terragrunt_fmt" } },
    tools = {
      { "terragrunt", "Terragrunt CLI + hcl fmt", "brew install terragrunt" },
    },
    optional = {
      -- Officially maintained by Gruntwork but explicitly a work in
      -- progress, so a warning rather than a failure. Without it you
      -- still get treesitter structure and `terragrunt hcl fmt`.
      { "terragrunt-ls", "Terragrunt LSP (early, WIP)", "go install github.com/gruntwork-io/terragrunt-ls@latest" },
    },
  },

  bash = {
    servers = { "bashls" },
    parsers = { "bash" },
    formatters = { sh = { "shfmt" }, bash = { "shfmt" } },
    tools = {
      { "bash-language-server", "bash LSP", "npm i -g bash-language-server" },
      { "shfmt", "shell formatter", "brew install shfmt" },
    },
    optional = {
      { "shellcheck", "shell linter (bashls uses it automatically)", "brew install shellcheck" },
    },
  },

  python = {
    servers = { "basedpyright", "ruff" },
    parsers = { "python" },
    formatters = { python = { "ruff_fix", "ruff_format" } },
    tools = {
      { "ruff", "Python lint + format", "brew install ruff" },
    },
    optional = {
      { "basedpyright", "Python type checker", "uv tool install basedpyright" },
    },
  },

  swift = {
    servers = { "sourcekit" },
    parsers = { "swift" },
    formatters = { swift = { "swiftformat" } },
    tools = {
      -- sourcekit-lsp ships with Xcode; verify.lua special-cases xcrun.
      { "xcrun", "Xcode toolchain (provides sourcekit-lsp)", "xcode-select --install" },
    },
    optional = {
      { "swiftformat", "Swift formatter", "brew install swiftformat" },
    },
  },

  kotlin = {
    servers = { "kotlin_lsp" },
    parsers = { "kotlin" },
    formatters = { kotlin = { "ktlint" } },
    tools = {
      { "kotlin-lsp", "Kotlin LSP (JetBrains, bundles its own JRE)", "brew install JetBrains/utils/kotlin-lsp" },
    },
    optional = {
      { "ktlint", "Kotlin formatter", "brew install ktlint" },
    },
  },

  toml = {
    servers = { "taplo" },
    parsers = { "toml" },
    formatters = { toml = { "taplo" } },
    tools = {
      { "taplo", "TOML LSP + formatter", "brew install taplo" },
    },
  },

  yaml = {
    servers = { "yamlls" },
    parsers = { "yaml" },
    formatters = { yaml = { "prettierd", "prettier", stop_after_first = true } },
    tools = {
      { "yaml-language-server", "YAML LSP", "npm i -g yaml-language-server" },
    },
  },

  json = {
    servers = { "jsonls" },
    -- No jsonc parser exists upstream; plugins.lua maps the filetype to
    -- the json one. Asking for it here only earns a warning per session.
    parsers = { "json" },
    formatters = {
      json = { "prettierd", "prettier", stop_after_first = true },
      jsonc = { "prettierd", "prettier", stop_after_first = true },
    },
    tools = {
      { "vscode-json-language-server", "JSON LSP", "npm i -g vscode-langservers-extracted" },
    },
  },

  lua = {
    servers = { "lua_ls" },
    parsers = { "lua", "luadoc" },
    formatters = { lua = { "stylua" } },
    tools = {
      { "lua-language-server", "Lua LSP", "brew install lua-language-server" },
    },
    optional = {
      { "stylua", "Lua formatter", "brew install stylua" },
    },
  },

  markdown = {
    parsers = { "markdown", "markdown_inline" },
    formatters = { markdown = { "prettierd", "prettier", stop_after_first = true } },
  },
}
