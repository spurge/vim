#!/bin/sh
# Claude Code's `statusLine` command, and the only way to get live rate-limit
# numbers out of Claude Code without inventing a second credential.
#
# ── Why this exists ───────────────────────────────────────────────────
# Claude Code pipes a JSON blob to this script on every status line render.
# For Claude.ai subscribers that blob carries `rate_limits.five_hour` and
# `rate_limits.seven_day` — the same percentages `/usage` shows, using the
# session's own auth. Nothing else on the machine publishes them live: the
# transcripts under ~/.claude/projects record token counts but no limits,
# and there is no `claude usage` subcommand.
#
# So: tee the blob to a state file that lua/core/claude.lua polls, and print
# a short line for Claude Code's own status bar while we're here.
#
# Installed by :ClaudeSetup inside Neovim. To do it by hand, put this in
# ~/.claude/settings.json:
#
#     "statusLine": { "type": "command", "command": "<repo>/claude/statusline.sh" }
#
# jq is optional. Without it the tee — the part Neovim needs — still
# happens, and only the printed line is skipped.

set -u

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"
cache="$state_dir/statusline.json"

input=$(cat)
[ -n "$input" ] || exit 0

# Write-then-rename, so a poll that lands mid-write reads the previous
# complete document rather than half of this one.
if mkdir -p "$state_dir" 2>/dev/null; then
  tmp="$cache.$$"
  if printf '%s' "$input" >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$cache" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  else
    rm -f "$tmp" 2>/dev/null
  fi
fi

command -v jq >/dev/null 2>&1 || exit 0

# Deliberately no `git` call: this runs on every render, and the branch is
# already in Neovim's statusline via gitsigns.
printf '%s' "$input" | jq -r '
  [ (.model.display_name // empty),
    (.workspace.current_dir // "" | split("/") | last | select(. != "")),
    ((.context_window.used_percentage // empty) | "ctx \(round)%"),
    ((.rate_limits.five_hour.used_percentage // empty) | "5h \(round)%"),
    ((.rate_limits.seven_day.used_percentage // empty) | "7d \(round)%")
  ] | join("  ")
' 2>/dev/null
