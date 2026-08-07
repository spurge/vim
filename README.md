# nvim

A small, hand-rolled Neovim configuration. Nine plugins, no framework.

Built on Neovim 0.12's native features rather than around them: `vim.pack`
for plugins, `vim.lsp` for language servers, `vim.lsp.completion` for
autocomplete, `vim.diagnostic` for linting. The result is roughly 1,400
lines you can read in an afternoon, instead of a distribution you
configure by overriding.

**Requires Neovim 0.12+.**

## Quick start

```sh
git clone <this-repo> nvim && cd nvim

make verify    # what your languages need, and how to install what's missing
make try       # launch sandboxed — does not touch your existing config
```

`make try` runs under `NVIM_APPNAME=nvim-test`, so it gets its own config
*and* plugin directory. Your current setup is untouched. Back out by
deleting `~/.config/nvim-test`.

When you're happy:

```sh
make link                # install as ~/.config/nvim (backs up what's there)
make shell-integration   # prints the fish/zsh/bash snippet — see below
```

`make` on its own lists everything.

## Make it yours

Everything you'd want to change is in **`lua/settings.lua`**. You should
not need to edit anything under `lua/core/`.

```lua
return {
  languages = { "go", "python", "lua" },   -- the master switch
  leader = ",",
  clipboard = "explicit",
  theme = { colorscheme = "gruvbox-material", follow_system = true },
  terminal = { agent = "claude" },
  -- ...
}
```

For machine-specific tweaks you don't want committed, create
`lua/settings_local.lua` returning a partial table. It's gitignored and
merged over the top.

### The languages list is the important one

It drives everything downstream — LSP servers, treesitter parsers,
formatters, and what `make verify` checks for. Delete a line and that
language's entire toolchain requirement disappears:

| `languages`       | LSP servers | required tools |
|-------------------|-------------|----------------|
| all 14            | 16          | 19             |
| `{ "go", "lua" }` | 2           | 3              |

So if you only write Go, you install two servers, not sixteen. Available:
`go` `typescript` `ruby` `terraform` `terragrunt` `bash` `python` `swift`
`kotlin` `toml` `yaml` `json` `lua` `markdown`.

Adding your own means one entry in `lua/core/languages.lua`:

```lua
rust = {
  servers = { "rust_analyzer" },
  parsers = { "rust" },
  formatters = { rust = { "rustfmt" } },
  tools = { { "rust-analyzer", "Rust LSP", "rustup component add rust-analyzer" } },
},
```

then add `"rust"` to `languages`. Nothing else.

### Leader

`,` by default, because it's a single unmodified key on every layout.
`<Space>` is the popular choice but costs you space-as-right-motion in
normal mode. `\` is the vim default but a three-key chord on many ISO
layouts. Change `leader` in settings and every mapping follows.

### Clipboard

- `"explicit"` — `y`/`p` stay register-local; `\y`/`\p` use the system
  clipboard. Keeps the two deliberately separate.
- `"system"` — plain `y`/`p` go straight to the system clipboard.

## Installing language servers

Servers are installed with your system package manager, not from inside
the editor. `make verify` tells you exactly what's missing and prints the
command for each:

```
go
  ✓ gopls                            Go LSP
  ✗ goimports                        Go imports
      go install golang.org/x/tools/cmd/goimports@latest
```

`mise.toml` is provided if you use [mise](https://mise.jdx.dev) and want
version pinning — `make install` uses it. It's entirely optional; brew,
apt, npm or nothing all work fine.

This is deliberate. An in-editor installer like mason gives you a second
package manager whose versions can silently diverge from the ones your
projects actually build against.

## Shell integration

`make shell-integration` prints the snippet. What it does and why:

`$NVIM` is set automatically for every child process of a `:terminal`
buffer and points at that instance's RPC socket. Without the integration,
typing `nvim foo.go` in a terminal split spawns Neovim *inside* Neovim.
With it, the file opens as a buffer in the instance you're already in —
and so do `git commit`, `git rebase -i`, and any CLI tool that respects
`$EDITOR`.

Two fish-specific details, both easy to get wrong:

- `set -gx EDITOR "nvim --server $NVIM --remote-wait"` is **quoted**.
  Unquoted, fish exports it as a list; git parses `$EDITOR` as a single
  shell command string and breaks.
- It defines `function nvim`, not `alias nvim`. Fish's `alias nvim="nvim
  ..."` generates a function that calls `nvim` — infinite recursion. The
  function uses `command nvim` to break the cycle.

### Which shell Neovim uses internally

Neovim's `'shell'` option is used for `:!`, `system()`, plugin shell-outs,
*and* `:terminal`. Non-POSIX shells (fish, nushell) are fine for the last
one but break the others, because plugins emit POSIX constructs —
`2>/dev/null`, `VAR=x cmd`, nested `$(...)` — that those shells reject or
reinterpret.

`lua/core/shell.lua` therefore splits the roles: POSIX for internals,
your interactive shell for terminal splits. Setting `'shell'` to fish
globally is the usual cause of "conform silently stopped formatting".

## Automatic light/dark

With `theme.follow_system = true` the chain is:

```
OS appearance (incl. its sunrise/sunset schedule)
  → terminal swaps palette, emits OSC 11
    → Neovim flips 'background' itself
      → autocmd reloads the colorscheme
```

No polling, no plugin doing the switching. Needs a terminal that reports
its background — Ghostty, WezTerm, kitty, Alacritty. Ghostty also follows
the OS setting on its own:

```
theme = light:gruvbox-material-light,dark:gruvbox-material
```

Under tmux, add `set -g allow-passthrough on` or OSC 11 never arrives.

> **Never `set background=...` in your config.** Assigning it explicitly
> makes Neovim delete its own OSC 11 detection autocmd, and the whole
> chain dies silently. This is the single most common way to break it.

For terminals that stay silent, add `f-person/auto-dark-mode.nvim` to
`extra_plugins` — see the note at the bottom of `lua/core/theme.lua`.

## Terminal mode and the nesting problem

`<C-\><C-n>` is swallowed by the *outermost* Neovim, so an inner Neovim
in a terminal buffer never sees it. Every nesting level needs its own way
out, and whatever key you pick gets eaten at the top first. Three-part
answer:

1. **Mostly avoid nesting** — the shell integration above means `$EDITOR`
   opens buffers in the current instance instead of spawning a new one.
2. **Escape with a control chord**, not a printable key.
   `settings.terminal.escape` defaults to `{ "<C-Space>", "<C-@>" }`
   (both, because terminals disagree — the kitty keyboard protocol sends
   a real `<C-Space>`, older ones send NUL, reported as `<C-@>`). A
   printable escape gets eaten by things you legitimately type: `\e`
   breaks `printf '\e[31m'`, `,e` breaks `ls {a,e}`.
3. **`<Leader>E` toggles passthrough** for a specific terminal buffer,
   handing the escape key down to the inner layer instead of consuming
   it. Buffer-local mappings beat global ones, which is what makes this
   work.

`<C-h/j/k/l>` are deliberately *not* mapped in terminal mode: `<C-l>` is
clear-screen and `<C-k>` is kill-line in every common shell. Escape
first, then `<C-w>h`.

## Keymaps

Leader is `,` by default. Where a table says `\`, that's
`clipboard_prefix` — a literal prefix, not leader, so both `,p` (tab
prev) and `\p` (paste) can coexist.

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
| `,tt`                   | toggle light/dark manually                       |
| `\y` `\p`               | system clipboard (when `clipboard = "explicit"`) |

Commenting is native since 0.10: `gcc`, `gc{motion}`, `gbc`.

## Layout

```
lua/settings.lua            ← the file you edit
lua/settings_local.lua      ← optional, gitignored, machine-specific
lua/core/
  config.lua                resolves defaults + settings + local
  languages.lua             the language registry — one entry per language
  plugins.lua               vim.pack.add + setup calls
  options.lua               editor options
  keymaps.lua               keymaps
  theme.lua                 colorscheme + OS light/dark
  lsp.lua                   native vim.lsp
  shell.lua                 POSIX internally, your shell interactively
  terminal.lua              escape, nesting, agent splits
  format.lua                format on save
  statusline.lua            native statusline + tabline
lsp/*.lua                   per-server overrides, auto-discovered
after/ftplugin/*.lua        per-language indent
shell/nvim.fish, nvim.sh    $NVIM handling
scripts/verify.lua          tool check, driven by the language registry
mise.toml                   optional tool pinning + tasks
```

## What's a plugin and what isn't

Nine plugins, each because there is no native equivalent:

| Plugin          | For                                           |
|-----------------|-----------------------------------------------|
| a colorscheme   | `theme.plugin`, swappable                     |
| nvim-lspconfig  | **data only** — server specs, never `setup()` |
| nvim-treesitter | grammars                                      |
| oil.nvim        | file explorer                                 |
| fzf-lua         | fuzzy finder                                  |
| gitsigns.nvim   | gutter signs, hunk staging                    |
| conform.nvim    | formatting                                    |
| mini.surround   | `ys` / `cs` / `ds`                            |

Absent because the core does it: plugin manager (`vim.pack`), LSP wrapper
(`vim.lsp`), completion engine (`vim.lsp.completion`), linting framework
(`vim.diagnostic`), statusline plugin, indent guides (`listchars`),
commenting, indent detection (`after/ftplugin/`), LSP installer.

## Maintenance

```sh
make update     # update plugins, refresh lockfile
make pin        # roll back to the lockfile after a bad update
make health     # :checkhealth
make lsp        # which servers attached
make lint       # lua syntax + stylua + shell syntax + config loads
make clean      # wipe plugins; next launch reinstalls from lockfile
```

**Commit the lockfile** `vim.pack` writes. It's what keeps multiple
machines on identical plugin revisions.

In-editor: `:FormatInfo`, `:FormatOff[!]`, `:FormatOn`, `:ThemeToggle`,
`:Shell`, `:checkhealth vim.lsp`.

## Known rough edges

- **Terragrunt.** `terragrunt-ls` is officially maintained but the
  maintainers describe it as a work in progress. You get hover and
  go-to-definition on `include`/`dependency` blocks, not the completion
  depth `terraform-ls` gives `.tf` files. Treesitter plus `terragrunt hcl
  fmt` does the rest.
- **terraform-ls returns nothing until `tofu init`** has run — it reads
  provider schemas from `.terraform/`.
- **Swift** needs a `Package.swift` or `.xcodeproj` before
  `sourcekit-lsp` is useful; bare `.swift` files get syntax and little
  else.
- **Kotlin.** JetBrains' `kotlin-lsp` is based on IntelliJ internals and
  is partially closed-source. Multiplatform support is incomplete. Good
  for plain JVM Gradle/Maven projects.
- **mise tool identifiers** come from mise's registry and occasionally
  drift. `make verify` checks what's actually on PATH rather than
  trusting the manifest.

## License

See `LICENSE`.
