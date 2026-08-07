# Neovim integration for fish.
#
#   ln -sfn /path/to/this/repo/shell/nvim.fish ~/.config/fish/conf.d/nvim.fish
#
# conf.d/ is the idiomatic place: fish sources everything there before
# config.fish, and keeping it as a file in the repo means the repo stays
# the single source of truth.
#
# ── What this solves ──────────────────────────────────────────────────
# $NVIM is set automatically for every child process of a :terminal
# buffer and points at that instance's RPC socket. Without the functions
# below, typing `nvim foo.go` in a terminal split spawns Neovim INSIDE
# Neovim. With them, the file opens as a buffer in the instance you are
# already sitting in.

if set -q NVIM
    # NOT `nvim --server $NVIM --remote-wait`: Neovim doesn't implement
    # that verb and answers E5600, which git reports as "there was a
    # problem with the editor". shell/nvim-edit builds the blocking
    # behaviour out of --remote plus a sentinel file.
    #
    # Found via the config dir rather than this file's location, so it
    # resolves correctly under NVIM_APPNAME too (e.g. `make try`).
    set -l __nvim_edit (set -q XDG_CONFIG_HOME; and echo $XDG_CONFIG_HOME; or echo $HOME/.config)/(set -q NVIM_APPNAME; and echo $NVIM_APPNAME; or echo nvim)/shell/nvim-edit

    if test -x "$__nvim_edit"
        # QUOTED deliberately. Unquoted, fish exports this as a list; git
        # parses $EDITOR as a single shell command string and breaks.
        set -gx EDITOR "$__nvim_edit"
        set -gx VISUAL "$__nvim_edit"
        set -gx GIT_EDITOR "$__nvim_edit"
    else
        set -gx EDITOR nvim
        set -gx VISUAL nvim
    end
else
    set -gx EDITOR nvim
    set -gx VISUAL nvim
end

# Functions, not aliases, deliberately.
#
# `alias nvim="nvim ..."` in fish defines a function named nvim whose body
# calls nvim — which recurses forever. `command` breaks the cycle.
# --wraps keeps completions working.

function nvim --wraps nvim --description "open in the parent nvim when nested"
    if set -q NVIM; and test (count $argv) -gt 0
        command nvim --server $NVIM --remote $argv
    else
        # No args, or not nested: behave normally. A bare `nvim` inside a
        # terminal split WILL nest — use <Leader>E in the outer instance
        # to hand the escape key down to it.
        command nvim $argv
    end
end

function vim --wraps nvim --description "nvim, remote-aware"
    nvim $argv
end

function vi --wraps nvim --description "nvim, remote-aware"
    nvim $argv
end

# ── OSC 11 under multiplexers ─────────────────────────────────────────
# Neovim reads the terminal background via OSC 11 to drive light/dark
# switching. tmux swallows it unless passthrough is on:
#
#   set -g allow-passthrough on    # ~/.tmux.conf
