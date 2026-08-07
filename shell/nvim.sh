# Neovim integration for zsh and bash.
#
#   echo 'source /path/to/this/repo/shell/nvim.sh' >> ~/.zshrc
#
# $NVIM is set for every child process of a :terminal buffer and points at
# that instance's RPC socket. This makes $EDITOR open a buffer in the
# Neovim you're already in rather than nesting a second one.

if [ -n "${NVIM:-}" ]; then
  EDITOR="nvim --server $NVIM --remote-wait"
  VISUAL="$EDITOR"
  GIT_EDITOR="$EDITOR"
  export EDITOR VISUAL GIT_EDITOR

  nvim() {
    if [ "$#" -gt 0 ]; then
      command nvim --server "$NVIM" --remote "$@"
    else
      command nvim
    fi
  }
  vim() { nvim "$@"; }
  vi() { nvim "$@"; }
else
  export EDITOR=nvim
  export VISUAL=nvim
fi

# Under tmux, add `set -g allow-passthrough on` to ~/.tmux.conf or the
# OSC 11 light/dark detection never reaches Neovim.
