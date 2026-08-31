# nvim

A small, hand-rolled Neovim configuration. Seven plugins, no framework.

(Plus whichever colorschemes you list — those are taste, not machinery.)

Built on Neovim 0.12's native features rather than around them: `vim.pack`
for plugins, `vim.lsp` for language servers, `vim.lsp.completion` for
autocomplete, `vim.diagnostic` for linting. Around 3,100 lines of Lua, and
1,300 more of comments explaining the why — small enough to read end to end
and own, instead of a distribution you configure by overriding.

The *why* behind each decision lives in the file that implements it —
`lua/core/*.lua` is commented for reading. This file is the map.

**Requires Neovim 0.12+.**

## Quick start

```sh
make verify    # what your languages need, and how to install what's missing
make try       # launch sandboxed — does not touch your existing config
make link      # install as ~/.config/nvim (backs up what's there)
```

`make try` runs under `NVIM_APPNAME=nvim-test`, so it gets its own config
*and* plugin directory. Back out by deleting `~/.config/nvim-test`.

`make` on its own lists everything.

## Make it yours

Everything you'd want to change is in **`lua/settings.lua`**. You should
not need to edit anything under `lua/core/`.

```lua
return {
  languages = { "go", "python", "lua" },   -- the master switch
  leader = ",",
  theme = { follow_system = true },        -- plus a `themes` list to cycle
  tabs = { display = "sidebar" },          -- or "tabline"
  stack = { enabled = true },              -- i3-style stacked windows
  iterm = { enabled = true },              -- nvim -> iTerm2 title / tab colour
  terminal = { agent = "claude" },
  claude = { enabled = true },             -- rate limits + notifications
}
```

For machine-specific tweaks you don't want committed, create
`lua/settings_local.lua` returning a partial table — merged over the top.

**`languages` drives everything downstream**: LSP servers, treesitter
parsers, formatters, and what `make verify` checks for. Delete a line and
that language's whole toolchain requirement disappears — write only Go and
you install two servers, not sixteen. Available: `go` `typescript` `ruby`
`terraform` `terragrunt` `bash` `python` `swift` `kotlin` `toml` `yaml`
`json` `lua` `markdown`. Add your own with one entry in
`lua/core/languages.lua`.

Servers are installed with your system package manager, not from inside
the editor — `make verify` prints the exact command for each missing one.
`mise.toml` is there if you want version pinning; entirely optional.

## Keymaps

Leader is `,`, set in `settings.lua`.

There is no clipboard section here, and that's deliberate: `clipboard` is
`unnamedplus`, so plain `y` and `p` are the system clipboard. One way to
copy, one way to paste, nothing to configure. Deletes go through it too —
`"0p` still pastes the last yank when a `d` has overwritten it.

### Files, search, windows

| Key                 | Action                                    |
|---------------------|-------------------------------------------|
| `<C-n>`             | file explorer (oil)                       |
| `,f` `,g` `,b`      | files / live grep / buffers               |
| `,d` `,D`           | diagnostics: buffer / project             |
| `,s` `,S`           | symbols: buffer / project                 |
| `,/` `,*`           | search in buffer / grep word under cursor |
| `,r`                | resume last picker                        |
| `,n` `,p` `,t` `,T` | tab next / prev / new / close             |
| `,B`                | tabs: stacked sidebar ⇄ top tabline       |
| `<C-h/j/k/l>`       | move between splits                       |
| `,-` `,\|` `,=`     | split h / split v / equalise              |
| `,m` `<C-w>T`       | move window to a tab / to a new tab       |
| `<C-w>x` `<C-w>r`   | swap with next / rotate, within the column|
| `<C-w>H/J/K/L`      | move window to far left/bottom/top/right  |
| `,zz` `,za` `,zx`   | stack: toggle column / add / remove       |
| `,zj` `,zk`         | stack: next / prev member (wraps)         |

### LSP

Mostly Neovim 0.11+ defaults, which need no configuration:

| Key         | Action                            |
|-------------|-----------------------------------|
| `K`         | hover documentation               |
| `grr`       | references (via picker)           |
| `grn` `gra` | rename / code action              |
| `gri` `grt` | implementations / type definition |
| `gO`        | document symbols                  |
| `<C-s>`     | signature help (insert mode)      |
| `gd` `gD`   | definition / declaration          |
| `,gd`       | definition in a vertical split    |
| `]d` `[d`   | next / prev diagnostic            |
| `,k`        | line diagnostics float            |
| `,i`        | toggle inlay hints                |
| `<C-e>`     | force completion (insert mode)    |

### Git, terminal, misc

| Key                     | Action                                   |
|-------------------------|------------------------------------------|
| `]c` `[c`               | next / prev hunk                         |
| `,hp` `,hs` `,hr` `,hb` | hunk preview / stage / reset / blame     |
| `,vs` `,vb` `,vl`       | git status / branches / log              |
| `<C-Space>`             | leave terminal mode                      |
| `,E`                    | toggle terminal escape passthrough       |
| `,cs` `,cV`             | shell split / vertical shell split       |
| `,cc` `,cv` `,cf`       | agent toggle / vertical / send file path |
| `,F`                    | format buffer or selection               |
| `,tt` `,tn`             | toggle light/dark / next colorscheme     |

## Stacked windows

The sidebar gives you i3's *tabs*. `,zz` gives you its **stacking**.

In i3, stacking is a property of a container, not of the workspace: one
container's children stack — one visible, the rest reduced to title bars —
while the rest of the layout stays tiled. That is what this does. Split a
column with `,-` a couple of times, press `,zz`, and the focused window
fills the column while every other window in *that column* collapses to a
single row. The sidebar, any `,|` neighbour and the terminal splits are
left exactly where they were.

```
┌─ sidebar ─┐┌──────────────────────────┐
│ ▼ Tab 1   ││                          │
│  ● one.lua││   one.lua                │  ← the expanded member
│    two.lua│└──────────────────────────┘
│ ▶ Tab 2   │  two.lua            ✎ ✖1     ← collapsed: one row, and that
│           │  README.md                     row is its statusline
└───────────┘
```

**`<C-j>` and `<C-k>` are the navigation.** There is nothing new to learn: a
collapsed member is an ordinary window that happens to be one row tall, so
the split-movement keys walk into it, and entering it is what expands it.
`,zj` / `,zk` exist only to wrap around at the ends.

`,za` brings another window into the stack — from the same column, or from
elsewhere in the tab, in which case the window moves and keeps its cursor
and scroll position. `,zx` takes one back out with a fair share of the
column. `,zz` again, or `:Stack!`, ends the stack and leaves ordinary
splits behind.

Splitting a stacked window *vertically* ends the stack, because once one
member is a row rather than a window, "a column of windows" has stopped
describing the layout. `,zz` puts it back.

### Moving windows inside a tab

Native Vim, nothing added here. `<C-w>x` swaps the current window with the
next one in its column, `<C-w>r` rotates the column (`<C-w>R` the other way),
and `<C-w>H` `<C-w>J` `<C-w>K` `<C-w>L` move it to the far left, bottom, top
or right — which restructures the layout rather than just reordering it.
`,m` and `<C-w>T` move a window to another tab instead.

In a stack, `<C-w>x` and `<C-w>r` reorder the members and the stack survives.
`<C-w>H/J/K/L` end it, because the members stop being one column — the same
rule as splitting a member vertically.

Be aware that `<C-w>H` puts the window to the left of the *sidebar*, and
`<C-w>J` squeezes the sidebar vertically. That's Vim doing what it was asked;
`,B` twice puts the sidebar back where it belongs.

### Terminals stack too

A column can mix shells and files freely — that is most of the point. A
terminal member shows as `$ <command>` in its title row.

Collapsing one works differently underneath, and it has to. Neovim refuses to
shrink a terminal window below one text line, and at one line the PTY reflows
onto a one-row screen and **destroys everything the job prints**: of 50 lines
written to a shrunk terminal, 0 survived. So a collapsed terminal doesn't
hold its terminal at all — the buffer is parked out of the window and goes
hidden, exactly as `,cs` already relies on, and all 50 lines survive. Focus it
and the terminal comes straight back, still running, with its scrollback
intact.

The `,cs` and `,cc` terminals are a half-exception. They are toggleable
overlays that own their own height, so a stray `:split` never sweeps one into
a stack — but stacking a column that contains one *on purpose* works fine,
because that's a decision rather than an accident. Any other terminal —
`:terminal`, `,cV`, `,cv`, a plain `:split | terminal` — is an ordinary
member either way.

`,zz` pressed while the cursor is in the sidebar stacks the content column,
rather than telling you the sidebar isn't a file window. When it does refuse,
it names the actual reason — a quickfix or help window can't be a member, and
a lone window has no column to stack.

## iTerm2

`titlestring` is set from the tab model in every terminal, so the terminal's
own tab or window title says which Neovim tab you are on — its `:TabRename`
name if it has one, else its index and directory.

Inside iTerm2 there is a little more. The config exports `nvim_tab`,
`nvim_index`, `nvim_tabs`, `nvim_errors`, `nvim_warnings`, `nvim_modified`
and `nvim_cwd` as iTerm2 user variables, and tints the native tab amber when
something is unsaved and red when something has an error. **The variables do
nothing until you reference them**: put `\(user.nvim_tab)` in iTerm2's tab
title format, in a status bar component, or in the badge. Nothing goes on
the wire unless a value actually changed, and nothing is computed at redraw
time.

What it deliberately does not do is make Neovim tabs *be* iTerm2 tabs — see
the gotcha below for why that is not a missing feature.

## Claude Code

On by default; `claude = { enabled = false }` in `lua/settings.lua` turns the
whole thing off. **No API key, ever** — both halves read what Claude Code
already writes under the auth of the session you're logged into.

**Rate limits in the statusline.** `5h 24% ⟳2h13m  7d 41%` — the rolling
session window with the time until it clears, and the weekly one. Amber past
75%, red past 90%. Two windows and not three because that is what Anthropic
reports; there is no monthly quota to show.

**A notification when a turn ends** or when Claude wants permission — the same
information you'd otherwise get by watching the `,cc` split.

The statusline half works on its own, reading `cachedUsageUtilization` from
`~/.claude.json`. For live numbers and for notifications, run **`:ClaudeSetup`**
once. It adds three entries to `~/.claude/settings.json` — a `statusLine`
command and two hooks, all pointing at `claude/*.sh` in this repo — after
showing you exactly what it will add and backing the file up. Everything else in
there is left alone. `:ClaudeSetup!` takes them out again.

`:ClaudeUsage` prints the current numbers, which of the two sources they came
from and how old they are — start there if the segment is empty.

`jq` and `terminal-notifier` are both optional, and only make the output
prettier. Nothing here is a required dependency.

Commenting is native since 0.10: `gcc`, `gc{motion}`, `gbc`. In the
sidebar: `<CR>` or click opens, `<Tab>` folds a tab group, double-clicking
a tab header renames it, `d` deletes a buffer, `q` returns to the tabline.

## Layout

```
lua/settings.lua            ← the file you edit
lua/settings_local.lua      ← optional, machine-specific
lua/core/
  config.lua                resolves defaults + settings + local
  languages.lua             the language registry — one entry per language
  plugins.lua               vim.pack.add + setup calls
  options.lua               editor options
  keymaps.lua               keymaps
  theme.lua                 colorscheme + OS light/dark
  lsp.lua                   native vim.lsp
  shell.lua                 which shell for :terminal vs for system()
  terminal.lua              escape, nesting, agent splits
  format.lua                format on save
  statusline.lua            native statusline
  tabs.lua                  tab model + top tabline
  sidebar.lua               the stacked left-hand view of that model
  stack.lua                 i3-style stacked windows inside one tab
  iterm.lua                 one-way nvim -> iTerm2 title / tab colour
  claude.lua                Claude Code rate limits + :ClaudeSetup
  reload.lua                :Reload — settings changes without a restart
  remote.lua                the waiting half of $EDITOR
claude/statusline.sh        Claude Code's statusLine command; tees its JSON
claude/notify.sh            the Stop / Notification hook handler
lsp/*.lua                   per-server overrides, auto-discovered
after/ftplugin/*.lua        per-language indent
shell/nvim.fish, nvim.sh    $NVIM handling
shell/nvim-edit             $EDITOR that opens in the parent and blocks
scripts/verify.lua          tool check, driven by the language registry
mise.toml                   optional tool pinning + tasks
```

Seven plugins, each because there is no native equivalent: nvim-lspconfig
(**data only** — server specs, never `setup()`), nvim-treesitter,
oil.nvim, fzf-lua, gitsigns.nvim, conform.nvim, mini.surround. Plus every
colorscheme in `theme.themes` — those are taste, not machinery, which is
why they're not in the count.

Absent because the core does it: plugin manager, LSP wrapper, completion
engine, linting framework, statusline, bufferline / tab sidebar, indent
guides, commenting, indent detection, LSP installer.

## Commands

```sh
make update     # update plugins, refresh lockfile
make pin        # roll back to the lockfile after a bad update
make health     # :checkhealth
make lsp        # which servers attached
make lint       # lua syntax + stylua + shell syntax + config loads
make clean      # wipe plugins; next launch reinstalls from lockfile
```

**Commit the lockfile** `vim.pack` writes — it's what keeps multiple
machines on identical plugin revisions.

In-editor: `:Reload` (re-read settings without restarting), `:Tabs`,
`:TabsToggle`, `:TabRename [name]` (`!` clears it),
`:WinMoveTab {n|name}` (`!` splits vertically), `:Stack` (`!` unstacks),
`:StackToggle`, `:StackAdd`, `:StackRemove`, `:StackNext`, `:StackPrev`,
`:ThemesToggle`
(next colorscheme), `:Theme <name>`,
`:ThemeToggle` (light/dark), `:FormatInfo`, `:FormatOff[!]`, `:FormatOn`,
`:Shell`, `:ShellInfo`, `:ClaudeSetup[!]`, `:ClaudeUsage`,
`:checkhealth vim.lsp`.

`theme.themes` in `lua/settings.lua` is an ordered list; `:ThemesToggle`
(`,tn`) cycles it and the choice is remembered across restarts in
`stdpath("state")`. Two kinds of colorscheme, and the distinction is the
only fiddly part: `options` become `vim.g.<key>` before loading (how the
sainnhe themes are configured), `setup` is passed to
`require(module).setup()` before loading (how Lua-configured ones like
monokai-nightasty are). Both must happen *before* `:colorscheme`, not
after.

## Gotchas

- **Never `set background=...`.** Assigning it makes Neovim delete its own
  OSC 11 detection autocmd, and automatic light/dark dies silently. Under
  tmux you also need `set -g allow-passthrough on`.
- **`brew install tree-sitter` is not the CLI.** That formula is the
  library; nvim-treesitter needs `tree-sitter-cli`. Without it every
  grammar fails to build, on every launch. `make verify` checks for it.
- **`:Reload` skips four modules on purpose** — `plugins.lua`, `lsp.lua`,
  `shell.lua`, `terminal.lua`. Their state is live (loaded plugins,
  running clients, terminal jobs). Change those and restart. It *does* now
  reload itself, which it previously didn't: `:Reload` used to run the copy
  loaded at startup forever, so its own module lists were frozen at whatever
  they said when the session began. Adding a module and reloading then
  brought back every other changed file but never the new module — leaving,
  for instance, a keymap calling a command whose module was never loaded to
  define it.
- **Shell integration** (`make shell-integration`) stops `$EDITOR` from
  spawning Neovim inside Neovim. It needs `function`, not `alias` — fish's
  `alias nvim=nvim` recurses forever. See `shell/nvim.fish`.
- **Neovim has no `--remote-wait`.** It answers `E5600: Wait commands not
  yet implemented`, and git reports "there was a problem with the editor".
  `$EDITOR` therefore points at `shell/nvim-edit`, which rebuilds the
  blocking from `--remote-tab` plus a sentinel file. Don't put
  `--remote-wait` in `$EDITOR` yourself — it has never worked. The commit
  message opens in its own tab so `:wq` returns you to the terminal you
  typed `git commit` in, rather than displacing it.
- **If fzf-lua returns nothing** or a formatter silently stops, set
  `shell = { internal = "posix" }`. Plugins emit POSIX constructs fish
  rejects. `:ShellInfo` shows what's in effect.
- **The Claude Code rate-limit segment can legitimately be empty.** Anthropic
  reports `rate_limits` only for Claude.ai Pro/Max, and only once a session has
  made a request — an API-key or Bedrock setup has nothing to show. It also
  disappears rather than freezing when the data goes stale (`stale_after`,
  default 30 min), because a percentage from an expired window is worse than no
  percentage. `:ClaudeUsage` says which case you're in.
- **A stacked tab runs `laststatus=2`.** That is the mechanism, not a
  preference: a collapsed member's statusline *is* its title bar, and under
  `laststatus=3` there are no per-window statuslines at all, so a collapsed
  window would draw zero rows and vanish. Tabs without a stack keep the
  global statusline; the flip is automatic and per tab. `winminheight` also
  goes to 0 for the session once any stack exists — harmless, since a window
  only shrinks if something explicitly shrinks it.
- **A window moved between tabs leaves its stack.** `,m` and `<C-w>T` both
  close and recreate the window, and window-local variables do not survive
  that. Deliberate, not a bug — `,za` puts it into the stack at the far end.
- **`<C-w>T` is wrapped.** Vanilla `<C-w>T` is a no-op in a single-window
  tab, but the sidebar is a real window, so Vim's count sees two and lets
  the move through — leaving a tab holding nothing but a sidebar, which the
  guard then closes, so the window appears to snap straight back. The
  wrapper counts only content windows and restores the original no-op.
- **iTerm2 tab sync is cosmetic, and that is iTerm2's ceiling.** There is no
  escape code to create, select or enumerate an iTerm2 tab; its only
  native-tab bridge is tmux control mode (`tmux -CC`), which Neovim does not
  speak. Nor would driving iTerm2 from outside help: every iTerm2 tab is a
  separate PTY running a separate process, while a Neovim tabpage is global
  editor state — every client attached with `--remote-ui` mirrors the same
  screen and the same current tabpage. Under tmux the OSC 1337 sequences
  need `allow-passthrough on`, the same as OSC 11 above.
- **`theme.follow_system` is degraded under iTerm2**, which does not answer
  OSC 11 reliably. `SetUserVar` cannot rescue it: it is write-only, so
  Neovim can publish to iTerm2 but never read the terminal's background back.
  Use the `auto-dark-mode.nvim` fallback noted at the end of the theme
  section. The inverse direction does work — iTerm2's Automatic Profile
  Switching can key off `\(user.nvim_cwd)`, so iTerm2 can follow Neovim.
- **`,cs` / `,cV` / `,cv` used to eat the buffer you were editing.** Fixed,
  but worth knowing why: `jobstart(..., { term = true })` converts the
  *current* buffer into the terminal, and `botright split` hands the new
  window the buffer it split from — so opening a shell turned that file into
  the shell and left two windows showing it. There is now an `:enew` in
  between, which is the pattern the API docs use. `core.terminal` is one of
  the four modules `:Reload` skips, so this one needed a restart to take
  effect.
- **`<C-w>H` `<C-w>J` `<C-w>K` `<C-w>L` and `<C-w>r` fire no autocmds at
  all** — not `WinNew`, not `WinClosed`, not `WinEnter`, not even
  `WinResized`. Measured; only `<C-w>x` fires anything, and only because it
  moves the cursor. A stack therefore cannot learn about a window move from
  an event, so `core.stack` watches a cheap fingerprint of window geometry on
  `SafeState` instead. Without that, `<C-w>H` out of a stack left the
  collapsed members at zero rows — invisible windows with no way back.
- **Terragrunt / Swift / Kotlin** language servers are all partial:
  `terragrunt-ls` is an early WIP, `sourcekit-lsp` needs a
  `Package.swift`, `kotlin-lsp` is JetBrains-internal and incomplete for
  multiplatform. `terraform-ls` returns nothing until `tofu init` has run.

## License

MIT — see `LICENSE`.
