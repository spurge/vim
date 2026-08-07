-- OpenTofu / Terraform.
--
-- terraform-ls works fine against OpenTofu configurations, but if you've
-- installed the OpenTofu fork we prefer it, since it tracks tofu-specific
-- syntax and the tofu registry.
--
--   brew install hashicorp/tap/terraform-ls   # or:
--   go install github.com/gamunu/opentofu-ls@latest
--
-- Reminder that bit everyone once: the server needs `tofu init` /
-- `terraform init` to have run, or it has no provider schemas and
-- completion comes back empty.

local cmd = vim.fn.executable("tofu-ls") == 1
  and { "tofu-ls", "serve" }
  or { "terraform-ls", "serve" }

return {
  cmd = cmd,
  filetypes = { "terraform", "terraform-vars" },
  root_markers = { ".terraform", ".terraform.lock.hcl", ".git" },
  settings = {
    terraform = {
      validation = { enableEnhancedValidation = true },
      indexing = { ignoreDirectoryNames = { ".terragrunt-cache" } },
    },
  },
}
