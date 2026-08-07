-- The stacked view: tabpages as collapsible groups, their buffers nested
-- underneath, in a fixed-width window down the left.
--
-- This is a window rather than a tabline because 'tabline' is a single
-- horizontal line by construction. See lua/core/tabs.lua, which owns the
-- model both views render from; this file only draws it.
--
-- One scratch buffer is shared by every tabpage's sidebar window, so a
-- single render updates all of them at once.

local config = require("core.config")

-- Lazy, to break the cycle: tabs.lua requires this module from inside
-- M.set(), which runs while tabs.lua is still loading.
local function tabs()
  return require("core.tabs")
end

local M = {}

M.enabled = false

local ns = vim.api.nvim_create_namespace("core.sidebar")
local group = vim.api.nvim_create_augroup("core.sidebar", { clear = true })

local view = nil       -- the shared scratch buffer
local meta = {}        -- 1-based line -> what clicking it does
local collapsed = {}   -- group key -> true
local rendering = false

-- ── Window plumbing ───────────────────────────────────────────────────

local function valid()
  return view and vim.api.nvim_buf_is_valid(view)
end

local function is_sidebar(win)
  return valid() and vim.api.nvim_win_get_buf(win) == view
end

local function sidebar_wins(tab)
  local out = {}
  if not valid() then return out end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if is_sidebar(w) then table.insert(out, w) end
  end
  return out
end

--- The window a chosen buffer should be loaded into: the first ordinary,
--- non-floating window of the current tabpage.
local function content_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_sidebar(w) and vim.api.nvim_win_get_config(w).relative == "" then
      return w
    end
  end
end

-- Creating and populating the window fires BufEnter/WinEnter, which route
-- straight back into a refresh. Suppress them rather than rely on the
-- reentrancy guard alone.
local function noauto(fn)
  local save = vim.o.eventignore
  vim.o.eventignore = "all"
  local ok, err = pcall(fn)
  vim.o.eventignore = save
  if not ok then error(err) end
end

-- ── Actions ───────────────────────────────────────────────────────────

local function fold(key)
  if not key then return end
  collapsed[key] = not collapsed[key] or nil
  M.render()
end

local function activate(line)
  local a = meta[line]
  if not a then return end

  if a.kind == "tab" then
    return fold(a.key)
  end

  if a.tab and vim.api.nvim_tabpage_is_valid(a.tab) then
    vim.api.nvim_set_current_tabpage(a.tab)
  end

  -- Already on screen in that tab: just go to it, don't disturb the layout.
  if a.win and vim.api.nvim_win_is_valid(a.win) then
    return vim.api.nvim_set_current_win(a.win)
  end

  local win = content_win()
  if not win then return end
  vim.api.nvim_set_current_win(win)
  if vim.api.nvim_buf_is_valid(a.buf) then
    vim.api.nvim_win_set_buf(win, a.buf)
  end
end

local function delete(line)
  local a = meta[line]
  if not a or a.kind ~= "buf" or not vim.api.nvim_buf_is_valid(a.buf) then return end

  if vim.bo[a.buf].modified then
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(a.buf), ":t")
    local choice = vim.fn.confirm(
      ("%s has unsaved changes."):format(name == "" and "[No Name]" or name),
      "&Save and close\n&Discard\n&Cancel", 3, "Question"
    )
    if choice == 1 then
      local ok = pcall(vim.api.nvim_buf_call, a.buf, function() vim.cmd("write") end)
      if not ok then return end
    elseif choice ~= 2 then
      return
    end
  end

  pcall(vim.api.nvim_buf_delete, a.buf, { force = true })
  M.render()
end

local function keymaps(buf)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  local function here(fn)
    return function() fn(vim.api.nvim_win_get_cursor(0)[1]) end
  end

  map("<CR>", here(activate), "sidebar: open")
  -- By the time a click reaches a mapping the cursor has already moved to
  -- it, so the mouse shares the <CR> path. Buffer-local, so it can't
  -- change what a click does in any other window.
  map("<LeftRelease>", here(activate), "sidebar: open (click)")
  map("<2-LeftMouse>", here(activate), "sidebar: open (double click)")

  map("<Tab>", here(function(l) fold(meta[l] and meta[l].key) end), "sidebar: fold group")
  map("za", here(function(l) fold(meta[l] and meta[l].key) end), "sidebar: fold group")
  map("d", here(delete), "sidebar: delete buffer")
  map("R", function() M.render() end, "sidebar: refresh")
  map("q", function() tabs().set("tabline") end, "sidebar: back to tabline")
end

local function ensure_buf()
  if valid() then return view end

  -- Adopt the buffer a previous incarnation of this module left behind,
  -- so reloading the config doesn't leak an orphan every time. The
  -- keymaps close over the old module and are re-set below.
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.b[b].core_sidebar then
      view = b
      keymaps(view)
      return view
    end
  end

  view = vim.api.nvim_create_buf(false, true)
  vim.b[view].core_sidebar = true
  vim.bo[view].buftype = "nofile"
  vim.bo[view].bufhidden = "hide"
  vim.bo[view].swapfile = false
  vim.bo[view].buflisted = false
  vim.bo[view].filetype = "sidebar"
  vim.bo[view].modifiable = false
  keymaps(view)
  return view
end

local function ensure_win()
  if #sidebar_wins(0) > 0 then return end
  local prev = vim.api.nvim_get_current_win()
  noauto(function()
    vim.cmd("topleft vsplit")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, ensure_buf())
    vim.api.nvim_win_set_width(win, config.tabs.width)
    for opt, value in pairs({
      winfixwidth = true, number = false, relativenumber = false,
      signcolumn = "no", foldcolumn = "0", wrap = false, list = false,
      spell = false, cursorline = true, statuscolumn = "",
    }) do
      vim.wo[win][opt] = value
    end
    if vim.api.nvim_win_is_valid(prev) then
      vim.api.nvim_set_current_win(prev)
    end
  end)
end

-- ── Drawing ───────────────────────────────────────────────────────────

local function segw(segments)
  local w = 0
  for _, s in ipairs(segments) do w = w + vim.fn.strdisplaywidth(s[1]) end
  return w
end

--- Compose one line from left and right segment lists, right-aligning the
--- status column. Only the LAST left segment is truncatable — everything
--- before it (indent, markers) is short and fixed.
local function compose(lines, marks, left, right, action)
  local width = config.tabs.width
  local fixed = 0
  for i = 1, #left - 1 do
    fixed = fixed + vim.fn.strdisplaywidth(left[i][1])
  end

  local segments = {}
  for i = 1, #left - 1 do table.insert(segments, left[i]) end
  local last = left[#left]
  if last then
    local budget = width - fixed - segw(right) - 1
    table.insert(segments, { tabs().truncate(last[1], math.max(budget, 1)), last[2] })
  end

  local pad = width - segw(segments) - segw(right)
  if pad > 0 then table.insert(segments, { string.rep(" ", pad) }) end
  vim.list_extend(segments, right)

  local row, text, col = #lines, "", 0
  for _, s in ipairs(segments) do
    if s[1] ~= "" then
      if s[2] then
        table.insert(marks, { row, col, col + #s[1], s[2] })
      end
      text = text .. s[1]
      col = col + #s[1]
    end
  end

  table.insert(lines, text)
  meta[#lines] = action
end

local function draw()
  local lines, marks = {}, {}
  meta = {}

  for _, t in ipairs(tabs().tree()) do
    local key = t.handle or "hidden"
    local open = not collapsed[key]

    -- Expanded, naming the group after its active buffer would just
    -- repeat the row below it — so title it by the tab instead, and by
    -- its :tcd directory when it has one. Collapsed, the active buffer is
    -- exactly what you want to see: it's the only clue to what's inside.
    local head
    if not t.handle then
      head = t.name
    elseif open then
      head = ("Tab %d%s"):format(t.index, t.cwd and ("  " .. t.cwd) or "")
    else
      head = ("Tab %d  %s"):format(t.index, t.name)
    end

    compose(lines, marks,
      { { (open and "▼" or "▶") .. " ", "Comment" },
        { head, t.current and "TabLineSel" or "TabLine" } },
      tabs().atoms(t.status, { diag = true, git = true }),
      { kind = "tab", key = key, tab = t.handle })

    if open then
      for _, b in ipairs(t.buffers) do
        local action = { kind = "buf", key = key, tab = t.handle, buf = b.buf, win = b.win }

        compose(lines, marks,
          { { "  " }, { (b.current and "●" or " ") .. " ", "Title" },
            { b.name, b.current and "Title" or "Normal" } },
          b.status.modified and { { " ✎", "WarningMsg" } } or {},
          action)

        if config.tabs.show_path then
          local right = tabs().atoms(b.status, { diag = true, git = true, modified = false })
          -- Skip the detail line when it would say nothing: a clean
          -- buffer at the cwd root doesn't need a blank second row.
          if b.dir ~= "" or #right > 0 then
            compose(lines, marks,
              { { "      " }, { b.dir, "Comment" } }, right, action)
          end
        end
      end
    end
  end

  local buf = ensure_buf()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, m[1], m[2], {
      end_col = m[3], hl_group = m[4],
    })
  end
end

-- ── Public ────────────────────────────────────────────────────────────

function M.render()
  if not M.enabled or rendering then return end
  -- The guard belongs here, not only in open(): a refresh scheduled during
  -- startup can otherwise win the race against VimEnter and split the
  -- window before the first file is even loaded.
  if vim.v.vim_did_enter == 0 then return end
  rendering = true
  local ok, err = pcall(function()
    ensure_win()
    draw()
  end)
  rendering = false
  if not ok then
    vim.notify("sidebar: " .. tostring(err), vim.log.levels.WARN)
  end
end

function M.open()
  M.enabled = true
  -- During startup there is no meaningful buffer list yet, and splitting
  -- before the first file is loaded puts the sidebar on the wrong side of
  -- the initial window.
  if vim.v.vim_did_enter == 0 then
    vim.api.nvim_create_autocmd("VimEnter", {
      group = group, once = true,
      callback = function() M.render() end,
    })
    return
  end
  M.render()
end

function M.close()
  M.enabled = false
  if not valid() then return end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, w in ipairs(sidebar_wins(tab)) do
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
end

-- Never let the sidebar be the only thing holding a tabpage open — with
-- nothing else to switch to, :q on the last real window would leave you
-- staring at a file list you can't quit out of.
-- WinClosed as well as WinEnter: if the sidebar already has focus when the
-- last real window goes away, no WinEnter fires and the check would never
-- run. Scheduled because during WinClosed the window is still open.
vim.api.nvim_create_autocmd({ "WinEnter", "WinClosed" }, {
  group = group,
  callback = function()
    vim.schedule(function()
      if not M.enabled or not valid() then return end
      local wins = vim.tbl_filter(function(w)
        return vim.api.nvim_win_get_config(w).relative == ""
      end, vim.api.nvim_tabpage_list_wins(0))
      if #wins == 1 and is_sidebar(wins[1]) then
        vim.cmd(#vim.api.nvim_list_tabpages() > 1 and "tabclose" or "quit")
      end
    end)
  end,
})

return M
