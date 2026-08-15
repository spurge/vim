-- Resolved configuration.
--
--   require("core.config")
--
-- Merge order, last wins:
--   1. the defaults below
--   2. lua/settings.lua         (committed — the file you edit)
--   3. lua/settings_local.lua   (gitignored — machine-specific overrides)
--
-- A missing or broken settings file is non-fatal: you get defaults plus a
-- warning, so a typo can never leave you without a working editor.

local defaults = {
  -- Conservative default set, so a fresh clone works with almost no
  -- tooling installed. lua/settings.lua overrides this.
  languages = { "lua", "markdown", "bash", "json", "yaml", "toml" },
  leader = ",",
  localleader = ",",
  theme = {
    -- An ordered list; :ThemesToggle cycles it. One entry is a perfectly
    -- good list.
    themes = {
      {
        plugin = "https://github.com/sainnhe/gruvbox-material",
        colorscheme = "gruvbox-material",
        options = {},
      },
    },
    follow_system = true,
    transparent = false,
    remember = true,
  },
  indent = { width = 2, expandtab = true },
  terminal = {
    escape = { "<C-Space>", "<C-@>" },
    agent = nil,
    height = 0.4,
  },
  shell = { interactive = nil, internal = "interactive" },
  tabs = {
    display = "tabline",
    width = 32,
    show_path = true,
    show_git = true,
    show_diagnostics = true,
  },
  claude = {
    enabled = true,
    statusline = true,
    notify = true,
    interval = 30,
    stale_after = 1800,
  },
  format_on_save = true,
  spell = { "en_us" },
  extra_plugins = {},
}

-- ── Merge ─────────────────────────────────────────────────────────────
-- NOT vim.tbl_deep_extend. That merges list-like tables index-by-index,
-- so overriding a 14-entry `languages` list with a 2-entry one would
-- leave 12 unwanted entries behind — silently. Lists must replace
-- wholesale; only maps merge.

local function is_list(t)
  return type(t) == "table" and (#t > 0 or next(t) == nil)
end

local function merge(base, override)
  local out = {}
  for k, v in pairs(base) do
    out[k] = v
  end
  for k, v in pairs(override) do
    if type(v) == "table" and type(out[k]) == "table"
      and not is_list(v) and not is_list(out[k]) then
      out[k] = merge(out[k], v)
    else
      out[k] = v
    end
  end
  return out
end

-- ── Load ──────────────────────────────────────────────────────────────
-- Note the module name: `settings_local`, not `settings.local`. Lua turns
-- dots in module names into path separators, so require("settings.local")
-- would look for lua/settings/local.lua and never find the file.

local function load(name, optional)
  local ok, mod = pcall(require, name)
  if not ok then
    local err = tostring(mod)
    local absent = err:find("not found", 1, true) ~= nil
    if not (optional and absent) then
      vim.schedule(function()
        vim.notify(("%s.lua failed to load — using defaults.\n%s"):format(name, err),
          vim.log.levels.WARN)
      end)
    end
    return {}
  end
  if type(mod) ~= "table" then
    vim.schedule(function()
      vim.notify(("%s.lua must return a table, got %s"):format(name, type(mod)),
        vim.log.levels.WARN)
    end)
    return {}
  end
  return mod
end

local config = merge(merge(defaults, load("settings")), load("settings_local", true))

-- ── Derived views over the language registry ──────────────────────────
-- Computed once, so lsp.lua, plugins.lua, format.lua and scripts/verify.lua
-- all read the same thing and cannot drift apart.

local registry = require("core.languages")

config.enabled = {}
local unknown = {}
for _, name in ipairs(config.languages) do
  if registry[name] then
    config.enabled[name] = registry[name]
  else
    table.insert(unknown, name)
  end
end

if #unknown > 0 then
  vim.schedule(function()
    local known = {}
    for k in pairs(registry) do table.insert(known, k) end
    table.sort(known)
    vim.notify(
      ("unknown language(s) in settings.lua: %s\navailable: %s")
        :format(table.concat(unknown, ", "), table.concat(known, ", ")),
      vim.log.levels.WARN
    )
  end)
end

--- LSP server names for the enabled languages.
function config.servers()
  local out, seen = {}, {}
  for _, lang in pairs(config.enabled) do
    for _, s in ipairs(lang.servers or {}) do
      if not seen[s] then
        seen[s] = true
        table.insert(out, s)
      end
    end
  end
  table.sort(out)
  return out
end

--- Treesitter parsers, plus a baseline that's useful regardless.
function config.parsers()
  local out, seen = {}, {}
  for _, p in ipairs({
    "c", "diff", "git_config", "git_rebase", "gitcommit", "gitignore",
    "query", "regex", "vim", "vimdoc",
  }) do
    seen[p] = true
    table.insert(out, p)
  end
  for _, lang in pairs(config.enabled) do
    for _, p in ipairs(lang.parsers or {}) do
      if not seen[p] then
        seen[p] = true
        table.insert(out, p)
      end
    end
  end
  table.sort(out)
  return out
end

--- conform's formatters_by_ft table.
function config.formatters()
  local out = {}
  for _, lang in pairs(config.enabled) do
    for ft, list in pairs(lang.formatters or {}) do
      out[ft] = list
    end
  end
  out["_"] = { "trim_whitespace", "trim_newlines" }
  return out
end

--- Required and optional tools, for scripts/verify.lua.
function config.tools()
  local required, optional = {}, {}
  for name, lang in pairs(config.enabled) do
    for _, t in ipairs(lang.tools or {}) do
      table.insert(required, { bin = t[1], purpose = t[2], hint = t[3], lang = name })
    end
    for _, t in ipairs(lang.optional or {}) do
      table.insert(optional, { bin = t[1], purpose = t[2], hint = t[3], lang = name })
    end
  end
  local by_bin = function(a, b) return a.bin < b.bin end
  table.sort(required, by_bin)
  table.sort(optional, by_bin)
  return required, optional
end

return config
