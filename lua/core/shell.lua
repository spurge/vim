-- Shell configuration.
--
-- Neovim's 'shell' option is used for THREE different things:
--   1. :!cmd, system(), vim.fn.system()
--   2. plugin shell-outs (conform's formatters, fzf-lua's pipelines)
--   3. the shell that :terminal launches
--
-- Non-POSIX shells (fish, nushell, xonsh) are fine for (3) but break
-- (1) and (2), because plugins emit POSIX constructs — `2>/dev/null`,
-- `VAR=x cmd`, nested `$(...)`, `[ ... ]` — which those shells reject or
-- reinterpret. Both conform and fzf-lua document this.
--
-- So the two roles are split. This is why 'shell' may not be your login
-- shell, and it's deliberate: setting 'shell' to fish globally is the
-- usual cause of "conform silently stopped formatting".

local config = require("core.config")

local M = {}

-- ── Internal: POSIX ───────────────────────────────────────────────────
local internal = config.shell.internal
if not internal or vim.fn.executable(internal) == 0 then
  internal = vim.fn.exepath("bash")
  if internal == "" then internal = "/bin/sh" end
end

vim.o.shell = internal
vim.o.shellcmdflag = "-c"
vim.o.shellredir = ">%s 2>&1"
vim.o.shellpipe = "2>&1| tee"
vim.o.shellquote = ""
vim.o.shellxquote = ""

M.internal = internal

-- ── Interactive: whatever you actually type into ──────────────────────
--- Resolution order: settings.shell.interactive, then fish, then $SHELL,
--- then the POSIX shell above.
function M.interactive()
  local want = config.shell.interactive
  if want and vim.fn.executable(want) == 1 then
    return vim.fn.exepath(want)
  end

  local fish = vim.fn.exepath("fish")
  if fish ~= "" then return fish end

  local env = vim.env.SHELL
  if env and env ~= "" and vim.fn.executable(env) == 1 then return env end

  return internal
end

vim.api.nvim_create_user_command("Shell", function()
  vim.cmd("botright split")
  vim.cmd.terminal(M.interactive())
end, { desc = "Interactive shell in a split" })

return M
