# Neovim integration for zsh and bash.
#
#   echo 'source /path/to/this/repo/shell/nvim.sh' >> ~/.zshrc
#
# $NVIM is set for every child process of a :terminal buffer and points at
# that instance's RPC socket. This makes $EDITOR open a buffer in the
# Neovim you're already in rather than nesting a second one.

if [ -n "${NVIM:-}" ]; then
  # NOT `nvim --server $NVIM --remote-wait`: Neovim doesn't implement that
  # verb and answers E5600, which git reports as "there was a problem with
  # the editor". shell/nvim-edit builds the blocking behaviour out of
  # --remote plus a sentinel file.
  #
  # Found via the config dir rather than this file's location, so it
  # resolves correctly under NVIM_APPNAME too (e.g. `make try`).
  __nvim_edit="${XDG_CONFIG_HOME:-$HOME/.config}/${NVIM_APPNAME:-nvim}/shell/nvim-edit"
  if [ -x "$__nvim_edit" ]; then
    EDITOR="$__nvim_edit"
  else
    EDITOR="nvim"
  fi
  VISUAL="$EDITOR"
  GIT_EDITOR="$EDITOR"
  export EDITOR VISUAL GIT_EDITOR
  unset __nvim_edit

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
