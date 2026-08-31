-- Statusline, native. Replaces a statusline plugin with ~90 lines and no
-- dependencies.
--
-- Recomputed on every redraw, so everything here stays cheap: no shelling
-- out, no git calls (gitsigns already puts the branch in a buffer var).
-- core.claude follows the same rule: it polls on a timer and hands back a
-- string it prepared earlier.
--
-- ╭─ THE WINDOW BEING DRAWN IS NOT THE CURRENT WINDOW ─────────────────╮
-- │ Everything derived in Lua must be derived from the window this     │
-- │ statusline belongs to. Under 'laststatus' 3 there is exactly one   │
-- │ statusline and the two are always the same window, so `vim.b.x`    │
-- │ and `vim.diagnostic.get(0)` happen to be right. core.stack runs a  │
-- │ stacked tabpage at 'laststatus' 2, where every window draws its    │
-- │ own — and every one of them would report the FOCUSED buffer's      │
-- │ branch, diagnostics and LSP clients. g:statusline_winid is the     │
-- │ window being drawn; see :h 'statusline'.                           │
-- ╰────────────────────────────────────────────────────────────────────╯
--
-- The %-items need no such care: %f, %m, %{&filetype} and the rest are
-- already evaluated against the window being drawn, not the current one.

local claude = require("core.claude")

local modes = {
  n = "NORMAL", no = "OP-PEND", nov = "OP-PEND", noV = "OP-PEND",
  v = "VISUAL", V = "V-LINE", ["\22"] = "V-BLOCK",
  s = "SELECT", S = "S-LINE", ["\19"] = "S-BLOCK",
  i = "INSERT", ic = "INSERT", ix = "INSERT",
  R = "REPLACE", Rv = "V-REPL",
  c = "COMMAND", cv = "EX",
  r = "PROMPT", rm = "MORE", ["r?"] = "CONFIRM",
  ["!"] = "SHELL", t = "TERMINAL",
}

local severities = {
  { vim.diagnostic.severity.ERROR, "e" },
  { vim.diagnostic.severity.WARN, "w" },
  { vim.diagnostic.severity.INFO, "i" },
}

--- The window this statusline belongs to, and its buffer. Outside a redraw
--- the variable is unset — a direct call from :lua, say — and then the
--- current window is the honest answer.
local function drawing()
  local win = vim.g.statusline_winid
  if not win or not vim.api.nvim_win_is_valid(win) then
    win = vim.api.nvim_get_current_win()
  end
  return win, vim.api.nvim_win_get_buf(win)
end

local function diagnostics(buf)
  local out = {}
  for _, s in ipairs(severities) do
    local n = #vim.diagnostic.get(buf, { severity = s[1] })
    if n > 0 then
      table.insert(out, ("%s»%d"):format(s[2], n))
    end
  end
  return table.concat(out, " ")
end

local function clients(buf)
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    table.insert(names, c.name)
  end
  if #names == 0 then return "" end
  table.sort(names)
  return table.concat(names, ",")
end

local function flags(buf)
  local out = {}
  if vim.b[buf].core_passthrough then
    table.insert(out, "[passthrough]")
  end
  if vim.g.disable_autoformat or vim.b[buf].disable_autoformat then
    table.insert(out, "[fmt off]")
  end
  return table.concat(out, " ")
end

function _G.NvimStatusline()
  local win, buf = drawing()

  -- A window that isn't focused has no mode — reporting NORMAL in all of
  -- them, or INSERT in all of them, is worse than saying nothing.
  local mode = ""
  if win == vim.api.nvim_get_current_win() then
    mode = modes[vim.api.nvim_get_mode().mode] or "?"
  end

  local head = vim.b[buf].gitsigns_head
  local left = table.concat({
    " %#StatusLineNC#",
    mode,
    "%* %f%m%r %#Comment#",
    head and (" " .. head) or "",
    "%*",
  })

  -- Empty unless Claude Code has reported a rate limit recently, so this
  -- costs nothing to anyone who doesn't use it.
  local usage = claude.statusline()

  local right = table.concat({
    "%#DiagnosticError#", diagnostics(buf), "%*",
    " %#Comment#", flags(buf), " ", clients(buf), "%*",
    usage ~= "" and ("  " .. usage) or "",
    "  %{&filetype}",
    "  %{&fileformat}",
    "  %l:%c",
    "  %P ",
  })

  return left .. "%=" .. right
end

-- ── The stacked-window title row ──────────────────────────────────────
--
-- core.stack collapses every unfocused member of a stacked column to a
-- single row, and that row is the window's statusline. So the i3 title bar
-- is this function: core.stack points a window-local 'statusline' here and
-- clears it back to "" on the member that's expanded.
--
-- core.tabs is required lazily because init.lua loads it AFTER this module,
-- and it renders from the same model the tabline and the sidebar do — a
-- title bar that disagreed with the sidebar about what a window holds would
-- be worse than no title bar at all.

function _G.NvimStackTitle()
  local tabs = require("core.tabs")
  local opts = require("core.config").stack

  local win, buf = drawing()

  -- A collapsed terminal member doesn't hold its terminal — core.stack parks
  -- it out of the window so the window can reach zero rows without the PTY
  -- reflowing. The window remembers what it parked, and that is what the
  -- title row has to name; the scratch buffer standing in for it has no name
  -- at all.
  local parked = vim.w[win].core_stack_parked
  if parked and vim.api.nvim_buf_is_valid(parked) then
    buf = parked
  end

  local atoms = tabs.atoms(tabs.status(buf, opts), {
    modified = true,
    diag = opts.show_diagnostics,
    git = opts.show_git,
  })

  local right, used = {}, 0
  for _, a in ipairs(atoms) do
    table.insert(right, a[2] and ("%%#%s#%s%%*"):format(a[2], a[1]) or a[1])
    used = used + vim.fn.strdisplaywidth(a[1]) + 1
  end

  local name = tabs.label(buf)
  if vim.bo[buf].buftype == "terminal" then
    -- Worth one character: in a column that mixes shells with files, which
    -- rows are which is the first thing you want off a title bar.
    name = "$ " .. name
  elseif opts.show_path then
    local d = tabs.dir(buf)
    if d ~= "" then name = name .. "  " .. d end
  end

  -- Only the name is truncatable; the status atoms are short, fixed, and the
  -- reason you'd glance at a collapsed row in the first place.
  local budget = math.max(vim.api.nvim_win_get_width(win) - used - 5, 8)

  -- No base highlight group on purpose. Vim already paints an unfocused
  -- statusline with StatusLineNC and the focused one with StatusLine, so the
  -- collapsed rows come out dimmed and the expanded one bright — the i3
  -- title-bar look, for free, in groups every colorscheme defines. See the
  -- note in core/theme.lua about surviving the light/dark flip.
  return ("  %s%%= %s "):format(
    tabs.escape(tabs.truncate(name, budget)),
    table.concat(right, " ")
  )
end

vim.o.statusline = "%!v:lua.NvimStatusline()"

-- Redraw when diagnostics change, otherwise the counts lag behind.
vim.api.nvim_create_autocmd({ "DiagnosticChanged", "LspAttach", "LspDetach" }, {
  group = vim.api.nvim_create_augroup("core.statusline", { clear = true }),
  callback = function() vim.cmd.redrawstatus() end,
})

-- The tabline lives in lua/core/tabs.lua — it shares a model with the
-- stacked sidebar, which is a window rather than a format string.
-- The collapsed-window title row lives in lua/core/stack.lua's view of
-- that same model, and is installed as a window-local 'statusline'.
