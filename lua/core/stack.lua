-- Stacked windows: i3/sway's `layout stacking`, for one column inside a tab.
--
-- In i3, stacking is a property of a CONTAINER, not of the workspace. One
-- container's children stack — one visible, the rest reduced to title bars —
-- while everything else in the layout stays tiled. That's what this is: the
-- focused member of one column fills it, every other member of that column
-- collapses to a single row, and the sidebar, any vsplit neighbour and the
-- terminal splits are left exactly where they were.
--
-- ┌────────────────────────────────────────────────────────────────────┐
-- │  ┌─ sidebar ─┐┌──────────────────────────┐                        │
-- │  │ ▼ Tab 1   ││                          │  the expanded member   │
-- │  │  ● one.lua││   one.lua                │                        │
-- │  │    two.lua│└──────────────────────────┘                        │
-- │  │ ▶ Tab 2   │  two.lua            ✎ ✖1     ← collapsed: 1 row,    │
-- │  │           │  README.md                     and that row is its  │
-- │  └───────────┘                                statusline           │
-- └────────────────────────────────────────────────────────────────────┘
--
-- ╭─ HOW A COLLAPSED WINDOW IS ONE ROW ────────────────────────────────╮
-- │ 'winminheight' 0 lets a window shrink to zero TEXT lines. What's   │
-- │ left is its statusline — one row — and that is the title bar. It   │
-- │ therefore only works under 'laststatus' 2: at 3 there are no       │
-- │ per-window statuslines, so a collapsed member would draw zero rows │
-- │ and vanish. A tabpage holding a stack runs at 2; every other tab   │
-- │ keeps the global statusline, and M.chrome() flips between them.    │
-- │                                                                    │
-- │ 'winbar' cannot do this job: a window with one can never go below  │
-- │ 1 text line, so each collapsed member would cost 2 rows, not 1.    │
-- ╰────────────────────────────────────────────────────────────────────╯
--
-- <C-j> / <C-k> ARE the stack navigation. A collapsed member is an ordinary
-- window that happens to be one row tall, so `wincmd j` walks into it and
-- the WinEnter below expands it. ,zj / ,zk exist only to wrap at the ends.
--
-- The model is tag-primary but frame-authoritative: w:core_stack marks a
-- member, and vim.fn.winlayout() decides what the column actually contains.
-- Nothing is bookkept across events — M.members() recomputes and reconciles
-- every time, the same discipline core.tabs applies to its tab tree.

local config = require("core.config")

local M = {}

local group = vim.api.nvim_create_augroup("core.stack", { clear = true })

local TITLE = "%!v:lua.NvimStackTitle()"

-- Captured at load. core.options runs before this module on both startup and
-- :Reload, so these are the config's own values rather than whatever a
-- stacked tabpage happened to leave behind.
local baseline_laststatus = vim.o.laststatus
local baseline_winminheight = vim.o.winminheight

local last_active = {} -- tabpage -> the member that was expanded
local pending = {}     -- tabpage -> a render is already queued
local retries = {}     -- tabpage -> consecutive passes that didn't converge
local applying = false

-- ── Plumbing ──────────────────────────────────────────────────────────

local function refuse(msg)
  vim.notify("stack: " .. msg, vim.log.levels.WARN)
end

local function here(tab)
  if tab == nil or tab == 0 then return vim.api.nvim_get_current_tabpage() end
  return tab
end

-- Resizing fires WinEnter/WinResized, which route straight back into a
-- refresh. Suppress them rather than rely on the reentrancy guard alone —
-- the same helper, and the same reasoning, as core.sidebar.
local function noauto(fn)
  local save = vim.o.eventignore
  vim.o.eventignore = "all"
  local ok, err = pcall(fn)
  vim.o.eventignore = save
  if not ok then error(err) end
end

--- 'winminheight' has to be 0 for a member to reach zero text lines. It's a
--- global option, and unlike 'laststatus' it is invisible: a window only
--- shrinks if something explicitly shrinks it. So it goes to 0 once, when
--- the first stack appears, rather than flipping per tabpage for no gain.
local function allow_collapse()
  if vim.o.winminheight ~= 0 then vim.o.winminheight = 0 end
end

-- Windows nobody means as column content. Terminals are deliberately NOT
-- here: mixing a shell in with your files is the point of a stack, and
-- park() below is what makes it safe.
local skip = { quickfix = true, help = true, prompt = true, nofile = true }

--- Why this window can't be a stack member, as a sentence, or nil if it can.
--- Returning the REASON rather than a boolean is the point: "that's not a
--- file window" is true of five different things and useless for all of them.
---
--- `explicit` relaxes the one rule that exists purely to stop AUTOMATIC
--- adoption. The <Leader>cs / <Leader>cc terminals are toggleable overlays
--- that own their own height, opened with `botright split` — which, in a tab
--- with no vsplit, lands them inside the stack's own column frame, where
--- being swept up by a stray :split would put core.stack and the toggle in a
--- fight over one window. But deliberately stacking a column that has one in
--- it is a choice, and it's yours to make.
local function why_not(win, explicit)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return "no window here"
  end
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return "that's a floating window"
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.b[buf].core_sidebar then
    return "that's the tab sidebar — step into a file window first (<C-l>)"
  end
  if not explicit and vim.b[buf].core_term_slot then
    return "that's a toggleable <Leader>c terminal"
  end
  local bt = vim.bo[buf].buftype
  if bt == "terminal" then return nil end
  if skip[bt] then
    return ("a %s window can't be a stack member"):format(bt)
  end
  return nil
end

local function eligible(win, explicit)
  return why_not(win, explicit) == nil
end

-- ── Parking a terminal ────────────────────────────────────────────────
--
-- ╭─ WHY A TERMINAL IS NOT COLLAPSED THE WAY A FILE IS ────────────────╮
-- │ Neovim refuses to shrink a terminal window below one text line —   │
-- │ ask for 0 and you get 1. And at one line the PTY reflows onto a    │
-- │ one-row screen, which destroys everything the job prints while it  │
-- │ is collapsed. Measured: of 50 lines written to a shrunk terminal,  │
-- │ 0 survived. Of 50 written to a HIDDEN one, all 50 did.             │
-- │                                                                    │
-- │ So a collapsed terminal member doesn't hold its terminal at all.   │
-- │ The buffer is swapped out for a scratch one — which collapses to   │
-- │ zero rows like any other — and the terminal goes hidden, keeping   │
-- │ its size and its scrollback exactly as <Leader>cs already relies   │
-- │ on. The title row still names it, because the window remembers     │
-- │ what it parked.                                                    │
-- ╰────────────────────────────────────────────────────────────────────╯

local park_scratch = nil

local function park_buf()
  if park_scratch and vim.api.nvim_buf_is_valid(park_scratch) then
    return park_scratch
  end
  -- Adopt the buffer a previous incarnation left behind, so :Reload doesn't
  -- leak one every time — the same trick core.sidebar uses for its view.
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.b[b].core_stack_park then
      park_scratch = b
      return b
    end
  end
  park_scratch = vim.api.nvim_create_buf(false, true)
  vim.b[park_scratch].core_stack_park = true
  vim.bo[park_scratch].buftype = "nofile"
  vim.bo[park_scratch].bufhidden = "hide"
  vim.bo[park_scratch].swapfile = false
  vim.bo[park_scratch].buflisted = false
  vim.bo[park_scratch].modifiable = false
  return park_scratch
end

--- Swap a terminal out of a window that is about to collapse, remembering
--- what it held. No-op for anything that isn't a terminal.
local function park(win)
  if vim.w[win].core_stack_parked then return end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "terminal" then return end
  vim.w[win].core_stack_parked = buf
  vim.api.nvim_win_set_buf(win, park_buf())
end

--- Put the terminal back. Safe to call on any window.
local function unpark(win)
  local buf = vim.w[win].core_stack_parked
  if not buf then return end
  vim.w[win].core_stack_parked = nil
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_win_set_buf(win, buf)
  end
end

--- Is this member showing a parked terminal rather than its own buffer?
local function is_parked(win)
  local buf = vim.w[win].core_stack_parked
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

--- Forget a window entirely: it becomes adoptable again.
local function strip(win)
  if not vim.api.nvim_win_is_valid(win) then return end
  -- Before anything else: a window leaving the stack must get its terminal
  -- back, or the job is left running with no window pointing at it.
  unpark(win)
  vim.w[win].core_stack = nil
  vim.wo[win].winfixheight = false
  vim.wo[win].statusline = ""
end

--- Mark a window as deliberately NOT a member. `false` rather than nil,
--- because nil means "never asked" and would be adopted straight back on the
--- next pass when stack.adopt is on.
local function release(win)
  if not vim.api.nvim_win_is_valid(win) then return end
  unpark(win)
  vim.w[win].core_stack = false
  vim.wo[win].winfixheight = false
  vim.wo[win].statusline = ""
end

--- Give up on a stack and leave ordinary splits behind. Separate from
--- M.unstack() because this is the involuntary version: called from
--- M.members() the moment the layout stops being describable as a column.
local function dissolve(wins)
  local anchor
  for _, w in ipairs(wins) do
    if vim.api.nvim_win_is_valid(w) then anchor = anchor or w end
    strip(w)
  end
  if anchor then
    pcall(noauto, function()
      vim.api.nvim_win_call(anchor, function() vim.cmd("wincmd =") end)
    end)
  end
end

--- The children of the innermost `col` frame holding `win` as a direct leaf,
--- or nil when it isn't in one. This — not window order, and not the order
--- nvim_tabpage_list_wins() happens to return — is what "the column this
--- window is in" means; winlayout() is the only thing that knows.
local function column(tab, win)
  local function walk(node, siblings)
    if node[1] == "leaf" then
      return node[2] == win and siblings or nil
    end
    local children = node[2]
    for _, child in ipairs(children) do
      local found = walk(child, node[1] == "col" and children or nil)
      if found then return found end
    end
    return nil
  end
  local ok, layout = pcall(vim.fn.winlayout, vim.api.nvim_tabpage_get_number(tab))
  if not ok then return nil end
  return walk(layout, nil)
end

--- How many screen rows the whole column occupies, members and non-members
--- alike. M.remove() needs this and the members' own total won't do: the
--- window being released is usually the expanded one, holding nearly every
--- row in the column, so measuring what's left would hand it a share of
--- almost nothing.
local function column_rows(tab, win)
  local siblings = column(tab, win)
  if not siblings then return nil end
  local total = 0
  for _, node in ipairs(siblings) do
    if node[1] == "leaf" and vim.api.nvim_win_is_valid(node[2]) then
      total = total + vim.api.nvim_win_get_height(node[2]) + 1
    end
  end
  return total
end

-- ── The model ─────────────────────────────────────────────────────────

--- The stack's members, top to bottom, reconciling tags against the layout
--- as it goes: a tagged window that has drifted out of the column is
--- released, an untagged eligible one inside it is adopted, and a stack
--- that is down to fewer than two members dissolves. Returns {} when this
--- tabpage has no stack.
function M.members(tab)
  tab = here(tab)
  if not config.stack.enabled or not vim.api.nvim_tabpage_is_valid(tab) then
    return {}
  end

  local tagged = {}
  local seed
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.w[w].core_stack == true then
      table.insert(tagged, w)
      seed = seed or w
    end
  end
  if not seed then return {} end

  local siblings = column(tab, seed)
  if not siblings then
    -- The seed is no longer a leaf of any column — <C-w>H moved it out into
    -- a column of its own, or the other members closed and it's alone now.
    -- Either way there is no stack left to speak of.
    --
    -- dissolve(), not a bare strip(): the survivors are still collapsed to
    -- zero rows, and untagging them without giving the height back leaves
    -- invisible windows behind that nothing will ever expand.
    dissolve(tagged)
    return {}
  end

  local out, inside = {}, {}
  for _, node in ipairs(siblings) do
    if node[1] == "leaf" and vim.api.nvim_win_is_valid(node[2]) then
      local w = node[2]
      local tag = vim.w[w].core_stack
      if tag == true then
        table.insert(out, w)
        inside[w] = true
      elseif tag == nil and config.stack.adopt and eligible(w) then
        -- A :split made inside the column joins the stack, which is what i3
        -- does. w: vars are not inherited by a new window, so this is the
        -- only thing that brings one in.
        vim.w[w].core_stack = true
        table.insert(out, w)
        inside[w] = true
      end
    end
  end

  for _, w in ipairs(tagged) do
    if not inside[w] then
      -- Tagged, but no longer a direct leaf of the column. A :vsplit of a
      -- member is what does this: it turns that member into a `row` nested
      -- inside the column, and once one member is a row, "a column of
      -- windows" has stopped describing the layout. Dropping just that
      -- window would leave the survivors squeezed into the two rows the
      -- split didn't take — a stack wedged beside a full-height pair, which
      -- reads as a bug. Ending the stack is the honest answer, and <Leader>zz
      -- puts it back.
      dissolve(vim.list_extend(tagged, out))
      return {}
    end
  end

  if #out < 2 then
    -- dissolve(), not a bare strip loop: stripping clears the tag and
    -- 'winfixheight' but hands no rows back, so a member that was collapsed
    -- stays at zero rows — and with 'laststatus' going back to 3 it loses its
    -- statusline row as well and vanishes entirely. Every path that ends a
    -- stack comes through here, :q on the expanded member included.
    dissolve(out)
    return {}
  end
  return out
end

--- Which member is expanded. The current window whenever it is one — that
--- invariant is what keeps apply() correct, see the note there — otherwise
--- the one that was expanded last, otherwise the top of the column.
local function active_of(tab, members)
  local cur = vim.api.nvim_get_current_win()
  for _, w in ipairs(members) do
    if w == cur then return w end
  end
  for _, w in ipairs(members) do
    if w == last_active[tab] then return w end
  end
  return members[1]
end

--- The window a buffer should actually be dropped into. core.sidebar calls
--- this through target_win(): the first content window of a stacked tab can
--- be a collapsed member, and putting a file in a window with no rows looks
--- exactly like nothing happened.
function M.expand(win)
  if not win or not vim.api.nvim_win_is_valid(win) then return win end
  if vim.w[win].core_stack ~= true then return win end
  local tab = vim.api.nvim_win_get_tabpage(win)
  local members = M.members(tab)
  if #members < 2 then return win end
  return active_of(tab, members)
end

-- ── Geometry ──────────────────────────────────────────────────────────

--- 'laststatus' for the CURRENT tabpage only — it's a global option, but the
--- statusline it controls is visible per window, so a tab without a stack
--- has to keep the global one.
function M.chrome(tab, members)
  tab = here(tab)
  if tab ~= vim.api.nvim_get_current_tabpage() then return end
  members = members or M.members(tab)
  local want = (#members >= 2) and 2 or baseline_laststatus
  if vim.o.laststatus ~= want then vim.o.laststatus = want end
end

--- Is the column already in the shape we'd give it? apply() is idempotent
--- by construction, but WinResized is delivered at redraw time — after
--- 'eventignore' has been restored — so our own resizes can echo back. This
--- turns that echo into a no-op instead of a second pass.
local function settled(members, active)
  for _, w in ipairs(members) do
    local h = vim.api.nvim_win_get_height(w)
    if w == active then
      -- A parked active member is never settled: it's showing the scratch
      -- buffer instead of the terminal you just moved onto.
      if h < 1 or is_parked(w) then return false end
    elseif h ~= 0 then
      return false
    elseif vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "terminal" then
      -- Collapsed and still holding a live terminal: park() hasn't run yet.
      return false
    end
    -- scope = "local" rather than vim.wo: 'statusline' is global-or-local,
    -- and vim.wo hands back the GLOBAL value for a window whose local one is
    -- empty. The active member's local value IS empty — that's how it falls
    -- back to the ordinary statusline — so vim.wo would report
    -- "%!v:lua.NvimStatusline()" here, never compare equal, and settled()
    -- would return false forever: no early-out, and three wasted retries
    -- after every single pass.
    local sl = vim.api.nvim_get_option_value("statusline", { win = w, scope = "local" })
    if sl ~= ((w == active) and "" or TITLE) then return false end
  end
  return true
end

--- Collapse every member but the active one. Idempotent, and self-correcting:
--- the column's total is recomputed from live heights every pass, so a
--- `botright split` that stole rows is absorbed by the next call rather than
--- leaving the stack permanently short.
function M.apply(tab)
  tab = here(tab)
  if not config.stack.enabled or not vim.api.nvim_tabpage_is_valid(tab) then
    return
  end

  local members = M.members(tab)
  if #members < 2 then
    M.chrome(tab, members)
    return
  end

  local active = active_of(tab, members)
  last_active[tab] = active
  if settled(members, active) then
    M.chrome(tab, members)
    return
  end

  applying = true
  local ok, err = pcall(noauto, function()
    local total = 0
    for _, w in ipairs(members) do
      total = total + vim.api.nvim_win_get_height(w) + 1
    end

    for _, w in ipairs(members) do
      vim.wo[w].winfixheight = false
    end

    -- Buffers before geometry. Unparking the active member first gives its
    -- terminal back the window it's about to be sized into; parking the rest
    -- is what lets them reach zero rows at all, since a window still holding
    -- a terminal is clamped to one line.
    unpark(active)
    for _, w in ipairs(members) do
      if w ~= active then park(w) end
    end

    -- ╭─ WHY nvim_win_call ──────────────────────────────────────────────╮
    -- │ 'winheight' floors the CURRENT window at 1 text line and cannot  │
    -- │ be set to 0. Resize while standing in a collapsed member and Vim │
    -- │ refuses to let that member reach zero, stranding a sibling at 1  │
    -- │ row — measured, repeatedly. Standing in the member being         │
    -- │ expanded makes the floor apply to the only window that wants     │
    -- │ height anyway, and the problem stops existing.                   │
    -- ╰──────────────────────────────────────────────────────────────────╯
    vim.api.nvim_win_call(active, function()
      for _, w in ipairs(members) do
        if w ~= active then vim.api.nvim_win_set_height(w, 0) end
      end
      vim.api.nvim_win_set_height(active, math.max(total - #members, 1))
    end)

    for _, w in ipairs(members) do
      -- 'winfixheight' is what protects the collapse from Vim's own
      -- equalise pass, which is why 'equalalways' can stay on: a :split
      -- anywhere else in the tab leaves the stack alone.
      vim.wo[w].winfixheight = true
      vim.wo[w].statusline = (w == active) and "" or TITLE
      -- Defensive: a winbar would put a floor of 1 text line under every
      -- collapsed member, doubling what each one costs.
      vim.wo[w].winbar = ""
    end
  end)
  applying = false

  M.chrome(tab, members)
  if not ok then
    refuse(tostring(err))
    return
  end

  -- One pass isn't always enough. If the layout was still moving underneath
  -- us — a window being created, the sidebar being rebuilt by :Reload — the
  -- heights we just asked for aren't the heights we got, and there may be no
  -- further event coming to notice. Retry, but bounded: a stack that cannot
  -- converge in three passes is wedged, and looping on it would be worse
  -- than leaving it visibly wrong.
  if settled(members, active) then
    retries[tab] = nil
  else
    local n = (retries[tab] or 0) + 1
    if n <= 3 then
      retries[tab] = n
      vim.schedule(function() M.apply(tab) end)
    else
      retries[tab] = nil
    end
  end
end

--- Coalesce to one pass per tick per tabpage. Events arrive in bursts —
--- one :split fires WinNew, WinEnter and WinResized — and each of those
--- wants the same single answer.
function M.schedule(tab)
  if applying then return end
  tab = here(tab)
  if pending[tab] then return end
  pending[tab] = true
  vim.schedule(function()
    pending[tab] = nil
    M.apply(tab)
  end)
end

-- ── Commands ──────────────────────────────────────────────────────────

--- Stack the column the current window is in.
function M.create()
  local tab = vim.api.nvim_get_current_tabpage()
  local win = vim.api.nvim_get_current_win()

  -- Without this the tags go on, 'winminheight' goes to 0, and apply() then
  -- returns early — leaving a column of windows marked as a stack that
  -- nothing will ever collapse or reconcile, because members() is disabled
  -- too. Refusing is the only coherent answer.
  if not config.stack.enabled then
    return refuse("stacking is off — set stack.enabled in lua/settings.lua")
  end
  -- Standing in the sidebar is easy to do — you just clicked a file, or
  -- walked left with <C-h> — and refusing there is technically correct and
  -- practically useless: there is exactly one column you could have meant.
  -- Aim at it instead of complaining.
  if vim.b[vim.api.nvim_win_get_buf(win)].core_sidebar then
    local ok, sidebar = pcall(require, "core.sidebar")
    local target = ok and sidebar.target_win(tab)
    if not target then
      return refuse("no file window in this tab to stack")
    end
    win = target
  end

  local reason = why_not(win, true)
  if reason then return refuse(reason) end
  local siblings = column(tab, win)
  if not siblings then
    return refuse("this window isn't in a column — split it first with <Leader>-")
  end

  local claimed = {}
  for _, node in ipairs(siblings) do
    if node[1] == "leaf" and eligible(node[2], true) then
      vim.w[node[2]].core_stack = true
      table.insert(claimed, node[2])
    end
  end
  if #claimed < 2 then
    for _, w in ipairs(claimed) do strip(w) end
    return refuse("need two windows in the column to stack — split with <Leader>-")
  end

  allow_collapse()
  M.apply(tab)
end

--- Undo the stack, leaving ordinary splits behind.
function M.unstack(tab)
  tab = here(tab)
  local wins = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.w[w].core_stack ~= nil then table.insert(wins, w) end
  end
  if #wins == 0 then return M.chrome(tab) end

  applying = true
  pcall(noauto, function()
    -- strip() unparks on the way past, so every terminal is back in its own
    -- window before the equalise below decides how tall each one should be.
    for _, w in ipairs(wins) do strip(w) end
    -- Equalise from inside the column. The sidebar holds 'winfixwidth', so
    -- its width survives this; nothing else in the tab has a claim worth
    -- protecting.
    vim.api.nvim_win_call(wins[1], function() vim.cmd("wincmd =") end)
  end)
  applying = false
  M.chrome(tab)
end

function M.toggle()
  if #M.members(0) >= 2 then
    M.unstack(0)
  else
    M.create()
  end
end

--- Bring the current window into this tab's stack. If it's already in the
--- stack's column that's just a tag; if it's somewhere else the window has
--- to move, which means carrying the buffer and the view across the way
--- core.tabs does it between tabpages.
function M.add()
  if not config.stack.enabled then
    return refuse("stacking is off — set stack.enabled in lua/settings.lua")
  end
  local tab = vim.api.nvim_get_current_tabpage()
  local win = vim.api.nvim_get_current_win()
  local members = M.members(tab)

  if #members < 2 then return M.create() end
  if vim.w[win].core_stack == true then return refuse("already in the stack") end
  local reason = why_not(win, true)
  if reason then return refuse(reason) end

  local siblings = column(tab, win)
  local shares = false
  if siblings then
    for _, node in ipairs(siblings) do
      if node[1] == "leaf" and node[2] == members[1] then shares = true end
    end
  end

  if shares then
    vim.w[win].core_stack = true
    return M.apply(tab)
  end

  -- A different column. Land the buffer in the stack before closing the
  -- window it came from, so a failure anywhere here still leaves the file
  -- on screen somewhere.
  local buf = vim.api.nvim_win_get_buf(win)
  local view = vim.fn.winsaveview()
  local anchor = active_of(tab, members)

  vim.api.nvim_set_current_win(anchor)
  vim.cmd("split")
  local new = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(new, buf)
  vim.w[new].core_stack = true
  vim.fn.winrestview(view)

  if vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, false)
  end
  M.apply(tab)
end

--- Take one window back out, giving it a real share of the column.
function M.remove(win)
  win = win or vim.api.nvim_get_current_win()
  if vim.w[win].core_stack ~= true then return refuse("not a stack member") end
  local tab = vim.api.nvim_win_get_tabpage(win)

  local rows = column_rows(tab, win)
  release(win)
  -- Hand it a real share BEFORE the remaining members re-divide the column.
  -- Skip this and it keeps whatever it had — 0 rows if it was collapsed, or
  -- the whole column if it was the expanded one — and in both cases the
  -- result reads as though the release didn't take.
  -- When this was the second-to-last member the stack ends outright, and
  -- members() has already equalised the column on its way out — there is no
  -- share left to handle here.
  local members = M.members(tab)
  if rows and #members >= 1 then
    local share = math.max(math.floor(rows / (#members + 1)) - 1, 1)
    pcall(vim.api.nvim_win_set_height, win, share)
  end
  M.apply(tab)
end

--- Move focus along the stack. Sets the current window and lets WinEnter do
--- the geometry — never the other way round, because "the active member is
--- the current window" is the invariant apply() depends on.
function M.cycle(delta)
  local tab = vim.api.nvim_get_current_tabpage()
  local members = M.members(tab)
  if #members < 2 then return refuse("no stack in this tab") end

  local cur, idx = active_of(tab, members), nil
  for i, w in ipairs(members) do
    if w == cur then idx = i end
  end
  if not idx then return end

  local n = #members
  local target = idx + delta
  if config.stack.wrap then
    target = ((target - 1) % n) + 1
  else
    target = math.min(math.max(target, 1), n)
  end
  vim.api.nvim_set_current_win(members[target])
end

-- ── Reload protocol ───────────────────────────────────────────────────

--- Pick up stacks left by a previous incarnation. w:core_stack survives a
--- :Reload the way t:tabname does, so the tags are still there — only the
--- module state that reads them was thrown away.
function M.adopt()
  if not config.stack.enabled then return end
  local function scan()
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if vim.w[w].core_stack == true then
          allow_collapse()
          M.schedule(tab)
          break
        end
      end
    end
  end
  if vim.v.vim_did_enter == 0 then
    vim.api.nvim_create_autocmd("VimEnter", { group = group, once = true, callback = scan })
  else
    scan()
  end
end

--- Called by :Reload before this module is discarded. The collapsed geometry
--- and the window-local statuslines are only reachable through this
--- incarnation, so they have to go now — but the TAGS stay, so M.adopt()
--- next time round rebuilds the same stacks instead of leaving you with a
--- column of windows nothing knows it owns.
function M.unload()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local wins = {}
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.w[w].core_stack == true then table.insert(wins, w) end
    end
    for _, w in ipairs(wins) do
      -- Not strip(): the tags stay, so M.adopt() rebuilds the stack. But the
      -- terminals have to come back now — the next incarnation has no idea
      -- which window parked which buffer.
      unpark(w)
      vim.wo[w].winfixheight = false
      vim.wo[w].statusline = ""
    end
    if #wins > 0 then
      pcall(vim.api.nvim_win_call, wins[1], function() vim.cmd("wincmd =") end)
    end
  end
  vim.o.laststatus = baseline_laststatus
  vim.o.winminheight = baseline_winminheight
end

-- ── Wiring ────────────────────────────────────────────────────────────

-- WinEnter is the one that matters: it's what makes <C-j>/<C-k> the stack
-- navigation, and what keeps the active member and the current window the
-- same thing. The rest re-assert geometry after something moved it.
vim.api.nvim_create_autocmd({ "WinEnter", "WinNew", "WinClosed", "WinResized" }, {
  group = group,
  callback = function()
    -- WinNew is scheduled anyway, which also gives 'buftype' time to settle
    -- before eligible() judges a terminal split. During WinClosed the window
    -- is still open, the same reason core.sidebar defers.
    M.schedule(0)
  end,
})

-- ╭─ THE NET, FOR THE EVENTS THAT DON'T EXIST ─────────────────────────╮
-- │ <C-w>H, <C-w>J, <C-w>K, <C-w>L and <C-w>r fire NOTHING. Not         │
-- │ WinNew, not WinClosed, not WinEnter, not even WinResized —          │
-- │ measured, all five are silent. Only <C-w>x fires anything, and      │
-- │ only because it happens to move the cursor.                         │
-- │                                                                     │
-- │ That matters because <C-w>H restructures the layout out from under  │
-- │ a stack: the members stop being one column, and with no event to    │
-- │ notice, the collapsed ones are left at zero rows — invisible        │
-- │ windows you cannot get back to. So this compares a cheap            │
-- │ fingerprint of the current tab's window geometry on SafeState and   │
-- │ reconciles when it moved. No winlayout() walk, no work at all for   │
-- │ a tab with no stack in it, and it converges: apply() is idempotent, │
-- │ so once the geometry settles the fingerprint stops changing.        │
-- ╰─────────────────────────────────────────────────────────────────────╯
local fingerprint = {}

vim.api.nvim_create_autocmd("SafeState", {
  group = group,
  callback = function()
    if applying then return end
    local tab = vim.api.nvim_get_current_tabpage()
    local parts, stacked = {}, false
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.w[w].core_stack ~= nil then stacked = true end
      parts[#parts + 1] = w .. ":" .. vim.api.nvim_win_get_height(w)
    end
    if not stacked then
      fingerprint[tab] = nil
      return
    end
    local fp = table.concat(parts, ",")
    if fp == fingerprint[tab] then return end
    fingerprint[tab] = fp
    M.schedule(tab)
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      M.schedule(tab)
    end
  end,
})

-- Chrome FIRST, then geometry, and unconditionally. Entering a stacked tab
-- while 'laststatus' is still 3 and 'winminheight' still 1 re-expands the
-- members on the spot, and putting the options back does NOT undo that —
-- measured. So the options go first and the re-apply always runs.
vim.api.nvim_create_autocmd("TabEnter", {
  group = group,
  callback = function()
    local tab = vim.api.nvim_get_current_tabpage()
    M.chrome(tab)
    M.schedule(tab)
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  group = group,
  callback = function()
    -- Every table keyed by tabpage, not just last_active: a tab can pick up
    -- a fingerprint or a retry count without ever having had an expanded
    -- member, and those entries would then never be collected.
    for _, t in ipairs({ last_active, retries, fingerprint, pending }) do
      for tab in pairs(t) do
        if not vim.api.nvim_tabpage_is_valid(tab) then t[tab] = nil end
      end
    end
  end,
})

-- ── Commands ──────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("Stack", function(o)
  if o.bang then M.unstack(0) else M.create() end
end, { bang = true, desc = "stack: stack this column (! unstacks)" })

vim.api.nvim_create_user_command("StackToggle", function()
  M.toggle()
end, { desc = "stack: toggle stacking for this column" })

vim.api.nvim_create_user_command("StackAdd", function()
  M.add()
end, { desc = "stack: bring this window into the stack" })

vim.api.nvim_create_user_command("StackRemove", function()
  M.remove()
end, { desc = "stack: take this window out of the stack" })

vim.api.nvim_create_user_command("StackNext", function(o)
  M.cycle(math.max(o.count, 1))
end, { count = 1, desc = "stack: next member" })

vim.api.nvim_create_user_command("StackPrev", function(o)
  M.cycle(-math.max(o.count, 1))
end, { count = 1, desc = "stack: previous member" })

M.adopt()

return M
