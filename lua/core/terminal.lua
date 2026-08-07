-- Terminal splits, and the nested-escape problem.
--
-- ── Why this needs thought ────────────────────────────────────────────
-- <C-\><C-n> is swallowed by the OUTERMOST Neovim. An inner Neovim
-- running in a terminal buffer never sees it. So every nesting level
-- needs its own way out, and whatever key you choose gets eaten at the
-- top first. Three-part answer:
--
--   1. Don't nest. $NVIM lets child processes talk to this instance, so
--      $EDITOR can open a buffer HERE instead of spawning nvim-in-nvim.
--      That's what the shell integration in shell/ does, and it removes
--      most of the problem rather than working around it.
--   2. Escape with a CONTROL CHORD (settings.terminal.escape). Never a
--      printable key: `\e` would eat `printf '\e[31m'`, `,e` would eat
--      `ls {a,e}`.
--   3. When you DO nest deliberately, <Leader>E hands the escape key
--      down to the inner layer instead of consuming it.

local config = require("core.config")
local shell = require("core.shell")
local map = vim.keymap.set

-- ── 1. Escape ─────────────────────────────────────────────────────────
for _, key in ipairs(config.terminal.escape) do
  map("t", key, "<C-\\><C-n>", { desc = "terminal: to normal mode" })
end
-- <C-\><C-n> still works too. Nothing removes it.

-- ── 2. Passthrough, for deliberate nesting ────────────────────────────
-- Buffer-local mappings beat global ones, so pointing the escape key at
-- a literal NUL in one specific terminal buffer sends it to the job
-- instead of acting on it. An inner Neovim running this same config maps
-- <C-@> and escapes as normal.
local function toggle_passthrough()
  if vim.bo.buftype ~= "terminal" then
    vim.notify("not a terminal buffer", vim.log.levels.WARN)
    return
  end

  if vim.b.core_passthrough then
    for _, key in ipairs(config.terminal.escape) do
      pcall(vim.keymap.del, "t", key, { buffer = 0 })
    end
    vim.b.core_passthrough = nil
    vim.notify("escape key: captured by this nvim")
  else
    local function send()
      vim.fn.chansend(vim.b.terminal_job_id, "\0")
    end
    for _, key in ipairs(config.terminal.escape) do
      vim.keymap.set("t", key, send, { buffer = 0 })
    end
    vim.b.core_passthrough = true
    vim.notify("escape key: passed through to inner process")
  end
end

map({ "t", "n" }, "<Leader>E", toggle_passthrough,
  { desc = "terminal: toggle escape passthrough" })

-- ── 3. Terminal buffer setup ──────────────────────────────────────────
vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("core.term", { clear = true }),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.cursorline = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.list = false
    vim.opt_local.scrolloff = 0
    vim.opt_local.spell = false
    vim.bo.bufhidden = "hide" -- survive being hidden, keep scrollback

    -- Auto-enable passthrough if the job is itself a Neovim. Heuristic:
    -- depends on the child setting its terminal title, so treat this as
    -- a convenience and <Leader>E as the reliable mechanism.
    vim.defer_fn(function()
      local title = vim.b.term_title or ""
      if title:match("nvim") or title:match("vim %-") then
        if not vim.b.core_passthrough then toggle_passthrough() end
      end
    end, 500)

    vim.cmd.startinsert()
  end,
})

vim.api.nvim_create_autocmd("TermClose", {
  group = "core.term",
  callback = function(ev)
    if vim.v.event.status == 0 then
      pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
    end
  end,
})

-- ── 4. Toggleable terminal slots ──────────────────────────────────────
-- Named, persistent terminals. Toggling hides the window without killing
-- the job, so a long-running agent session keeps its context.
local slots = {}

local function toggle(name, cmd, size)
  local slot = slots[name]

  if slot and vim.api.nvim_buf_is_valid(slot.buf) then
    local win = vim.fn.bufwinid(slot.buf)
    if win ~= -1 then
      vim.api.nvim_win_hide(win)
      return
    end
  end

  vim.cmd("botright split")
  vim.api.nvim_win_set_height(0, math.floor(vim.o.lines * (size or config.terminal.height)))

  if slot and vim.api.nvim_buf_is_valid(slot.buf) then
    vim.api.nvim_win_set_buf(0, slot.buf)
    vim.cmd.startinsert()
  else
    -- Always the interactive shell, whatever 'shell' happens to be.
    shell.open_terminal(cmd)
    slots[name] = { buf = vim.api.nvim_get_current_buf() }
  end
end

map({ "n", "t" }, "<Leader>cs", function() toggle("shell", nil, 0.35) end,
  { desc = "toggle shell split" })
map("n", "<Leader>cV", function()
  vim.cmd("vsplit")
  shell.open_terminal()
end, { desc = "shell in vertical split" })

-- ── 5. Coding agent, if configured ────────────────────────────────────
-- settings.terminal.agent = "claude" | "aider" | "codex" | nil
local agent = config.terminal.agent
if agent and agent ~= "" then
  map({ "n", "t" }, "<Leader>cc", function() toggle("agent", agent, 0.45) end,
    { desc = "toggle " .. agent })

  map("n", "<Leader>cv", function()
    vim.cmd("vsplit")
    shell.open_terminal(agent)
  end, { desc = agent .. " in vertical split" })

  -- Send the current file's path to the agent terminal, so you don't
  -- retype it. Uses the @path convention most CLI agents accept.
  map("n", "<Leader>cf", function()
    local slot = slots["agent"]
    if not (slot and vim.api.nvim_buf_is_valid(slot.buf)) then
      vim.notify("no " .. agent .. " terminal open", vim.log.levels.WARN)
      return
    end
    local path = vim.fn.expand("%:.")
    vim.fn.chansend(vim.b[slot.buf].terminal_job_id, "@" .. path .. " ")
    vim.notify("sent @" .. path)
  end, { desc = "send buffer path to " .. agent })
end
