-- Shell configuration.
--
-- Neovim's 'shell' option is used for FOUR different things:
--   1. :terminal (when invoked with no explicit command)
--   2. :!cmd
--   3. system() / vim.fn.system()
--   4. some plugin shell-outs (fzf-lua's pipelines, :grep via 'grepprg')
--
-- (1) wants your login shell. (2)-(4) want POSIX, because plugins emit
-- constructs like `VAR=x cmd`, `2>/dev/null` and nested `$(...)` that
-- fish and nushell reject or reinterpret.
--
-- Those pull in opposite directions and there is no way to have both
-- from one option. The default here favours (1) — least surprising,
-- since :terminal giving you a shell you don't use is jarring. Set
-- settings.shell.internal = "posix" to flip the tradeoff if a plugin
-- starts misbehaving; the terminal toggles in core/terminal.lua exec
-- your interactive shell directly either way, so they are unaffected.

local config = require("core.config")

local M = {}

-- ── Interactive: what :terminal and the toggles open ──────────────────
--- Resolution order: settings.shell.interactive, then fish, then $SHELL,
--- then bash, then /bin/sh.
local function resolve_interactive()
  local want = config.shell.interactive
  if want and want ~= "" and vim.fn.executable(want) == 1 then
    return vim.fn.exepath(want)
  end

  local fish = vim.fn.exepath("fish")
  if fish ~= "" then
    return fish
  end

  local env = vim.env.SHELL
  if env and env ~= "" and vim.fn.executable(env) == 1 then
    return env
  end

  local bash = vim.fn.exepath("bash")
  return bash ~= "" and bash or "/bin/sh"
end

M.interactive_path = resolve_interactive()

function M.interactive()
  return M.interactive_path
end

-- ── Internal: what :! and system() use ────────────────────────────────
local function resolve_internal()
  local want = config.shell.internal

  -- "posix": force a POSIX shell regardless of your login shell.
  if want == "posix" then
    local bash = vim.fn.exepath("bash")
    return bash ~= "" and bash or "/bin/sh"
  end

  -- An explicit path.
  if want and want ~= "" and want ~= "interactive" and vim.fn.executable(want) == 1 then
    return vim.fn.exepath(want)
  end

  -- "interactive" (the default): same shell everywhere.
  return M.interactive_path
end

M.internal_path = resolve_internal()

vim.o.shell = M.internal_path
vim.o.shellcmdflag = "-c"
vim.o.shellredir = ">%s 2>&1"
vim.o.shellpipe = "2>&1| tee"
vim.o.shellquote = ""
vim.o.shellxquote = ""

--- True when 'shell' is a shell that plugins can rely on being POSIX.
function M.internal_is_posix()
  local name = vim.fn.fnamemodify(M.internal_path, ":t")
  return name == "bash" or name == "sh" or name == "dash"
    or name == "zsh" or name == "ksh" or name == "ash"
end

-- Warn once, lazily, if 'shell' is non-POSIX. Not an error — plenty of
-- people run this way without trouble — but when fzf-lua returns nothing
-- or a formatter silently stops, this is the first thing to check.
if not M.internal_is_posix() then
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      vim.g.core_shell_warning = ("'shell' is %s (non-POSIX). If fzf-lua or a "
        .. "formatter misbehaves, set shell.internal = \"posix\" in "
        .. "lua/settings.lua — see :ShellInfo"):format(
        vim.fn.fnamemodify(M.internal_path, ":t"))
    end,
  })
end

vim.api.nvim_create_user_command("ShellInfo", function()
  local lines = {
    "interactive  " .. M.interactive_path .. "   (:terminal, ,cs, ,cV)",
    "internal     " .. M.internal_path .. "   (:!, system(), :grep, plugins)",
    "posix-safe   " .. tostring(M.internal_is_posix()),
  }
  if vim.g.core_shell_warning then
    table.insert(lines, "")
    table.insert(lines, vim.g.core_shell_warning)
  end
  vim.notify(table.concat(lines, "\n"))
end, { desc = "Show which shells this config is using and why" })

vim.api.nvim_create_user_command("Shell", function()
  vim.cmd("botright split")
  M.open_terminal()
end, { desc = "Interactive shell in a split" })

--- Open a terminal in the current window running `cmd`, or the
--- interactive shell if `cmd` is nil.
---
--- Uses jobstart rather than :terminal so the interactive shell is
--- exec'd directly. `:terminal foo` runs foo *through* 'shell', which
--- would spawn a pointless bash wrapper around fish when
--- shell.internal = "posix".
function M.open_terminal(cmd)
  local argv
  if not cmd then
    argv = { M.interactive_path }
  elseif type(cmd) == "table" then
    argv = cmd
  else
    argv = { M.interactive_path, "-c", cmd }
  end
  return vim.fn.jobstart(argv, { term = true })
end

return M
