-- The terminal Neovim runs in: desktop notifications and its progress bar.
--
-- Neovim is a terminal too, and a terminal buffer is where the interesting
-- signals start. Claude Code in a :terminal emits OSC 777 "needs your
-- permission" and OSC 9;4 "working" exactly as it would straight in
-- Ghostty — and Neovim, being the terminal it's talking to, swallows both.
-- This forwards them to the real one, the way a multiplexer would.
--
--   child TUI ── OSC 9 / 777 / 9;4 ──> TermRequest ──> here ──> Ghostty
--   LspProgress ────────────────────────────────────> here ──> Ghostty
--   claude/notify.sh ── nvim --server ──────────────> here ──> Ghostty
--
-- ── Notifications ─────────────────────────────────────────────────────
-- Ghostty posts them, so a click brings back the window they came from, and
-- no osascript or Accessibility permission is involved. And because they
-- pass through here, they can be dropped when there's nothing to tell: the
-- terminal they came from is on screen in the current tab AND Ghostty has
-- focus. That's the focus detection claude/notify.sh can't do on its own.
--
-- ── Progress ──────────────────────────────────────────────────────────
-- Neovim 0.12 already turns |Progress| messages into OSC 9;4 (see
-- `nvim.progress` in vim/_core/defaults.lua), but with one bar per message
-- and the first to finish clearing it while the others still run. This
-- replaces that with one aggregate over every source: an unknown
-- percentage anywhere makes the bar indeterminate, otherwise it's the
-- average.
--
-- ┌────────────────────────────────────────────────────────────────────┐
-- │  Turning progress off and :Reload does not bring Neovim's own      │
-- │  `nvim.progress` handler back — it was deleted, not wrapped.       │
-- │  Restart for that.                                                 │
-- └────────────────────────────────────────────────────────────────────┘

local config = require("core.config")

local M = {}

local opts = config.hostterm or {}
local notify_opts = opts.notify or {}
local progress_opts = opts.progress or {}

-- ── The host ──────────────────────────────────────────────────────────
-- By environment, like core.iterm. GHOSTTY_RESOURCES_DIR as well as
-- TERM_PROGRAM because tmux overwrites the latter with "tmux" and leaves
-- the former alone.

local host = (function()
  local tp = vim.env.TERM_PROGRAM
  if tp == "ghostty" or vim.env.GHOSTTY_RESOURCES_DIR then return "ghostty" end
  if tp == "iTerm.app" or vim.env.LC_TERMINAL == "iTerm2" then return "iterm2" end
  if tp == "WezTerm" then return "wezterm" end
  if vim.env.KITTY_WINDOW_ID then return "kitty" end
  return nil
end)()

-- Which host speaks which. OSC 9;4 is an allowlist rather than "send it and
-- see": a terminal that knows OSC 9 but not 9;4 shows "4;1;42" as a
-- notification, which is worse than no bar.
local notify_style = { ghostty = "777", wezterm = "777", iterm2 = "9", kitty = "99" }
local progress_hosts = { ghostty = true, iterm2 = true }

M.host = host

--- Write raw bytes to the terminal, wrapped for tmux's passthrough when
--- needed (tmux needs `set -g allow-passthrough on`). Same as core.iterm.
local function emit(seq)
  if vim.env.TMUX then
    seq = "\27Ptmux;" .. seq:gsub("\27", "\27\27") .. "\27\\"
  end
  pcall(vim.api.nvim_ui_send, seq)
end

-- ── Notifications ─────────────────────────────────────────────────────

--- One line, no control characters, and short. A BEL or ESC inside a body
--- would end the sequence early and dump the rest on screen.
local function clean(s, max)
  s = tostring(s or ""):gsub("[%c]", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  -- By character: a byte cut can split "—" and hand Ghostty invalid UTF-8.
  if vim.fn.strchars(s) > max then s = vim.fn.strcharpart(s, 0, max - 1) .. "…" end
  return s
end

local function send(title, body)
  local style = notify_style[host]
  title, body = clean(title, 80), clean(body, 240)
  if style == "777" then
    -- The title ends at the next `;`, so it can't contain one.
    emit(("\27]777;notify;%s;%s\27\\"):format(title:gsub(";", ","), body))
  elseif style == "9" then
    -- OSC 9 has no title field.
    emit(("\27]9;%s: %s\27\\"):format(title, body))
  elseif style == "99" then
    emit(("\27]99;i=nvim:d=0;%s\27\\"):format(title))
    emit(("\27]99;i=nvim:p=body;%s\27\\"):format(body))
  end
end

-- Tracked from FocusGained/FocusLost, which Neovim gets from the terminal's
-- focus reporting. Starts true: a terminal that never reports focus should
-- err towards the quiet side, not notify about a buffer you're looking at.
local focused = true

--- Is `buf` something you can see right now?
local function in_view(buf)
  if not (buf and focused) then return false end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf then return true end
  end
  return false
end

--- Post a notification through the host terminal. `buf` is the terminal
--- buffer it's about, if any; it's what makes suppression possible.
--- Returns true when the host can show notifications at all, whether or
--- not this one was dropped — false means "use some other notifier".
function M.notify(title, body, buf)
  if notify_opts.enabled == false or not notify_style[host] then return false end
  if notify_opts.when ~= "always" and in_view(buf) then return true end
  send(title, body)
  return true
end

-- ── Duplicates ────────────────────────────────────────────────────────
-- Claude Code announces a permission prompt twice: as its own OSC
-- notification out of the terminal, and through the Notification hook that
-- runs claude/notify.sh. The hook's is better — it knows the project — so
-- a terminal's own notification waits briefly, and a hook call for the
-- same buffer cancels it.

local HOLD_MS = 400
local held = {} -- buf -> uv timer

local function hold(buf, title, body)
  if held[buf] then held[buf]:stop(); held[buf]:close() end
  local t = vim.uv.new_timer()
  held[buf] = t
  t:start(HOLD_MS, 0, vim.schedule_wrap(function()
    if held[buf] ~= t then return end
    held[buf] = nil
    t:close()
    M.notify(title, body, buf)
  end))
end

local function release(buf)
  if buf and held[buf] then
    held[buf]:stop(); held[buf]:close()
    held[buf] = nil
  end
end

--- The terminal buffer whose job is `pid` or one of its ancestors. A hook
--- script is a grandchild of Claude Code, which is a child of the shell the
--- terminal job started — walking up finds the buffer with no environment
--- variable having to be threaded through every way a terminal gets opened.
local function buf_for_pid(pid)
  local jobs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local job = vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "terminal"
      and vim.b[buf].terminal_job_id
    if job then
      local ok, jpid = pcall(vim.fn.jobpid, job)
      if ok and jpid > 0 then jobs[jpid] = buf end
    end
  end
  for _ = 1, 32 do
    if not pid or pid <= 1 then return nil end
    if jobs[pid] then return jobs[pid] end
    local ok, proc = pcall(vim.api.nvim_get_proc, pid)
    pid = ok and type(proc) == "table" and proc.ppid or nil
  end
end

--- Entry point for claude/notify.sh, over `nvim --server "$NVIM"`. Strings
--- arrive base64-encoded so the shell never has to quote them into an
--- expression. Returns 1 when handled here, 0 to make the script fall back
--- to its own notifier.
function M.remote_notify(title_b64, body_b64, pid)
  local ok_t, title = pcall(vim.base64.decode, title_b64 or "")
  local ok_b, body = pcall(vim.base64.decode, body_b64 or "")
  if not (ok_t and ok_b) then return 0 end
  local buf = buf_for_pid(tonumber(pid))
  release(buf)
  return M.notify(title, body, buf) and 1 or 0
end

-- ── Progress ──────────────────────────────────────────────────────────

-- key -> { percent = n|nil, error = bool, at = ms }. Keys are
-- "msg:<id>" (Progress messages), "lsp:<client>:<token>" and "term:<buf>".
local items = {}
local last_sent = nil
local heartbeat = nil

-- A source that stops talking without saying it finished — a crashed
-- server, a killed TUI — would otherwise leave the bar up forever.
local STALE_MS = 30000
-- Ghostty drops a bar it hasn't heard about for 15 seconds, on the
-- assumption that the program died. A long quiet LSP index is not dead.
local HEARTBEAT_MS = 5000

local function now() return vim.uv.now() end

local function aggregate()
  local count, sum, unknown, failed = 0, 0, false, false
  local t = now()
  for key, item in pairs(items) do
    if t - item.at > STALE_MS then
      items[key] = nil
    else
      count = count + 1
      if item.error then failed = true end
      if item.percent then sum = sum + item.percent else unknown = true end
    end
  end
  if count == 0 then return "0;0" end
  -- 2 is error (red), 3 indeterminate, 1 normal.
  if failed then return ("2;%d"):format(unknown and 100 or math.floor(sum / count)) end
  if unknown then return "3;0" end
  return ("1;%d"):format(math.floor(sum / count))
end

local function flush(force)
  local state = aggregate()
  if state ~= last_sent or (force and state ~= "0;0") then
    emit(("\27]9;4;%s\27\\"):format(state))
    last_sent = state
  end
  if state == "0;0" then
    if heartbeat then heartbeat:stop() end
  else
    heartbeat = heartbeat or vim.uv.new_timer()
    if not heartbeat:is_active() then
      heartbeat:start(HEARTBEAT_MS, HEARTBEAT_MS, vim.schedule_wrap(function() flush(true) end))
    end
  end
end

-- A dozen LSP updates in one tick make one write.
local scheduled = false
local function update(key, item)
  if item then item.at = now() end
  items[key] = item
  if scheduled then return end
  scheduled = true
  vim.schedule(function()
    scheduled = false
    flush(false)
  end)
end

-- ── Terminal requests ─────────────────────────────────────────────────

local function on_term_request(ev)
  local seq = ev.data and ev.data.sequence
  if type(seq) ~= "string" then return end
  local body = seq:match("^\27%](.*)$")
  if not body then return end
  local buf = ev.buf

  -- OSC 9;4;state;percent — ConEmu's progress. 0 clears, 2 is error,
  -- 3 indeterminate, 4 paused (shown as running).
  local state, pct = body:match("^9;4;(%d*);?(%d*)")
  if state then
    if progress_opts.enabled == false or progress_opts.terminals == false
      or not progress_hosts[host] then
      return
    end
    state = tonumber(state) or 0
    if state == 0 then
      update("term:" .. buf, nil)
    else
      update("term:" .. buf, {
        percent = state ~= 3 and tonumber(pct) or nil,
        error = state == 2,
      })
    end
    return
  end

  if notify_opts.terminals == false then return end
  local title = vim.b[buf].term_title
  if not title or title == "" then title = "Neovim" end

  local t777, b777 = body:match("^777;notify;([^;]*);(.*)$")
  if t777 then return hold(buf, t777 ~= "" and t777 or title, b777) end

  -- Every other `9;<number>;` is a ConEmu control code, not a message.
  if body:match("^9;%d+;") then return end
  local b9 = body:match("^9;(.+)$")
  if b9 then return hold(buf, title, b9) end
end

-- ── Wiring ────────────────────────────────────────────────────────────

local group = vim.api.nvim_create_augroup("core.hostterm", { clear = true })

vim.api.nvim_create_autocmd("FocusGained", { group = group, callback = function() focused = true end })
vim.api.nvim_create_autocmd("FocusLost", { group = group, callback = function() focused = false end })

if notify_style[host] or progress_hosts[host] then
  vim.api.nvim_create_autocmd("TermRequest", { group = group, callback = on_term_request })
end

vim.api.nvim_create_autocmd("TermClose", {
  group = group,
  callback = function(ev)
    release(ev.buf)
    if items["term:" .. ev.buf] then update("term:" .. ev.buf, nil) end
  end,
})

if progress_opts.enabled ~= false and progress_hosts[host] then
  -- Take over from Neovim's per-message bar. See the box at the top.
  pcall(vim.api.nvim_del_augroup_by_name, "nvim.progress")

  vim.api.nvim_create_autocmd("Progress", {
    group = group,
    callback = function(ev)
      local d = ev.data or {}
      if d.id == nil then return end
      if d.status == "running" then
        update("msg:" .. tostring(d.id), { percent = d.percent })
      elseif d.status == "failed" then
        update("msg:" .. tostring(d.id), { percent = d.percent, error = true })
        vim.defer_fn(function() update("msg:" .. tostring(d.id), nil) end, 1500)
      else
        update("msg:" .. tostring(d.id), nil)
      end
    end,
  })

  if progress_opts.lsp ~= false then
    -- Straight into the aggregate rather than through nvim_echo: a
    -- progress message is also shown in the cmdline ('messagesopt'
    -- "progress:c"), and a language server indexing is a lot of flicker
    -- down there for something the bar already says.
    vim.api.nvim_create_autocmd("LspProgress", {
      group = group,
      callback = function(ev)
        local params = ev.data and ev.data.params or {}
        local value = params.value
        if type(value) ~= "table" or params.token == nil then return end
        local key = ("lsp:%s:%s"):format(ev.data.client_id, tostring(params.token))
        if value.kind == "end" then
          update(key, nil)
        else
          update(key, { percent = value.percentage })
        end
      end,
    })
  end
end

vim.api.nvim_create_user_command("HostTerm", function()
  local running = {}
  for key, item in pairs(items) do
    running[#running + 1] = ("  %s  %s"):format(key, item.percent and (item.percent .. "%") or "…")
  end
  table.sort(running)
  vim.notify(table.concat({
    ("host           %s"):format(host or "unknown (nothing is sent)"),
    ("notifications  %s"):format(notify_style[host] and ("OSC " .. notify_style[host]) or "not supported"),
    ("progress bar   %s"):format(progress_hosts[host] and "OSC 9;4" or "not supported"),
    ("focused        %s"):format(tostring(focused)),
    ("bar            %s"):format(last_sent or "never sent"),
    #running > 0 and ("running:\n" .. table.concat(running, "\n")) or "running:      nothing",
  }, "\n"))
end, { desc = "Show what is forwarded to the host terminal" })

function M.unload()
  for buf in pairs(held) do release(buf) end
  if heartbeat then
    heartbeat:stop(); heartbeat:close(); heartbeat = nil
  end
  -- Don't leave a bar up that nothing will ever clear.
  if last_sent and last_sent ~= "0;0" then emit("\27]9;4;0;0\27\\") end
  pcall(vim.api.nvim_del_augroup_by_name, "core.hostterm")
end

return M
