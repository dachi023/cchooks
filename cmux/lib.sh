#!/bin/bash
# Shared constants and helpers for cmux integration scripts.

CMUX_BIN="/Applications/cmux.app/Contents/Resources/bin/cmux"
TASK_CACHE_DIR="/tmp/cmux-claude-tasks"

# Sanitize a surface ref (e.g. "surface:34") into a safe filename key.
surface_ref_to_key() {
  printf '%s' "$1" | tr -cd 'A-Za-z0-9_-'
}

# Get the focused surface ref. Returns empty string on failure.
get_focused_ref() {
  "$CMUX_BIN" identify --no-caller 2>/dev/null | jq -r '.focused.surface_ref // ""'
}

# Get both caller and focused surface refs as "caller_ref focused_ref".
get_caller_and_focused_refs() {
  local identity
  identity=$("$CMUX_BIN" identify 2>/dev/null || echo "{}")
  local caller="" focused=""
  {
    IFS= read -r -d '' caller
    IFS= read -r -d '' focused
  } < <(jq -j '
    (.caller.surface_ref // ""), "\u0000",
    (.focused.surface_ref // ""), "\u0000"
  ' <<< "$identity") || true
  echo "$caller $focused"
}

# Returns true if cmux is available and socket is set.
cmux_available() {
  [[ -x "$CMUX_BIN" ]] && [[ -n "${CMUX_SOCKET_PATH:-}" ]]
}

# --- Task sidebar helpers ---

# Summarize task state from a JSON file.
# Sets variables: task_total, task_completed, task_current
# Usage: summarize_tasks /path/to/state.json
summarize_tasks() {
  local state_file="$1"
  eval "$(jq -r '
    .tasks | to_entries |
    {
      total: length,
      completed: [.[] | select(.value.status == "completed")] | length,
      current: ([.[] | select(.value.status == "in_progress")][0].value.subject // "")
    } |
    @sh "task_total=\(.total)",
    @sh "task_completed=\(.completed)",
    @sh "task_current=\(.current)"
  ' "$state_file" | tr '\n' ' ')"
}

# Update the cmux sidebar task status pill from summary variables.
# Expects task_total, task_completed, task_current to be set (via summarize_tasks).
update_task_sidebar() {
  if (( task_total == 0 )); then
    "$CMUX_BIN" clear-status "tasks" >/dev/null 2>&1 || true
    return
  fi

  local label color
  if [[ -n "$task_current" ]]; then
    label="[${task_completed}/${task_total}] ${task_current}"
  else
    label="[${task_completed}/${task_total}]"
  fi

  if (( task_completed == task_total )); then
    color="#4ade80"  # green — all done
  elif [[ -n "$task_current" ]]; then
    color="#60a5fa"  # blue — in progress
  else
    color="#8b8b8b"  # gray — pending
  fi

  "$CMUX_BIN" set-status "tasks" "$label" --icon "list" --color "$color" >/dev/null 2>&1
}

# Atomically update a JSON state file using a jq filter.
# Usage: jq_update_state /path/to/state.json '.tasks["1"].status = "done"' [--arg key val ...]
jq_update_state() {
  local file="$1"; shift
  local filter="$1"; shift
  jq "$@" "$filter" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}
