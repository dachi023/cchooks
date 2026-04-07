#!/bin/bash
# StatusLine hook: update cmux sidebar with context window progress bar.
#
# Reads Claude Code status JSON from stdin.
# Caches context_pct per surface so on-focus.sh can restore it.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

cmux_available || exit 0

json=$(cat)

{
  IFS= read -r -d '' context_pct
} < <(jq -j '
  (.context_window.used_percentage // ""), "\u0000"
' <<< "$json") || true

# --- Identify caller surface --------------------------------------------------

mkdir -p "$CONTEXT_CACHE_DIR"

read -r caller_ref focused_ref <<< "$(get_caller_and_focused_refs)"
[[ -n "$caller_ref" ]] || exit 0

cache_key=$(surface_ref_to_key "$caller_ref")

# Only write cache if numeric and changed.
if [[ "$context_pct" =~ ^[0-9]+\.?[0-9]*$ ]]; then
  cache_file="$CONTEXT_CACHE_DIR/$cache_key"
  new_line="context_pct=$context_pct"
  if [[ ! -f "$cache_file" ]] || [[ "$(<"$cache_file")" != "$new_line" ]]; then
    printf '%s\n' "$new_line" > "$cache_file"
  fi
fi

# --- Update progress bar (only if focused) ------------------------------------

if [[ "$caller_ref" == "$focused_ref" ]]; then
  update_context_sidebar "$context_pct"
fi
