-- ════════════════════════════════════════════════════════════════════
--  THIS IS THE FILE YOU EDIT.
--
--  Everything below has a working default. Change what you want, ignore
--  the rest. Nothing else in this repo needs touching to make it yours.
--
--  For machine-specific tweaks you don't want committed, create
--  lua/settings_local.lua returning a partial table — it's gitignored
--  and merged over the top of this one.
-- ════════════════════════════════════════════════════════════════════

return {
  -- ── Languages ───────────────────────────────────────────────────────
  -- This list is the master switch. It decides which language servers
  -- start, which treesitter parsers install, which formatters register,
  -- and what `make verify` checks for. Delete a line and that language's
  -- entire toolchain requirement disappears.
  --
  -- Available: go, typescript, ruby, terraform, terragrunt, bash,
  --            python, swift, kotlin, toml, yaml, json, lua, markdown
  -- See lua/core/languages.lua to add your own.
  languages = {
    "go",
    "typescript", -- also covers JavaScript, Node, JSX/TSX
    "ruby",
    "terraform",  -- OpenTofu and Terraform
    "terragrunt", -- Terragrunt HCL
    "bash",
    "python",
    "swift",
    "kotlin",
    "toml",
    "yaml",
    "json",
    "lua",        -- keep this if you plan to edit this config
    "markdown",
  },

  -- ── Leader ──────────────────────────────────────────────────────────
  -- ',' is a single unmodified key on every layout. '<Space>' is the
  -- popular choice but costs you space-as-right-motion in normal mode.
  -- '\' is the vim default but a three-key chord on many ISO layouts.
  leader = ",",
  localleader = ",",

  -- ── Clipboard ───────────────────────────────────────────────────────
  --   "explicit"  y/p stay register-local; prefix+y / prefix+p use the
  --               system clipboard. Keeps the two deliberately separate.
  --   "system"    plain y and p go straight to the system clipboard
  --               (sets clipboard=unnamedplus). Simpler, less control.
  clipboard = "explicit",
  clipboard_prefix = "\\", -- only used when clipboard = "explicit"

  -- ── Theme ───────────────────────────────────────────────────────────
  theme = {
    plugin = "https://github.com/sainnhe/gruvbox-material",
    colorscheme = "gruvbox-material",

    -- Follow the OS light/dark setting automatically. Requires a terminal
    -- that reports its background via OSC 11 (Ghostty, WezTerm, kitty,
    -- Alacritty). Neovim flips 'background' on its own; we just reload
    -- the colorscheme. No polling, no plugin.
    follow_system = true,

    -- Set these only if your colorscheme needs a different name per
    -- background. Most modern ones read 'background' themselves, so nil
    -- is usually right.
    light = nil, -- e.g. "catppuccin-latte"
    dark = nil,  -- e.g. "catppuccin-mocha"

    transparent = false,

    -- Passed through as vim.g.<key> before the colorscheme loads. These
    -- defaults are gruvbox-material's; change them if you swap themes.
    options = {
      gruvbox_material_background = "hard",
      gruvbox_material_foreground = "material",
      gruvbox_material_better_performance = 1,
      gruvbox_material_enable_italic = 1,
      gruvbox_material_diagnostic_virtual_text = "colored",
    },
  },

  -- ── Indentation ─────────────────────────────────────────────────────
  -- The global default. Per-language overrides live in after/ftplugin/
  -- (Go wants real tabs, Python wants 4) — that's the native mechanism
  -- and it's why there's no vim-sleuth here.
  indent = {
    width = 2,
    expandtab = true,
  },

  -- ── Terminal ────────────────────────────────────────────────────────
  terminal = {
    -- How to leave terminal mode. Use a CONTROL CHORD, never a printable
    -- key: a printable escape gets eaten by things you legitimately type
    -- into a shell (`\e` breaks `printf '\e[31m'`, `,e` breaks `{a,e}`).
    -- Both spellings are listed because terminals disagree — the kitty
    -- keyboard protocol sends a real <C-Space>, older ones send NUL,
    -- which Neovim reports as <C-@>.
    escape = { "<C-Space>", "<C-@>" },

    -- CLI coding agent toggled with <Leader>cc. Set to nil to skip.
    -- e.g. "claude", "aider", "codex", "gemini"
    agent = "claude",

    height = 0.4, -- fraction of the window for bottom splits
  },

  -- ── Shell ───────────────────────────────────────────────────────────
  shell = {
    -- What :terminal and the terminal toggles (,cs ,cc ,cV) open.
    -- nil = autodetect: fish, else $SHELL, else bash.
    interactive = nil,

    -- What :!, system(), :grep and plugin shell-outs use.
    --
    --   "interactive"  the same shell as above (default). Least
    --                  surprising — everything matches your $SHELL.
    --   "posix"        force bash/sh. Use this if fzf-lua returns
    --                  nothing or a formatter silently stops: plugins
    --                  emit POSIX constructs like `VAR=x cmd` and
    --                  nested `$(...)` that fish and nushell reject.
    --   "/bin/zsh"     an explicit path.
    --
    -- The terminal toggles exec the interactive shell directly, so they
    -- give you fish either way. :ShellInfo shows what's in effect.
    internal = "interactive",
  },

  -- ── Tabs ────────────────────────────────────────────────────────────
  -- Where the tab list lives, and how much it tells you about each entry.
  tabs = {
    --   "tabline"  the usual strip across the top, one entry per tabpage
    --   "sidebar"  a fixed-width window down the left, with each tab's
    --              buffers listed underneath it and foldable
    --   "none"     neither
    --
    -- Toggle between the first two at any time with <Leader>B, or pick
    -- one with :Tabs tabline. Both are clickable with the mouse.
    display = "sidebar",

    width = 32, -- sidebar only

    -- The per-entry summary. All of it comes from state Neovim already
    -- has — no shelling out — so none of it can go stale.
    show_path = true,        -- the directory, so same-named files differ
    show_git = true,         -- +added ~changed -removed, from gitsigns
    show_diagnostics = true, -- ✖errors ⚠warnings, from the LSP
  },

  -- ── Behaviour ───────────────────────────────────────────────────────
  format_on_save = true,
  spell = { "en_us" }, -- add your own, e.g. { "en_us", "sv", "de" }

  -- ── Extra plugins ───────────────────────────────────────────────────
  -- Added to vim.pack alongside the built-in nine. Configure them in
  -- lua/settings_local.lua or a file of your own required from init.lua.
  extra_plugins = {
    -- "https://github.com/tpope/vim-fugitive",
  },
}
