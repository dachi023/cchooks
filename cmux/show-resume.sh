#!/bin/bash
# Display saved Claude Code resume commands.
#
# Usage:
#   show-resume.sh          Show all saved sessions
#   show-resume.sh --cwd    Show resume command for current directory only

set -euo pipefail

resume_dir="$HOME/.claude/cmux-resume"

if [[ ! -d "$resume_dir" ]] || [[ -z "$(ls -A "$resume_dir" 2>/dev/null)" ]]; then
  echo "No saved sessions." >&2
  exit 0
fi

if [[ "${1:-}" == "--cwd" ]]; then
  project_key=$(printf '%s' "$PWD" | tr '/' '-')
  if [[ -f "$resume_dir/$project_key" ]]; then
    cat "$resume_dir/$project_key"
  else
    echo "No saved session for $PWD" >&2
  fi
  exit 0
fi

# Show all saved sessions with their project paths
for file in "$resume_dir"/*; do
  [[ -f "$file" ]] || continue
  key=$(basename "$file")
  path=$(printf '%s' "$key" | sed 's/^-/\//; s/-/\//g')
  cmd=$(cat "$file")
  mod=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$file" 2>/dev/null || stat -c '%y' "$file" 2>/dev/null | cut -d. -f1)
  printf '  %s\n    %s  (%s)\n' "$path" "$cmd" "$mod"
done
