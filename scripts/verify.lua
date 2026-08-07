-- Check that the tools your enabled languages need are on PATH.
--
--   nvim -l scripts/verify.lua       (or: make verify)
--
-- Reads settings.languages and the registry in lua/core/languages.lua, so
-- there is exactly one list of tools in this repo and this script can't
-- drift from it. Deleting a language from settings.lua removes its tools
-- from this output too.
--
-- Exit code is 1 if a REQUIRED tool is missing, 0 otherwise. Optional
-- tools are reported but never fail the run.

-- nvim -l runs before the config, so make this repo importable.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local ok, config = pcall(require, "core.config")
if not ok then
  io.stderr:write("could not load config: " .. tostring(config) .. "\n")
  os.exit(2)
end

-- ── output helpers ────────────────────────────────────────────────────
local color = os.getenv("NO_COLOR") == nil
local function paint(code, s)
  if not color then return s end
  return ("\27[%sm%s\27[0m"):format(code, s)
end
local pass = function(s) return paint("32", s) end
local fail = function(s) return paint("31", s) end
local warn = function(s) return paint("33", s) end
local dim = function(s) return paint("90", s) end
local bold = function(s) return paint("1", s) end

local out = function(s) io.write((s or "") .. "\n") end

local missing, present, degraded = 0, 0, 0

local function have(bin)
  return vim.fn.executable(bin) == 1
end

local function report(tool, required)
  -- Swift is special: sourcekit-lsp lives inside the Xcode toolchain and
  -- isn't on PATH directly.
  local found = have(tool.bin)
  if tool.bin == "xcrun" and found then
    found = vim.fn.system({ "xcrun", "--find", "sourcekit-lsp" }) ~= ""
      and vim.v.shell_error == 0
  end

  if found then
    out(("  %s %-32s %s"):format(pass("✓"), tool.bin, dim(tool.purpose)))
    present = present + 1
    return
  end

  if required then
    out(("  %s %-32s %s"):format(fail("✗"), tool.bin, tool.purpose))
    missing = missing + 1
  else
    out(("  %s %-32s %s"):format(warn("○"), tool.bin, tool.purpose))
    degraded = degraded + 1
  end
  out(("      %s"):format(warn(tool.hint)))
end

-- ── Neovim itself ─────────────────────────────────────────────────────
out()
out(bold("Neovim"))
local v = vim.version()
local version_str = ("%d.%d.%d"):format(v.major, v.minor, v.patch)
if vim.fn.has("nvim-0.12") == 1 then
  out(("  %s %-32s %s"):format(pass("✓"), "nvim", dim(version_str)))
  present = present + 1
else
  out(("  %s %-32s %s"):format(fail("✗"), "nvim", version_str .. " — this config needs 0.12+"))
  out(("      %s"):format(warn("brew install neovim  |  https://github.com/neovim/neovim/releases")))
  missing = missing + 1
end

-- ── Always needed ─────────────────────────────────────────────────────
out()
out(bold("Core tools"))
report({ bin = "git", purpose = "vim.pack clones plugins over git", hint = "xcode-select --install  |  apt install git" }, true)
report({ bin = "rg", purpose = "fzf-lua live_grep, :grep", hint = "brew install ripgrep" }, true)
report({ bin = "fd", purpose = "fzf-lua file finding", hint = "brew install fd" }, false)

-- ── Per-language, from the registry ───────────────────────────────────
local required, optional = config.tools()

-- Group by language so the output maps onto settings.lua.
local by_lang = {}
local order = {}
local function bucket(tool, is_required)
  if not by_lang[tool.lang] then
    by_lang[tool.lang] = {}
    table.insert(order, tool.lang)
  end
  table.insert(by_lang[tool.lang], { tool = tool, required = is_required })
end
for _, t in ipairs(required) do bucket(t, true) end
for _, t in ipairs(optional) do bucket(t, false) end
table.sort(order)

for _, lang in ipairs(order) do
  out()
  out(bold(lang))
  for _, entry in ipairs(by_lang[lang]) do
    report(entry.tool, entry.required)
  end
end

-- ── Shell integration ─────────────────────────────────────────────────
out()
out(bold("Shell"))
local interactive = config.shell.interactive or "fish"
if have(interactive) then
  out(("  %s %-32s %s"):format(pass("✓"), interactive, dim("interactive terminal splits")))
  present = present + 1
else
  out(("  %s %-32s %s"):format(warn("○"), interactive, "interactive terminal splits"))
  out(("      %s"):format(dim("optional — falls back to $SHELL, then a POSIX shell")))
  degraded = degraded + 1
end

-- ── Summary ───────────────────────────────────────────────────────────
out()
out(("%d present, %d missing, %d optional not installed"):format(present, missing, degraded))
if missing == 0 and degraded == 0 then
  out(pass("Everything your enabled languages need is here."))
elseif missing == 0 then
  out(pass("All required tools present.") .. " " ..
    dim("Optional ones only reduce features for that language."))
else
  out(fail(("%d required tool(s) missing."):format(missing)))
  out(dim("Not fatal — the servers you do have will still attach. Languages you"))
  out(dim("don't use can be removed from `languages` in lua/settings.lua."))
end
out()

os.exit(missing > 0 and 1 or 0)
