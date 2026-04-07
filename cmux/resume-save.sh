#!/bin/bash
# Claude Code Stop hook: save resume command for session recovery.
#
# On stop, saves `claude --resume <session_id>` to a persistent file
# and echoes it to the terminal (best-effort, for pane buffer survival).
#
# Saved files: ~/.claude/cmux-resume/<project_key>

set -euo pipefail

json=$(cat)

session_id=$(jq -r '.session_id // empty' <<< "$json")
[[ -z "$session_id" ]] && exit 0

cwd=$(jq -r '.cwd // empty' <<< "$json")
[[ -z "$cwd" ]] && exit 0

resume_cmd="claude --resume $session_id"

# --- Best-effort: echo to terminal buffer ---
# If cmux preserves the pane buffer across restart, this will be visible.
printf '\n%s\n' "$resume_cmd" > /dev/tty 2>/dev/null || true

# --- Reliable fallback: save to file ---
resume_dir="$HOME/.claude/cmux-resume"
mkdir -p "$resume_dir"

# Key: same encoding as Claude's project directory naming
project_key=$(printf '%s' "$cwd" | tr '/' '-')
printf '%s\n' "$resume_cmd" > "$resume_dir/$project_key"
