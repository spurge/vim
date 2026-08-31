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

  -- ── Stacked windows ─────────────────────────────────────────────────
  -- i3/sway's `layout stacking`, for ONE column of windows inside a tab.
  -- The focused member fills the column; every other member collapses to a
  -- single row — its statusline, which reads as a title bar. Everything
  -- else in the tab keeps its normal geometry: the sidebar, any vsplit
  -- neighbour, the terminal splits. That's the difference between this and
  -- "the whole tab stacks", and it's the i3 model: stacking is a property
  -- of a container, not of the workspace.
  --
  -- <C-j> / <C-k> ARE the stack navigation. Moving focus into a collapsed
  -- member expands it, because they're ordinary windows that happen to be
  -- one row tall. ,zj / ,zk exist only to wrap around at the ends.
  --
  -- A tab holding a stack runs with laststatus=2 — one statusline per
  -- window — because that IS the title row. Tabs without a stack keep the
  -- global statusline; the flip is automatic, per tab.
  stack = {
    enabled = true,

    -- A :split made inside the stacked column joins the stack, rather than
    -- sitting in it as an odd full-height window. The sidebar, quickfix and
    -- help windows are never adopted, and neither are the <Leader>cs /
    -- <Leader>cc terminals — those own their own height, so they only join
    -- when you stack a column deliberately. Ordinary terminals ARE stackable
    -- either way, and mixing them in with files is the point.
    adopt = true,

    -- ,zj past the last member goes back to the first.
    wrap = true,

    -- What the title row says besides the filename. Same source as the tab
    -- list, so the two can't disagree about what a window holds.
    show_path = false,       -- the directory; costs a lot of a one-line title
    show_git = true,         -- +added ~changed -removed, from gitsigns
    show_diagnostics = true, -- ✖errors ⚠warnings, from the LSP
  },

  -- ── iTerm2 ──────────────────────────────────────────────────────────
  -- One-way cosmetic sync: Neovim tells iTerm2 what it's showing.
  --
  -- Cosmetic is the ceiling, and that's iTerm2's limit rather than a choice
  -- made here. There is no escape code to create, select or even enumerate
  -- an iTerm2 tab; its only native-tab bridge is tmux control mode
  -- (`tmux -CC`), which Neovim does not speak. Neovim tabs and iTerm2 tabs
  -- stay separate things. This makes the iTerm2 one say what the Neovim one
  -- contains.
  --
  -- `title` works in every terminal. The rest is OSC 1337 and is a silent
  -- no-op anywhere but iTerm2.
  iterm = {
    enabled = true,
    title = true,      -- 'titlestring' from the tab model
    user_vars = true,  -- OSC 1337 SetUserVar. Read them on the iTerm2 side as
                       -- \(user.nvim_tab) in a tab title, badge or status bar
    tab_color = true,  -- tint the native tab: amber unsaved, red on errors
    colors = { modified = "b58900", error = "cc241d" },
    interval = 250,    -- ms; nothing here ever runs at redraw time
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
