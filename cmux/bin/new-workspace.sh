#!/usr/bin/env bash
# Create a new cmux workspace with a 7:3 left-right split layout.
#
# Usage:
#   new-workspace.sh [--cwd <path>] [--name <name>]
#
# The left pane (~70%) is focused after creation.

set -euo pipefail

CMUX="/Applications/cmux.app/Contents/Resources/bin/cmux"

cwd=""
name=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd)  cwd="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    *)      echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Create workspace (--id-format must precede the subcommand)
ws_args=(--id-format refs new-workspace)
[[ -n "$cwd" ]] && ws_args+=(--cwd "$cwd")

ws_id=$("$CMUX" "${ws_args[@]}" 2>&1 | grep -oE 'workspace:[0-9]+' | head -1)

if [[ -z "$ws_id" ]]; then
  echo "Failed to create workspace" >&2
  exit 1
fi

# Rename if requested
if [[ -n "$name" ]]; then
  "$CMUX" rename-workspace --workspace "$ws_id" "$name" >/dev/null 2>&1 || true
fi

# Select workspace — resize only works on the visible workspace
"$CMUX" select-workspace --workspace "$ws_id" >/dev/null

# Add right pane via new-pane (more direct than new-split)
"$CMUX" new-pane --direction right --workspace "$ws_id" >/dev/null

# Get left pane (first listed)
left_pane=$("$CMUX" --id-format refs list-panes --workspace "$ws_id" 2>&1 \
  | grep -oE 'pane:[0-9]+' | head -1)

# Resize left pane to ~70%.
# resize-pane has a small per-call cap, so we need many iterations.
for _ in $(seq 1 33); do
  "$CMUX" resize-pane --pane "$left_pane" --workspace "$ws_id" -R --amount 10 >/dev/null 2>&1 || true
done

# Focus the left pane
"$CMUX" focus-pane --pane "$left_pane" --workspace "$ws_id" >/dev/null 2>&1 || true

echo "Created workspace $ws_id with 7:3 layout"
