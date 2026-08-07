# nvim

A small, hand-rolled Neovim configuration. Seven plugins, no framework.

(Plus whichever colorschemes you list — those are taste, not machinery.)

Built on Neovim 0.12's native features rather than around them: `vim.pack`
for plugins, `vim.lsp` for language servers, `vim.lsp.completion` for
autocomplete, `vim.diagnostic` for linting. Roughly 1,600 lines you can
read in an afternoon, instead of a distribution you configure by
overriding.

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
  clipboard = "explicit",                  -- y/p local, \y/\p system
  theme = { follow_system = true },        -- plus a `themes` list to cycle
  tabs = { display = "sidebar" },          -- or "tabline"
  terminal = { agent = "claude" },
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

Leader is `,`. Where a table says `\`, that's `clipboard_prefix` — a
literal prefix, not leader, so `,p` (tab prev) and `\p` (paste) coexist.

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

| Key                     | Action                                           |
|-------------------------|--------------------------------------------------|
| `]c` `[c`               | next / prev hunk                                 |
| `,hp` `,hs` `,hr` `,hb` | hunk preview / stage / reset / blame             |
| `,vs` `,vb` `,vl`       | git status / branches / log                      |
| `<C-Space>`             | leave terminal mode                              |
| `,E`                    | toggle terminal escape passthrough               |
| `,cs` `,cV`             | shell split / vertical shell split               |
| `,cc` `,cv` `,cf`       | agent toggle / vertical / send file path         |
| `,F`                    | format buffer or selection                       |
| `,tt` `,tn`             | toggle light/dark / next colorscheme             |
| `\y` `\p`               | system clipboard (when `clipboard = "explicit"`) |

Commenting is native since 0.10: `gcc`, `gc{motion}`, `gbc`. In the
sidebar: `<CR>` or click opens, `<Tab>` folds a tab group, `d` deletes a
buffer, `q` returns to the tabline.

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
  reload.lua                :Reload — settings changes without a restart
  remote.lua                the waiting half of $EDITOR
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
`:TabsToggle`, `:ThemesToggle` (next colorscheme), `:Theme <name>`,
`:ThemeToggle` (light/dark), `:FormatInfo`, `:FormatOff[!]`, `:FormatOn`,
`:Shell`, `:ShellInfo`, `:checkhealth vim.lsp`.

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
  running clients, terminal jobs). Change those and restart.
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
- **Terragrunt / Swift / Kotlin** language servers are all partial:
  `terragrunt-ls` is an early WIP, `sourcekit-lsp` needs a
  `Package.swift`, `kotlin-lsp` is JetBrains-internal and incomplete for
  multiplatform. `terraform-ls` returns nothing until `tofu init` has run.

## License

See `LICENSE`.
