-- Claude Code rate limits in the statusline, and notifications when a turn
-- ends.
--
-- ── Where the numbers come from ───────────────────────────────────────
-- Claude Code never asks you to configure a key here, and neither does
-- this. Two files it already writes carry the same percentages `/usage`
-- shows, both produced under the session's own auth:
--
--   1. the statusLine cache        claude/statusline.sh tees Claude Code's
--      (XDG state dir)             own stdin payload here on every render.
--                                  Live, but only while a session is open.
--   2. ~/.claude.json              cachedUsageUtilization, Claude Code's
--                                  copy of the server's answer. Survives
--                                  between sessions, so the segment works
--                                  before :ClaudeSetup has ever been run —
--                                  but it only refreshes when some Claude
--                                  process fetches it, hence fetchedAtMs.
--
-- Whichever was fetched more recently wins. Deliberately NOT used: the
-- transcripts under ~/.claude/projects (token counts, no limits), the
-- Keychain (reading it prompts), and `claude setup-token` (a new
-- credential, which is the thing this avoids).
--
-- ┌────────────────────────────────────────────────────────────────────┐
-- │  Two windows, not three. Anthropic exposes a 5-hour rolling window │
-- │  and a 7-day one. There is no monthly quota to show.               │
-- └────────────────────────────────────────────────────────────────────┘
--
-- ── The redraw budget ─────────────────────────────────────────────────
-- statusline.lua's rule is that nothing runs at redraw time. So a timer
-- does the stat-ing, reading and formatting, caches one finished string,
-- and redraws only when that string changes. M.statusline() is a lookup.

local config = require("core.config")

local M = {}

local settings = config.claude or {}
local state_path = vim.fs.joinpath(
  vim.env.XDG_STATE_HOME or vim.fs.joinpath(vim.env.HOME, ".local", "state"),
  "claude-code", "statusline.json"
)
local claude_json = vim.fs.joinpath(vim.env.HOME, ".claude.json")
local settings_json = vim.fs.joinpath(vim.env.HOME, ".claude", "settings.json")

-- ── Reading ───────────────────────────────────────────────────────────

--- mtime in seconds, or nil if the file isn't there.
local function mtime(path)
  local st = vim.uv.fs_stat(path)
  return st and st.mtime.sec or nil
end

local function read_json(path)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then return nil end
  local st = vim.uv.fs_fstat(fd)
  local data = st and vim.uv.fs_read(fd, st.size, 0) or nil
  vim.uv.fs_close(fd)
  if not data or data == "" then return nil end
  local ok, decoded = pcall(vim.json.decode, data)
  return ok and type(decoded) == "table" and decoded or nil
end

--- The local clock's offset from UTC, in seconds.
local function utc_offset()
  local now = os.time()
  local as_utc = os.date("!*t", now)
  as_utc.isdst = false
  return os.difftime(now, os.time(as_utc))
end

--- "2026-07-31T12:30:00.149026+00:00" -> epoch seconds.
---
--- os.time() reads a broken-down table as LOCAL time, so the offset has to
--- be added back by hand. The trailing zone is honoured when present;
--- Claude Code writes +00:00, but assuming that would be a silent bug the
--- day it stops being true.
local function iso_to_epoch(s)
  if type(s) ~= "string" then return nil end
  local y, mo, d, h, mi, sec = s:match("^(%d+)-(%d+)-(%d+)[T ](%d+):(%d+):(%d+)")
  if not y then return nil end

  local t = os.time({
    year = tonumber(y), month = tonumber(mo), day = tonumber(d),
    hour = tonumber(h), min = tonumber(mi), sec = tonumber(sec),
    isdst = false,
  })
  if not t then return nil end
  t = t + utc_offset()

  local sign, oh, om = s:match("([+-])(%d%d):?(%d%d)%s*$")
  if sign then
    local zone = tonumber(oh) * 3600 + tonumber(om) * 60
    t = t - (sign == "-" and -zone or zone)
  end
  return t
end

local function window(pct, resets_at)
  if type(pct) ~= "number" then return nil end
  return { pct = pct, resets_at = resets_at }
end

--- The statusLine cache. Percentages are 0-100, resets_at epoch seconds.
local function from_statusline()
  local data = read_json(state_path)
  local limits = data and data.rate_limits
  if type(limits) ~= "table" then return nil end

  local five = type(limits.five_hour) == "table" and limits.five_hour or {}
  local seven = type(limits.seven_day) == "table" and limits.seven_day or {}
  local out = {
    source = "statusLine",
    fetched_at = mtime(state_path) or 0,
    five_hour = window(five.used_percentage, five.resets_at),
    seven_day = window(seven.used_percentage, seven.resets_at),
  }
  if not (out.five_hour or out.seven_day) then return nil end
  return out
end

--- ~/.claude.json. Same numbers under different names: `utilization`
--- rather than `used_percentage`, and an ISO8601 reset rather than epoch.
local function from_claude_json()
  local data = read_json(claude_json)
  local cached = data and data.cachedUsageUtilization
  local util = type(cached) == "table" and cached.utilization or nil
  if type(util) ~= "table" then return nil end

  local five = type(util.five_hour) == "table" and util.five_hour or {}
  local seven = type(util.seven_day) == "table" and util.seven_day or {}
  local out = {
    source = "~/.claude.json",
    fetched_at = math.floor((tonumber(cached.fetchedAtMs) or 0) / 1000),
    five_hour = window(five.utilization, iso_to_epoch(five.resets_at)),
    seven_day = window(seven.utilization, iso_to_epoch(seven.resets_at)),
  }
  if not (out.five_hour or out.seven_day) then return nil end
  return out
end

-- ── Formatting ────────────────────────────────────────────────────────

--- "2h13m", "47m", "3d4h". Coarse on purpose: this is refreshed on a
--- timer, so a seconds field would be wrong most of the time it's read.
local function countdown(seconds)
  if seconds <= 0 then return nil end
  local d = math.floor(seconds / 86400)
  local h = math.floor(seconds % 86400 / 3600)
  local m = math.floor(seconds % 3600 / 60)
  if d > 0 then return ("%dd%dh"):format(d, h) end
  if h > 0 then return ("%dh%dm"):format(h, m) end
  return ("%dm"):format(math.max(m, 1))
end

--- Warn at three quarters, error at nine tenths. Reuses the groups the
--- rest of the statusline already uses, so it follows every colorscheme.
local function highlight(pct)
  if pct >= 90 then return "%#DiagnosticError#" end
  if pct >= 75 then return "%#DiagnosticWarn#" end
  return "%#Comment#"
end

local function render_window(label, win, now)
  if not win then return nil end

  -- A percentage from before the window reset describes a window that no
  -- longer exists. Say so rather than showing a stale number as current.
  if win.resets_at and win.resets_at <= now then
    return ("%%#Comment#%s ·"):format(label)
  end

  -- %%%% survives twice: once through string.format, and once through the
  -- statusline parser, for which a lone % starts an item and would eat the
  -- separator after it.
  local out = ("%s%s %d%%%%"):format(highlight(win.pct), label, math.floor(win.pct + 0.5))
  local left = win.resets_at and countdown(win.resets_at - now) or nil
  if left then out = out .. " ⟳" .. left end
  return out
end

--- The finished statusline string for `usage`, or "" when there's nothing
--- honest to show.
local function render(usage)
  if not usage then return "" end

  local now = os.time()
  local stale = tonumber(settings.stale_after) or 1800
  if stale > 0 and usage.fetched_at > 0 and (now - usage.fetched_at) > stale then
    return ""
  end

  local parts = {}
  for _, w in ipairs({ { "5h", usage.five_hour }, { "7d", usage.seven_day } }) do
    local s = render_window(w[1], w[2], now)
    if s then table.insert(parts, s) end
  end
  if #parts == 0 then return "" end
  -- Two spaces between groups, matching the rest of the statusline.
  return table.concat(parts, "  ") .. "%*"
end

-- ── Polling ───────────────────────────────────────────────────────────

local current = nil  -- the freshest normalised reading
local segment = ""   -- render(current), cached for the statusline
local seen = {}      -- path -> mtime of the last read
local polled = false -- has a read been attempted at all yet
local timer = nil

--- Re-read whichever source changed, keep the one fetched most recently.
local function poll()
  local changed = false
  for _, path in ipairs({ state_path, claude_json }) do
    local m = mtime(path)
    if m ~= seen[path] then
      seen[path] = m
      changed = true
    end
  end
  -- Keyed on `polled`, not on `current`: someone with no rate limits to
  -- report — an API-key setup, a free account — has files that never
  -- change and a reading that stays nil, and must not re-decode the 90 KB
  -- of ~/.claude.json every tick for the life of the session.
  if not changed and polled then
    -- Nothing new on disk, but the countdown still has to tick down and a
    -- window can lapse into staleness between polls.
    local rendered = render(current)
    if rendered ~= segment then
      segment = rendered
      vim.schedule(function() vim.cmd.redrawstatus() end)
    end
    return
  end

  polled = true
  local best = nil
  for _, reader in ipairs({ from_statusline, from_claude_json }) do
    local ok, usage = pcall(reader)
    if ok and usage and (not best or usage.fetched_at > best.fetched_at) then
      best = usage
    end
  end

  current = best
  local rendered = render(current)
  if rendered ~= segment then
    segment = rendered
    vim.schedule(function() vim.cmd.redrawstatus() end)
  end
end

local function start()
  if timer then return end
  timer = vim.uv.new_timer()
  local interval = math.max(tonumber(settings.interval) or 30, 5) * 1000
  -- The first read is deferred rather than immediate: startup has enough
  -- to do without two JSON decodes, and the segment appearing a moment
  -- late costs nothing.
  timer:start(1000, interval, vim.schedule_wrap(poll))
end

--- Called by :Reload before this module is discarded. Without it every
--- reload leaks a timer holding a closure over the old module.
function M.unload()
  if timer then
    timer:stop()
    if not timer:is_closing() then timer:close() end
    timer = nil
  end
end

--- The statusline component. A table lookup — see the header comment.
function M.statusline()
  return segment
end

--- Force a re-read, ignoring the mtime cache. Used by :ClaudeUsage.
function M.refresh()
  seen, polled = {}, false
  poll()
end

-- ── :ClaudeSetup ──────────────────────────────────────────────────────
-- ~/.claude/settings.json is outside this repo and holds things nothing
-- here put there — an org's permission policy, enabled plugins, your
-- model choice. So this is a command you run, not something that happens
-- at startup, it shows what it will change before changing it, and it
-- keeps a backup.

--- Through the symlink, deliberately. This config is normally reached as
--- ~/.config/nvim, and under `make try` as ~/.config/nvim-test — writing
--- either of those into a global settings.json would point Claude Code at
--- whatever that name happens to mean later, including a sandbox. The
--- checkout itself is the stable answer.
local function repo_root()
  local this = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(vim.uv.fs_realpath(this) or this, ":p:h:h:h")
end

local function scripts()
  local root = repo_root()
  return vim.fs.joinpath(root, "claude", "statusline.sh"),
    vim.fs.joinpath(root, "claude", "notify.sh")
end

local function hook_entry(command)
  return { { matcher = "", hooks = { { type = "command", command = command } } } }
end

--- Our three entries, layered onto whatever is already in the file.
local function with_integration(current_settings)
  local statusline_sh, notify_sh = scripts()
  local out = vim.deepcopy(current_settings)

  if settings.statusline ~= false then
    out.statusLine = { type = "command", command = statusline_sh }
  end

  if settings.notify ~= false then
    out.hooks = type(out.hooks) == "table" and out.hooks or {}
    out.hooks.Notification = hook_entry(notify_sh .. " attention")
    out.hooks.Stop = hook_entry(notify_sh .. " done")
  end

  return out
end

local function without_integration(current_settings)
  local out = vim.deepcopy(current_settings)
  out.statusLine = nil
  if type(out.hooks) == "table" then
    out.hooks.Notification = nil
    out.hooks.Stop = nil
    if next(out.hooks) == nil then out.hooks = nil end
  end
  return out
end

--- vim.json.encode emits one long line and cannot preserve key order, and
--- this is a file people hand-edit. jq restores the formatting when it's
--- there; the backup covers when it isn't.
local function encode(tbl)
  local text = vim.json.encode(tbl)
  if vim.fn.executable("jq") == 1 then
    local pretty = vim.system({ "jq", "." }, { stdin = text }):wait()
    if pretty.code == 0 and pretty.stdout and pretty.stdout ~= "" then
      return pretty.stdout
    end
  end
  return text .. "\n"
end

local function write_settings(tbl)
  local backup = settings_json .. ".bak." .. os.date("%Y%m%d%H%M%S")
  if vim.uv.fs_stat(settings_json) then
    local ok = vim.uv.fs_copyfile(settings_json, backup)
    if not ok then
      vim.notify("could not back up " .. settings_json .. " — nothing written",
        vim.log.levels.ERROR)
      return nil
    end
  else
    backup = nil
    vim.fn.mkdir(vim.fs.dirname(settings_json), "p")
  end

  local ok, err = pcall(function()
    local fd = assert(vim.uv.fs_open(settings_json, "w", 420))
    assert(vim.uv.fs_write(fd, encode(tbl), 0))
    vim.uv.fs_close(fd)
  end)
  if not ok then
    vim.notify("could not write " .. settings_json .. "\n" .. tostring(err),
      vim.log.levels.ERROR)
    return nil
  end
  return backup or "(no previous file)"
end

local function setup(remove)
  local existing = read_json(settings_json) or {}
  local wanted = remove and without_integration(existing) or with_integration(existing)

  if vim.deep_equal(existing, wanted) then
    vim.notify(remove and "Claude Code integration is not installed"
      or "Claude Code integration is already installed")
    return
  end

  local statusline_sh, notify_sh = scripts()
  for _, path in ipairs({ statusline_sh, notify_sh }) do
    if vim.fn.executable(path) ~= 1 then
      vim.notify(("%s is not executable — run: chmod +x %s"):format(path, path),
        vim.log.levels.ERROR)
      return
    end
  end

  local preview
  if remove then
    -- Worth saying plainly: this removes our three entries, it does not
    -- put back a Notification hook that was there before :ClaudeSetup ran.
    -- That one is in the backup this wrote at the time.
    preview = table.concat({
      "  statusLine         removed",
      "  hooks.Notification removed",
      "  hooks.Stop         removed",
      "",
      "  Any Notification hook you had before :ClaudeSetup is not restored;",
      "  it is in the backup that :ClaudeSetup made.",
    }, "\n")
  else
    local lines = {}
    if wanted.statusLine then
      table.insert(lines, "  statusLine         " .. statusline_sh)
    end
    if wanted.hooks and wanted.hooks.Notification then
      table.insert(lines, "  hooks.Notification " .. notify_sh .. " attention")
      table.insert(lines, "  hooks.Stop         " .. notify_sh .. " done")
    end
    preview = table.concat(lines, "\n")
  end

  local prompt = ("%s\n\n%s\n\nEverything else in that file is left alone, and it is backed up first."):format(
    settings_json, preview)

  if vim.fn.confirm(prompt, "&Write\n&Cancel", 2) ~= 1 then
    vim.notify("cancelled")
    return
  end

  local backup = write_settings(wanted)
  if not backup then return end

  vim.notify(("%s\nbackup: %s\n\nClaude Code picks this up on its next render; restart it if in doubt.")
    :format(remove and "Claude Code integration removed" or "Claude Code integration installed", backup))
  M.refresh()
end

-- ── Wiring ────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("ClaudeSetup", function(o)
  setup(o.bang)
end, { bang = true, desc = "Install (or with ! remove) the Claude Code statusLine and hooks" })

vim.api.nvim_create_user_command("ClaudeUsage", function()
  M.refresh()
  if not current then
    vim.notify(table.concat({
      "no Claude Code usage data found.",
      "",
      "  statusLine cache  " .. state_path,
      "  fallback          " .. claude_json .. " (cachedUsageUtilization)",
      "",
      "Rate limits are reported for Claude.ai Pro/Max only, and only after",
      "the first API response in a session. :ClaudeSetup installs the",
      "statusLine command that keeps the first file up to date.",
    }, "\n"), vim.log.levels.WARN)
    return
  end

  local age = os.time() - current.fetched_at
  local lines = { ("source: %s, %ds old"):format(current.source, age) }
  for _, w in ipairs({ { "5h", current.five_hour }, { "7d", current.seven_day } }) do
    if w[2] then
      local left = w[2].resets_at and countdown(w[2].resets_at - os.time())
      table.insert(lines, ("  %s  %d%%  resets in %s"):format(
        w[1], math.floor(w[2].pct + 0.5), left or "—"))
    end
  end
  vim.notify(table.concat(lines, "\n"))
end, { desc = "Show the Claude Code rate-limit numbers and where they came from" })

if settings.enabled ~= false and settings.statusline ~= false then
  start()
end

return M
