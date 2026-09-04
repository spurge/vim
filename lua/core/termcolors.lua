-- Terminal colours: what a TUI running inside a :terminal buffer can see.
--
-- ── The bug this exists to fix ────────────────────────────────────────
-- Dark text on a dark background, in every colorscheme, but only once the
-- OS flips to dark in the evening. Three separate things stack up:
--
--   1. Neovim REMOVES $COLORTERM from every terminal job's environment.
--      Setting it in vim.env doesn't help — it's stripped from the child
--      env after that. So a TUI that checks COLORTERM to decide whether
--      it may use 24-bit colour concludes it may not, and falls back to
--      the 16 ANSI colours. Claude Code, delta, bat, gh and most modern
--      TUIs all do this. Outside Neovim they'd be full-colour.
--
--   2. Those 16 ANSI colours come from `g:terminal_color_0` … `_15`, and
--      a colorscheme is under no obligation to set them. gruvbox-material
--      sets NONE, so terminal buffers get libvterm's built-in palette:
--      colour 0 is #000000 and colour 4 is #0000e0. On gruvbox hard dark
--      (#1d2021) that's a contrast ratio of 1.3:1 and 1.1:1 — invisible.
--      everforest and monokai-nightasty do set a palette, and still put
--      colour 0/8 within 1.5:1 of their own dark background.
--
--      On a LIGHT background the very same palette is perfectly readable,
--      which is why the problem only shows up after dark.
--
--   3. Neovim answers a child's OSC 11 background query with a hardcoded
--      rgb:0000/0000/0000 whatever 'background' actually is, and strips
--      $COLORFGBG too — so a TUI set to "auto" cannot tell light from
--      dark in here either.
--
-- ── What this module does about it ────────────────────────────────────
--   1. hands $COLORTERM back to terminals opened through core.shell, but
--      only while 'termguicolors' is on, so it's never a lie
--   2. derives the 16 ANSI colours from the active colorscheme's own
--      highlight groups, then lifts any entry that fails a contrast floor
--      against Normal's background — so no palette entry can ever be
--      invisible, whichever theme and whichever background
--   3. sets $COLORFGBG so "auto" TUIs get the right answer
--
-- ── The one thing it can't fix ────────────────────────────────────────
-- `:help terminal-config`: the palette variables "are read during
-- TermOpen". A terminal that was already running when the OS flipped
-- keeps the palette it was born with. New ones are correct; a long-lived
-- one has to be restarted. :TermColors says which is which.

local config = require("core.config")

local M = {}

local settings = (config.terminal or {}).colors or {}
local enabled = settings.enabled ~= false
local floor = tonumber(settings.min_contrast) or 3.0

-- ── Colour arithmetic ─────────────────────────────────────────────────
-- WCAG relative luminance and contrast ratio. Perceptual rather than
-- naive, because "is this readable" is a perceptual question: #0000ee and
-- #767676 have nearly the same naive brightness and wildly different
-- legibility.

local function to_rgb(n)
  return { math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256 }
end

local function to_hex(c)
  return ("#%02x%02x%02x"):format(
    math.max(0, math.min(255, math.floor(c[1] + 0.5))),
    math.max(0, math.min(255, math.floor(c[2] + 0.5))),
    math.max(0, math.min(255, math.floor(c[3] + 0.5))))
end

local function parse(s)
  local r, g, b = tostring(s):match("^#(%x%x)(%x%x)(%x%x)$")
  if not r then return nil end
  return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
end

local function linear(v)
  v = v / 255
  return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
end

local function luminance(c)
  return 0.2126 * linear(c[1]) + 0.7152 * linear(c[2]) + 0.0722 * linear(c[3])
end

local function contrast(a, b)
  local hi, lo = luminance(a), luminance(b)
  if hi < lo then hi, lo = lo, hi end
  return (hi + 0.05) / (lo + 0.05)
end

local function mix(a, b, t)
  return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

--- Move `c` towards `target` until it clears `floor` against `bg`.
--- Returns `c` untouched when it already does, so a theme that got its
--- palette right keeps it exactly.
local function lift(c, bg, target)
  if contrast(c, bg) >= floor then return c end
  for step = 1, 20 do
    local out = mix(c, target, step / 20)
    if contrast(out, bg) >= floor then return out end
  end
  return target
end

-- ── Deriving a palette from the colorscheme ───────────────────────────
-- Only used for entries the colorscheme left unset — gruvbox-material
-- sets none at all, so this is its whole palette.
--
-- The trap here is that ANSI slots are HUES, not syntax roles. Taking
-- `Function` for slot 4 ("blue") gives you green under gruvbox-material,
-- where functions are green — and then `ls` paints directories the same
-- colour as executables, which is worse than the problem being fixed. So
-- every candidate is checked against the canonical hue for its slot and
-- rejected if it isn't recognisably that colour. The theme gets to tint
-- the palette; it doesn't get to redefine what blue means.
--
-- Slots 0 and 7 are the achromatic pair and skip the check: 0 is dimmed
-- text (what TUIs actually use 0 and 8 for — nothing wants literal black
-- letters) and 7 is ordinary foreground.

local roles = {
  [0] = { hue = nil, groups = { "Comment", "NonText", "LineNr" },
          base = { 128, 128, 128 } },
  [1] = { hue = 0,   groups = { "DiagnosticError", "ErrorMsg", "Removed", "diffRemoved" },
          base = { 205, 0, 0 } },
  [2] = { hue = 120, groups = { "DiagnosticOk", "Added", "diffAdded", "String" },
          base = { 0, 205, 0 } },
  [3] = { hue = 60,  groups = { "DiagnosticWarn", "WarningMsg", "Changed", "diffChanged" },
          base = { 205, 205, 0 } },
  [4] = { hue = 240, groups = { "DiagnosticInfo", "Directory", "Function", "Identifier" },
          base = { 60, 100, 230 } },
  [5] = { hue = 300, groups = { "Keyword", "Statement", "PreProc", "Include" },
          base = { 205, 0, 205 } },
  [6] = { hue = 180, groups = { "DiagnosticHint", "Type", "Special", "Constant" },
          base = { 0, 205, 205 } },
  [7] = { hue = nil, groups = { "Normal" }, base = { 229, 229, 229 } },
}

--- Hue in degrees, and saturation 0-1. Grey has no meaningful hue, hence
--- the saturation floor at the call site.
local function hsv(c)
  local r, g, b = c[1] / 255, c[2] / 255, c[3] / 255
  local hi, lo = math.max(r, g, b), math.min(r, g, b)
  local d = hi - lo
  if d < 1e-6 then return 0, 0 end
  local h
  if hi == r then h = (g - b) / d % 6
  elseif hi == g then h = (b - r) / d + 2
  else h = (r - g) / d + 4 end
  return h * 60, d / hi
end

local function hue_distance(a, b)
  local d = math.abs(a - b) % 360
  return d > 180 and 360 - d or d
end

--- The theme's own colour for this slot, if it has one that is actually
--- the right hue and isn't already in use by another slot. nil means
--- "use the canonical colour instead".
---
--- `taken` is the hues assigned so far. Without it everforest's Keyword,
--- a red at 359 degrees, passes as magenta and slot 5 comes out identical
--- to slot 1 — and a palette with two reds and no magenta is a different
--- kind of unreadable from the one this module exists to fix.
local function from_theme(role, taken)
  for _, name in ipairs(role.groups) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok and type(hl) == "table" and hl.fg then
      local c = to_rgb(hl.fg)
      if not role.hue then return c end
      local h, sat = hsv(c)
      -- 60 degrees is a sixth of the wheel: wide enough for a theme's
      -- muted, off-primary take on a hue — gruvbox's green sits 50
      -- degrees off true green — and still narrow enough that green can
      -- never pass as blue.
      if sat >= 0.15 and hue_distance(h, role.hue) <= 60 then
        local clash = false
        for _, used in ipairs(taken) do
          if hue_distance(h, used) < 25 then clash = true end
        end
        if not clash then
          table.insert(taken, h)
          return c
        end
      end
    end
  end
end

--- Build and install g:terminal_color_0 … _15.
function M.apply()
  if not enabled then return end

  local ok, normal = pcall(vim.api.nvim_get_hl, 0, { name = "Normal", link = false })
  normal = ok and normal or {}
  local dark = vim.o.background == "dark"
  local bg = normal.bg and to_rgb(normal.bg) or (dark and { 0, 0, 0 } or { 255, 255, 255 })
  local fg = normal.fg and to_rgb(normal.fg) or (dark and { 255, 255, 255 } or { 0, 0, 0 })

  -- Lifting moves a failing colour towards the foreground, not towards
  -- white: on a light background "brighter" is the wrong direction.
  local target = fg

  -- Hues already spoken for, so no two slots end up the same colour.
  -- Seeded from whatever the colorscheme set itself, which is authority
  -- this module does not override.
  local taken = {}
  for i = 1, 6 do
    local set = parse(vim.g["terminal_color_" .. i])
    if set then
      local h, sat = hsv(set)
      if sat >= 0.15 then table.insert(taken, h) end
    end
  end

  -- 0-7 first, so 8-15 can be the bright version of the SAME choice
  -- rather than running the hue search a second time against a `taken`
  -- list that its own dim half has already filled.
  local base = {}
  for i = 0, 7 do
    base[i] = parse(vim.g["terminal_color_" .. i])
      or from_theme(roles[i], taken)
      or roles[i].base
  end

  for i = 0, 15 do
    local c = parse(vim.g["terminal_color_" .. i])
    if not c then
      c = base[i % 8]
      -- 8-15 are the "bright" half. Only synthesised entries get this;
      -- a theme that set them meant what it said.
      if i >= 8 then c = mix(c, target, 0.35) end
    end
    vim.g["terminal_color_" .. i] = to_hex(lift(c, bg, target))
  end
end

--- Environment for terminal jobs, filling in what Neovim strips out.
function M.env()
  local out = {}
  if not enabled then return out end

  -- Only when it's true. Claiming truecolor to a child while Neovim is
  -- rendering in 256 colours would make things worse, not better.
  if settings.truecolor ~= false and vim.o.termguicolors then
    out.COLORTERM = "truecolor"
  end

  -- rxvt's convention, still what "auto" TUIs read: fg;bg as palette
  -- indices. 15;0 is light-on-dark, 0;15 is dark-on-light.
  if settings.hint_background ~= false then
    out.COLORFGBG = vim.o.background == "dark" and "15;0" or "0;15"
  end

  return out
end

-- ── Wiring ────────────────────────────────────────────────────────────
-- ColorSchemePre clears the palette so one theme's colours can't survive
-- into the next: :ThemesToggle from everforest (which sets all 16) to
-- gruvbox-material (which sets none) would otherwise leave you looking at
-- everforest's terminal.

if enabled then
  local group = vim.api.nvim_create_augroup("core.termcolors", { clear = true })

  vim.api.nvim_create_autocmd("ColorSchemePre", {
    group = group,
    callback = function()
      for i = 0, 15 do vim.g["terminal_color_" .. i] = nil end
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = M.apply,
  })

  -- core.theme applies a colorscheme at require time, and this module is
  -- required first, so the autocmd above covers startup. This covers the
  -- case where it isn't — a stock colorscheme, or :Reload.
  M.apply()

  -- Terminals born before the flip keep their old palette. Say so once
  -- per flip rather than leaving it to be rediscovered at 22:00.
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "background",
    callback = function()
      local stale = 0
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buftype == "terminal"
          and vim.api.nvim_buf_is_loaded(buf)
          and (vim.b[buf].terminal_job_id or 0) > 0 then
          stale = stale + 1
        end
      end
      if stale > 0 then
        vim.schedule(function()
          vim.notify(("background is now %s — %d running terminal%s still use the old "
            .. "palette (it is fixed at TermOpen). Restart them, or see :TermColors.")
            :format(vim.o.background, stale, stale == 1 and "" or "s"))
        end)
      end
    end,
  })
end

vim.api.nvim_create_user_command("TermColors", function()
  if not enabled then
    vim.notify("terminal.colors.enabled is false in lua/settings.lua")
    return
  end

  local ok, normal = pcall(vim.api.nvim_get_hl, 0, { name = "Normal", link = false })
  normal = ok and normal or {}
  local bg = normal.bg and to_rgb(normal.bg)
    or (vim.o.background == "dark" and { 0, 0, 0 } or { 255, 255, 255 })

  local lines = {
    ("background=%s  Normal bg=%s  floor=%.1f:1")
      :format(vim.o.background, to_hex(bg), floor),
    "",
  }
  for i = 0, 15 do
    local c = parse(vim.g["terminal_color_" .. i])
    lines[#lines + 1] = ("  %-2d %s  %4.1f:1"):format(
      i, c and to_hex(c) or "unset  ", c and contrast(c, bg) or 0)
  end

  local env = M.env()
  lines[#lines + 1] = ""
  lines[#lines + 1] = ("  COLORTERM %s   COLORFGBG %s")
    :format(env.COLORTERM or "(not sent)", env.COLORFGBG or "(not sent)")

  local stale = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "terminal" and vim.api.nvim_buf_is_loaded(buf) then
      stale[#stale + 1] = "  " .. (vim.b[buf].term_title or vim.api.nvim_buf_get_name(buf))
    end
  end
  if #stale > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Terminals running now — these kept the palette they opened with:"
    vim.list_extend(lines, stale)
  end

  vim.notify(table.concat(lines, "\n"))
end, { desc = "Show the terminal ANSI palette, its contrast, and what is stale" })

return M
