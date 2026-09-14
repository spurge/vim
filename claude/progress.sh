#!/bin/sh
# Claude Code's working state -> Ghostty's progress bar, via Neovim.
#
#     progress.sh running    UserPromptSubmit, PostToolUse, PostToolUseFailure
#     progress.sh attention  Notification (reads its type from stdin)
#     progress.sh stop       Stop, StopFailure, SessionEnd
#
# Only does anything inside a Neovim terminal buffer. Straight in Ghostty,
# Claude Code drives the bar itself; inside Neovim it doesn't, so
# lua/core/hostterm.lua keeps one bar per session from these hooks instead
# (see M.remote_progress there for why each event maps where it does).
#
# Installed by :ClaudeSetup inside Neovim.

set -u

[ -n "${NVIM:-}" ] || exit 0
command -v nvim >/dev/null 2>&1 || exit 0

state="${1:-running}"
input=$(cat 2>/dev/null) || input=""

if [ "$state" = "attention" ]; then
  # A permission prompt means Claude is paused on you. The idle prompt, 60
  # seconds after a turn ended, means nothing is running — including after
  # an interrupt, which fires no Stop hook. Anything else changes nothing.
  case "$input" in
    *'"notification_type"'*'"permission_prompt"'* | \
    *'"notification_type"'*'"worker_permission_prompt"'* | \
    *'"notification_type"'*'"elicitation_dialog"'* | \
    *'"notification_type"'*'"elicitation_url_dialog"'* | \
    *'"notification_type"'*'"agent_needs_input"'*) state=waiting ;;
    *'"notification_type"'*'"idle_prompt"'*) state=stop ;;
    *) exit 0 ;;
  esac
fi

nvim --server "$NVIM" --remote-expr \
  "v:lua.require'core.hostterm'.remote_progress('$state',$PPID)" >/dev/null 2>&1

# Never fail the hook: a non-zero exit shows up as an error in the transcript.
exit 0
