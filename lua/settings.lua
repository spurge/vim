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
  -- Only used when clipboard = "explicit". Avoid '\' on an ISO layout —
  -- it's Option+Shift+7 on a Swedish Mac, and terminals that map Option
  -- to Meta swallow it entirely. A leader chord is always reachable.
  clipboard_prefix = "<Leader>c",

  -- ── Theme ───────────────────────────────────────────────────────────
  theme = {
    -- Cycled by :ThemesToggle (<Leader>tn), in this order. :Theme <name>
    -- jumps straight to one. Every entry gets installed, so keep the list
    -- to themes you actually want.
    --
    -- Per entry:
    --   colorscheme  the :colorscheme name
    --   options      vim.g.<key> set BEFORE loading — how the sainnhe
    --                themes are configured
    --   setup        passed to require(module).setup() before loading —
    --                how Lua-configured themes are configured
    --   module       only if it differs from `colorscheme`
    --   light/dark   only for themes that ship as two separate names
    themes = {
      {
        plugin = "https://github.com/sainnhe/gruvbox-material",
        colorscheme = "gruvbox-material",
        options = {
          gruvbox_material_background = "hard",
          gruvbox_material_foreground = "material",
          gruvbox_material_better_performance = 1,
          gruvbox_material_enable_italic = 1,
          gruvbox_material_diagnostic_virtual_text = "colored",
        },
      },
      {
        plugin = "https://github.com/polirritmico/monokai-nightasty.nvim",
        colorscheme = "monokai-nightasty",
        setup = {
          dark_style_background = "default", -- "dark" | "transparent" | #hex
          light_style_background = "default",
          markdown_header_marks = true,
          terminal_colors = true,
        },
      },
      {
        plugin = "https://github.com/sainnhe/everforest",
        colorscheme = "everforest",
        options = {
          everforest_background = 'medium',
          everforest_better_performance = 1,
        },
      },
    },

    -- Follow the OS light/dark setting automatically. Requires a terminal
    -- that reports its background via OSC 11 (Ghostty, WezTerm, kitty,
    -- Alacritty). Neovim flips 'background' on its own; we just reload
    -- the colorscheme. No polling, no plugin.
    follow_system = true,

    -- Remember the cycled choice across restarts, in stdpath("state").
    -- It's a per-machine preference, so it doesn't belong in this file.
    remember = true,

    -- Sets the sainnhe-style vim.g.<theme>_transparent_background. Themes
    -- configured through `setup` express transparency there instead.
    transparent = false,
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

  -- ── Claude Code ─────────────────────────────────────────────────────
  -- Rate limits in the statusline, and a desktop notification when Claude
  -- finishes or wants something. Nothing here needs an API key: both
  -- halves read what Claude Code already writes, under the auth of the
  -- session you're already logged into.
  --
  -- The statusline half works on its own. The notification half needs one
  -- entry in ~/.claude/settings.json, which lives outside this repo — run
  -- :ClaudeSetup once and it adds it (and shows you what it's adding).
  --
  -- Two windows, because that's what Anthropic reports: `5h` is the
  -- rolling session window with the time until it clears, `7d` is the
  -- weekly one. There is no monthly quota to show. Both appear only for
  -- Claude.ai Pro/Max, and only once a session has made a request.
  claude = {
    enabled = true,     -- the master switch for both halves
    statusline = true,  -- the 5h / 7d segment
    notify = true,      -- banner when a turn ends or needs you
    interval = 30,      -- seconds between checks; nothing runs on redraw
    stale_after = 1800, -- drop the segment once the data is this old,
                        -- rather than showing a number that has stopped
                        -- being true
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
