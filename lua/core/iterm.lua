-- One-way sync: Neovim tells iTerm2 what it's showing.
--
-- ╭─ WHAT THIS CANNOT DO, AND WHY ─────────────────────────────────────╮
-- │ It cannot make Neovim's tabs BE iTerm2's tabs. Two reasons, and    │
-- │ both are walls rather than difficulties:                           │
-- │                                                                    │
-- │  1. No escape code exists. iTerm2's proprietary sequences cover    │
-- │     titles, colours, badges and user variables — not one of them   │
-- │     creates, selects or enumerates a tab. Its only native-tab      │
-- │     bridge is tmux control mode (`tmux -CC`), a protocol Neovim    │
-- │     does not speak.                                                │
-- │  2. Driving iTerm2 from outside wouldn't help either. Every iTerm2 │
-- │     tab is a separate PTY running a separate process, and a Neovim │
-- │     tabpage is GLOBAL editor state — every client attached with    │
-- │     --remote-ui mirrors the same screen, same current tabpage. So  │
-- │     iTerm2 tab A showing tabpage 1 while tab B shows tabpage 2 is  │
-- │     not a thing that can be built.                                 │
-- ╰────────────────────────────────────────────────────────────────────╯
--
-- What's left is worth having: the native tab says which Neovim tab you're
-- on, and goes amber or red when something wants you. 'title' works in every
-- terminal; the OSC 1337 half is a silent no-op anywhere but iTerm2.
--
-- To use the variables, put \(user.nvim_tab) in iTerm2's tab title format,
-- badge, or a status bar component. Nothing shows up until you do — the
-- sequences only set values, they don't decide where they're displayed.
--
-- Nothing here runs at redraw time. core.tabs already coalesces its events
-- into one callback per tick and calls M.sync() from there; a timer on top
-- of that collapses a burst (a :bufdo, an LSP flood) into one write. The
-- same rule core.claude follows: prepare a string on a timer, never in the
-- draw path.

local config = require("core.config")

local M = {}

local opts = config.iterm

-- LC_TERMINAL as well as TERM_PROGRAM: the first isn't forwarded over ssh
-- and the second is, which is exactly why iTerm2 sets it.
local is_iterm = vim.env.TERM_PROGRAM == "iTerm.app" or vim.env.LC_TERMINAL == "iTerm2"

-- Order matters only so the writes are deterministic and easy to read in a
-- trace; iTerm2 does not care.
local VARS = {
  "nvim_tab", "nvim_index", "nvim_tabs",
  "nvim_errors", "nvim_warnings", "nvim_modified", "nvim_cwd",
}

local last = {}
local timer = nil
local armed = false

-- ── The wire ──────────────────────────────────────────────────────────

--- Write raw bytes to the terminal. Under tmux they have to be wrapped in a
--- DCS passthrough with every ESC doubled, and tmux needs
--- `set -g allow-passthrough on` to forward them — the same requirement the
--- OSC 11 chain in core/theme.lua has, for the same reason.
local function emit(seq)
  if vim.env.TMUX then
    seq = "\27Ptmux;" .. seq:gsub("\27", "\27\27") .. "\27\\"
  end
  pcall(vim.api.nvim_ui_send, seq)
end

local function osc1337(body)
  return "\27]1337;" .. body .. "\27\\"
end

-- ── The model ─────────────────────────────────────────────────────────

--- Everything we might publish, read in one pass off core.tabs' tree so it
--- can't disagree with the sidebar or the tabline about what's open.
local function snapshot()
  local tabs = require("core.tabs")

  local current, count, errors, warnings, modified = nil, 0, 0, 0, false
  for _, t in ipairs(tabs.tree()) do
    -- The "Hidden" group has no handle: it's a bucket for buffers no tabpage
    -- is showing, not a tab, and counting it would overstate the total.
    if t.handle then
      count = count + 1
      if t.current then current = t end
      errors = errors + t.status.errors
      warnings = warnings + t.status.warnings
      modified = modified or t.status.modified
    end
  end

  -- The same fallback chain the sidebar titles a group with: a name you
  -- chose, else the tab's :tcd directory, else the active buffer.
  local name, index = "nvim", 0
  if current then
    index = current.index
    name = current.custom or current.cwd or current.name
  end

  local snap = {
    nvim_tab = name,
    nvim_index = tostring(index),
    nvim_tabs = tostring(count),
    nvim_errors = tostring(errors),
    nvim_warnings = tostring(warnings),
    nvim_modified = modified and "1" or "0",
    nvim_cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":~"),
  }
  snap.title = count > 1
    and ("%s — nvim %d/%d"):format(name, index, count)
    or ("%s — nvim"):format(name)
  snap.color = (errors > 0 and opts.colors.error)
    or (modified and opts.colors.modified)
    or "default"
  return snap
end

-- ── Publishing ────────────────────────────────────────────────────────

--- Emit whatever actually changed. In a session that's sitting still this
--- writes nothing at all, which is the point: an escape sequence per redraw
--- would be a lot of bytes to say the same thing.
function M.flush()
  if not opts.enabled then return end
  local snap = snapshot()

  if opts.title and snap.title ~= last.title then
    -- Escaped: 'titlestring' expands printf-style % items exactly as
    -- 'statusline' does, so a tab showing `100%.md` would set a title with
    -- the filename half eaten by a format item.
    vim.o.titlestring = require("core.tabs").escape(snap.title)
    vim.o.title = true
  end

  if is_iterm then
    if opts.user_vars then
      for _, key in ipairs(VARS) do
        if snap[key] ~= last[key] then
          emit(osc1337("SetUserVar=" .. key .. "=" .. vim.base64.encode(snap[key])))
        end
      end
    end
    if opts.tab_color and snap.color ~= last.color then
      -- "default" is what CLEARS the tint. Leaving a colour behind on a tab
      -- whose errors you already fixed is worse than never colouring it.
      emit(osc1337("SetColors=tab=" .. snap.color))
    end
  end

  last = snap
end

--- Called from core.tabs' coalescer, once per tick at most. The timer
--- collapses a run of those ticks into one, and then only ARMS the write —
--- SafeState below is what actually performs it.
function M.sync()
  if not opts.enabled then return end
  timer = timer or vim.uv.new_timer()
  timer:stop()
  timer:start(opts.interval, 0, vim.schedule_wrap(function()
    armed = true
  end))
end

function M.unload()
  armed = false
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
  if is_iterm and opts.tab_color and last.color and last.color ~= "default" then
    emit(osc1337("SetColors=tab=default"))
  end
  -- Neovim restores the terminal's own title from 'titleold' when 'title'
  -- goes off, so there's nothing to save and put back by hand.
  vim.o.title = false
  last = {}
end

-- ── Wiring ────────────────────────────────────────────────────────────

local group = vim.api.nvim_create_augroup("core.iterm", { clear = true })

-- ╭─ WHY THE WRITE HAPPENS HERE AND NOT ON THE TIMER ──────────────────╮
-- │ This module writes escape sequences to the terminal's stdout, and  │
-- │ it is not the only thing that does. 'clipboard' is unnamedplus, so │
-- │ every yank goes through the clipboard provider — and under tmux or │
-- │ over ssh that provider writes OSC 52 to the same stdout. Two       │
-- │ writers at an arbitrary moment is how you get interleaved bytes,   │
-- │ a corrupted sequence, and a yank that misbehaves "sometimes".      │
-- │                                                                    │
-- │ SafeState is Neovim saying it is idle: no pending operator, no     │
-- │ half-finished mapping, nothing mid-flight. So the timer only marks │
-- │ the state dirty and this does the writing.                         │
-- ╰────────────────────────────────────────────────────────────────────╯
vim.api.nvim_create_autocmd("SafeState", {
  group = group,
  callback = function()
    if not armed then return end
    armed = false
    M.flush()
  end,
})

-- Everything else arrives through core.tabs' refresh, which already fires on
-- every buffer, window, tab, diagnostic and gitsigns event. :tcd is the one
-- thing it has no reason to care about and this does.
vim.api.nvim_create_autocmd({ "DirChanged", "VimEnter" }, {
  group = group,
  callback = function() M.sync() end,
})

M.sync()

return M
