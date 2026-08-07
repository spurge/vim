-- Terragrunt HCL.
--
--   go install github.com/gruntwork-io/terragrunt-ls@latest
--
-- Set expectations honestly: this is the *official* Gruntwork server, but
-- the maintainers describe it as a work in progress and say plainly it
-- isn't a project they can give much time to. You get hover and
-- go-to-definition on include/dependency blocks; you do not get the
-- completion depth terraform-ls gives you for .tf files.
--
-- The heavier lifting for terragrunt.hcl comes from elsewhere in this
-- config: the treesitter hcl grammar for structure and highlighting, and
-- `terragrunt hcl fmt` on save (see lua/core/format.lua).

return {
  cmd = { "terragrunt-ls" },
  filetypes = { "hcl", "terragrunt" },
  root_markers = { "root.hcl", "terragrunt.hcl", ".git" },
}
