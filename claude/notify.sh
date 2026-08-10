#!/bin/sh
# Desktop notification for Claude Code, driven by its hooks.
#
#     notify.sh done         Claude finished a turn        (Stop hook)
#     notify.sh attention    Claude wants something        (Notification hook)
#
# The hook payload arrives as JSON on stdin; `cwd` is what makes the banner
# useful when several sessions are running, so it becomes the subtitle.
#
# Installed by :ClaudeSetup inside Neovim. To do it by hand, put this in
# ~/.claude/settings.json:
#
#     "hooks": {
#       "Notification": [{ "matcher": "", "hooks": [
#         { "type": "command", "command": "<repo>/claude/notify.sh attention" } ] }],
#       "Stop":         [{ "matcher": "", "hooks": [
#         { "type": "command", "command": "<repo>/claude/notify.sh done" } ] }]
#     }
#
# jq is optional — without it you get a generic body instead of the project
# name and the hook's own message.
#
# No focus detection. Suppressing the banner when the terminal is already
# frontmost needs Accessibility permission via System Events, which is too
# much to ask of a config other people clone.

set -u

kind="${1:-attention}"
input=$(cat 2>/dev/null) || input=""

title="Claude Code"
subtitle=""
case "$kind" in
  done)      message="Finished" ;;
  attention) message="Needs your attention" ;;
  *)         message="$kind" ;;
esac

if [ -n "$input" ] && command -v jq >/dev/null 2>&1; then
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && subtitle=$(basename "$cwd")

  # The Notification hook carries its own text ("Claude needs your
  # permission to use Bash"); it beats anything we could invent. Stop
  # carries last_assistant_message, which is prose and too long for a
  # banner, so `done` keeps its fixed wording.
  if [ "$kind" = "attention" ]; then
    hook_message=$(printf '%s' "$input" | jq -r '.message // empty' 2>/dev/null)
    [ -n "$hook_message" ] && message="$hook_message"
  fi
fi

# Banners are one line. Collapse anything that isn't.
message=$(printf '%s' "$message" | tr '\n\r\t' '   ')

# An AppleScript string literal, with backslashes and quotes escaped.
as_string() {
  printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
}

if command -v terminal-notifier >/dev/null 2>&1; then
  # Preferred when installed: the banner is clickable and groups by -group.
  if [ -n "$subtitle" ]; then
    terminal-notifier -title "$title" -subtitle "$subtitle" \
      -message "$message" -group "claude-code" >/dev/null 2>&1
  else
    terminal-notifier -title "$title" -message "$message" \
      -group "claude-code" >/dev/null 2>&1
  fi
elif [ "$(uname)" = "Darwin" ]; then
  script="display notification $(as_string "$message") with title $(as_string "$title")"
  [ -n "$subtitle" ] && script="$script subtitle $(as_string "$subtitle")"
  osascript -e "$script" >/dev/null 2>&1
elif command -v notify-send >/dev/null 2>&1; then
  [ -n "$subtitle" ] && message="$subtitle — $message"
  notify-send "$title" "$message" >/dev/null 2>&1
fi

# Never fail the hook. A missing notifier is not a reason to interrupt
# Claude, and a non-zero exit shows up as an error in the transcript.
exit 0
