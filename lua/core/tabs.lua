-- Tabs: one model, two views.
--
-- Vim's 'tabline' is structurally a single horizontal line — the format
-- string returns one line and there is no option to rotate it. So a
-- stacked, left-hand list can't be a tabline at all; it has to be a real
-- window. That's lua/core/sidebar.lua. Both views read the tree() below,
-- so they can never drift apart in what they report.
--
--   settings.tabs.display = "tabline"  top strip, one entry per tabpage
--                         = "sidebar"  left window, buffers nested per tab
--                         = "none"     neither
--
-- Everything here is recomputed on redraw, so it stays cheap: no shelling
-- out, no git calls. gitsigns already puts per-buffer hunk counts in a
-- buffer var, and diagnostics are counted from the running LSP.

local config = require("core.config")

local M = {}

M.mode = nil

-- Publish before the module finishes loading. M.set() at the bottom of
-- this file reaches into sidebar.lua, which reaches straight back here for
-- the model — and a plain require() would call that a cycle and fail. It
-- only bites when this module is re-required into a running Neovim (a
-- config reload), because at startup the sidebar defers to VimEnter by
-- which time loading is done. Everything the sidebar needs is defined
-- above M.set(), so the partial table it sees is complete enough.
package.loaded["core.tabs"] = M

-- Loaded lazily, and only in sidebar mode. Also breaks the require cycle:
-- sidebar.lua reaches back into this module for the model.
local function sidebar()
  return require("core.sidebar")
end

-- ── Model ─────────────────────────────────────────────────────────────

-- An untouched, unnamed buffer — the one :tabnew hands you before you
-- open anything. Listing it is noise: there's nothing to go back to.
local function scratch(buf)
  if vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].modified then return false end
  if not vim.api.nvim_buf_is_loaded(buf) then return true end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, 2, false)
  return #lines <= 1 and (lines[1] or "") == ""
end

local function listed(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buflisted
    and (buf == vim.api.nvim_get_current_buf() or not scratch(buf))
end

local function label(buf)
  if vim.bo[buf].buftype == "terminal" then
    return vim.b[buf].term_title or "[terminal]"
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then return "[No Name]" end
  return vim.fn.fnamemodify(name, ":t")
end

local function dir(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or vim.bo[buf].buftype ~= "" then return "" end
  return vim.fn.fnamemodify(name, ":~:.:h")
end

local function status(buf)
  local s = {
    modified = vim.bo[buf].modified,
    errors = 0, warnings = 0,
    added = 0, changed = 0, removed = 0,
  }
  if config.tabs.show_diagnostics then
    local n = vim.diagnostic.count(buf)
    s.errors = n[vim.diagnostic.severity.ERROR] or 0
    s.warnings = n[vim.diagnostic.severity.WARN] or 0
  end
  if config.tabs.show_git then
    local d = vim.b[buf].gitsigns_status_dict
    if d then
      s.added, s.changed, s.removed = d.added or 0, d.changed or 0, d.removed or 0
    end
  end
  return s
end

local function aggregate(buffers)
  local s = {
    modified = false,
    errors = 0, warnings = 0,
    added = 0, changed = 0, removed = 0,
  }
  for _, b in ipairs(buffers) do
    s.modified = s.modified or b.status.modified
    for _, k in ipairs({ "errors", "warnings", "added", "changed", "removed" }) do
      s[k] = s[k] + b.status[k]
    end
  end
  return s
end

-- A buffer shown in a tabpage's window obviously belongs to that tabpage.
-- A hidden buffer belongs to none of them, so remember where it was last
-- active: without this, :b-ing away from a file would make it disappear
-- from the list entirely, which is the opposite of what a buffer list is
-- for.
local owner = {}

local function entry(buf, win, cur_buf)
  return {
    buf = buf,
    win = win,
    name = label(buf),
    dir = dir(buf),
    current = buf == cur_buf,
    status = status(buf),
  }
end

local function by_name(a, b)
  if a.name == b.name then return a.buf < b.buf end
  return a.name < b.name
end

--- The shared model: an ordered list of tabpages, each with its buffers.
--- Both the tabline and the sidebar render from this.
function M.tree()
  local cur_tab = vim.api.nvim_get_current_tabpage()
  local cur_buf = vim.api.nvim_get_current_buf()
  -- While the sidebar has focus the current buffer IS the sidebar, so
  -- nothing would carry the marker exactly when you're looking at the
  -- list. Fall back to what this tabpage is showing.
  if not listed(cur_buf) then
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(cur_tab)) do
      local b = vim.api.nvim_win_get_buf(w)
      if listed(b) then
        cur_buf = b
        break
      end
    end
  end
  local tabs, index, visible = {}, {}, {}

  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local t = { handle = tab, index = i, current = tab == cur_tab, buffers = {} }

    local win = vim.api.nvim_tabpage_get_win(tab)
    if vim.api.nvim_win_is_valid(win) then
      t.active = vim.api.nvim_win_get_buf(win)
    end

    local seen = {}
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local buf = vim.api.nvim_win_get_buf(w)
      if listed(buf) and not seen[buf] then
        seen[buf] = true
        visible[buf] = true
        owner[buf] = tab
        table.insert(t.buffers, entry(buf, w, cur_buf))
      end
    end

    tabs[i], index[tab] = t, t
  end

  local orphans = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if listed(buf) and not visible[buf] then
      local home = owner[buf] and index[owner[buf]]
      table.insert(home and home.buffers or orphans, entry(buf, nil, cur_buf))
    end
  end

  for _, t in ipairs(tabs) do
    table.sort(t.buffers, by_name)
    t.name = t.active and label(t.active) or "[No Name]"
    t.dir = t.active and dir(t.active) or ""
    t.status = aggregate(t.buffers)
    -- Only when :tcd gave the tab its own directory. The sidebar titles
    -- groups with it, which is the whole point of a per-tab cwd.
    if vim.fn.haslocaldir(-1, t.index) == 1 then
      t.cwd = vim.fn.fnamemodify(vim.fn.getcwd(-1, t.index), ":t")
    end
  end

  if #orphans > 0 then
    table.sort(orphans, by_name)
    table.insert(tabs, {
      name = "Hidden", dir = "", buffers = orphans, status = aggregate(orphans),
    })
  end

  return tabs
end

-- ── Shared formatting ─────────────────────────────────────────────────

--- Status atoms for one buffer or one tabpage, most important first, as
--- { text, highlight-group } pairs. `opts` gates the categories so the
--- tabline can shed them under pressure; the sidebar passes everything.
--- Highlight groups are all ones the colorscheme already defines — see
--- the note in lua/core/theme.lua about surviving the light/dark flip.
function M.atoms(s, opts)
  local out = {}
  local function add(text, hl) table.insert(out, { text, hl }) end

  if opts.modified ~= false and s.modified then add("✎", "WarningMsg") end
  if opts.diag then
    if s.errors > 0 then add(("✖%d"):format(s.errors), "DiagnosticError") end
    if s.warnings > 0 then add(("⚠%d"):format(s.warnings), "DiagnosticWarn") end
  end
  if opts.git then
    if s.added > 0 then add(("+%d"):format(s.added), "Added") end
    if s.changed > 0 then add(("~%d"):format(s.changed), "Changed") end
    if s.removed > 0 then add(("-%d"):format(s.removed), "Removed") end
  end
  return out
end

--- Clip to `max` display cells, marking the cut with an ellipsis.
function M.truncate(s, max)
  if max < 2 or vim.fn.strdisplaywidth(s) <= max then return s end
  return vim.fn.strcharpart(s, 0, max - 1) .. "…"
end

-- ── Tabline view ──────────────────────────────────────────────────────

-- A '%' in a filename would be read as a format item.
local function esc(s)
  return (s:gsub("%%", "%%%%"))
end

local function build(tabs, opts)
  local parts, width = {}, 0

  for _, t in ipairs(tabs) do
    if t.handle then
      local bits = { tostring(t.index), M.truncate(t.name, opts.name_width or 999) }
      if opts.path and t.dir ~= "" then
        table.insert(bits, M.truncate(t.dir, 20))
      end
      -- Monochrome per tab: the whole label takes TabLine/TabLineSel, so
      -- the selected tab stays visually one block. The sidebar has room
      -- to colour each atom individually; one line does not.
      for _, a in ipairs(M.atoms(t.status, opts)) do
        table.insert(bits, a[1])
      end

      local text = " " .. table.concat(bits, " ") .. " "
      width = width + vim.fn.strdisplaywidth(text)

      local hl = t.current and "%#TabLineSel#" or "%#TabLine#"
      -- %{n}T opens a native click region: Neovim switches to tab n on a
      -- mouse click by itself, no Lua handler needed. %T below closes the
      -- last one.
      table.insert(parts, ("%%%dT%s%s"):format(t.index, hl, esc(text)))
    end
  end

  return table.concat(parts) .. "%T%#TabLineFill#", width
end

-- Tried in order until one fits. Horizontal room is scarce, so give up
-- hunk counts before diagnostics — a warning is worth more than a hunk —
-- and only then start clipping names.
local levels = {
  { git = true,  path = true,  diag = true },
  { git = true,  path = false, diag = true },
  { git = false, path = false, diag = true },
  { git = false, path = false, diag = false },
}

function _G.NvimTabline()
  local tabs = M.tree()

  -- Two tabs showing different init.lua files are indistinguishable
  -- without their directories, but a directory costs width — so only pay
  -- for it when there's an actual collision.
  local count, collide = {}, false
  for _, t in ipairs(tabs) do
    if t.handle then
      count[t.name] = (count[t.name] or 0) + 1
      if count[t.name] > 1 then collide = true end
    end
  end

  for _, level in ipairs(levels) do
    local s, w = build(tabs, {
      git = level.git,
      path = collide and level.path,
      diag = level.diag,
    })
    if w <= vim.o.columns then return s end
  end

  -- Still over. Clip names to a fair share of the line rather than let
  -- the trailing tabs fall off the right edge entirely.
  local share = math.max(6, math.floor(vim.o.columns / math.max(#tabs, 1)) - 8)
  return (build(tabs, { name_width = share }))
end

-- ── Mode ──────────────────────────────────────────────────────────────

local modes = { tabline = true, sidebar = true, none = true }

--- Switch display mode. Safe to call repeatedly.
function M.set(mode)
  if not modes[mode] then
    vim.notify(
      ("unknown tabs.display %q — want tabline, sidebar or none"):format(tostring(mode)),
      vim.log.levels.WARN
    )
    return
  end

  M.mode = mode
  vim.o.showtabline = mode == "tabline" and 1 or 0

  if mode == "sidebar" then
    sidebar().open()
  elseif package.loaded["core.sidebar"] then
    sidebar().close()
  end

  M.refresh()
end

function M.toggle()
  M.set(M.mode == "sidebar" and "tabline" or "sidebar")
end

--- Called by :Reload before this module is thrown away. The sidebar's
--- windows are only reachable through this incarnation, so they have to
--- go now — otherwise the next one splits a second sidebar beside them.
function M.unload()
  M.set("none")
end

-- Events arrive in bursts — one :bdelete can fire four of them — so
-- coalesce into a single redraw per tick instead of rendering four times.
local pending = false

function M.refresh()
  if M.mode == "tabline" then
    vim.cmd("redrawtabline")
  elseif M.mode == "sidebar" and not pending then
    pending = true
    vim.schedule(function()
      pending = false
      if M.mode == "sidebar" then sidebar().render() end
    end)
  end
end

-- ── Wiring ────────────────────────────────────────────────────────────

local group = vim.api.nvim_create_augroup("core.tabs", { clear = true })

vim.api.nvim_create_autocmd({
  "BufAdd", "BufDelete", "BufFilePost", "BufModifiedSet", "BufWritePost",
  "TabNew", "TabClosed", "TabEnter", "WinEnter", "WinClosed",
  "DiagnosticChanged", "LspAttach", "LspDetach",
}, {
  group = group,
  callback = function() M.refresh() end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "GitSignsUpdate",
  group = group,
  callback = function() M.refresh() end,
})

-- Ownership is tracked even when display is "none", so switching modes
-- mid-session shows a correct list straight away rather than an empty one.
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(ev)
    if listed(ev.buf) then
      owner[ev.buf] = vim.api.nvim_get_current_tabpage()
    end
    M.refresh()
  end,
})

vim.api.nvim_create_autocmd("BufDelete", {
  group = group,
  callback = function(ev) owner[ev.buf] = nil end,
})

vim.api.nvim_create_user_command("Tabs", function(o)
  M.set(o.args ~= "" and o.args or M.mode)
end, {
  nargs = "?",
  complete = function() return { "tabline", "sidebar", "none" } end,
  desc = "tabs: set display mode",
})

vim.api.nvim_create_user_command("TabsToggle", function()
  M.toggle()
end, { desc = "tabs: toggle sidebar / tabline" })

vim.o.tabline = "%!v:lua.NvimTabline()"

M.set(config.tabs.display)

return M
