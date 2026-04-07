#!/bin/bash
# pane-focus hook: refresh cmux sidebar with the focused surface's cached data.
#
# Updates both the context progress bar and the task status pill.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

focused_ref=$(get_focused_ref)
[[ -z "$focused_ref" ]] && exit 0

cache_key=$(surface_ref_to_key "$focused_ref")

# --- Context progress bar ---

context_file="$CONTEXT_CACHE_DIR/$cache_key"
if [[ -f "$context_file" ]]; then
  IFS='=' read -r _ context_pct < "$context_file"
  update_context_sidebar "${context_pct:-}"
else
  "$CMUX_BIN" clear-progress >/dev/null 2>&1 || true
fi

# --- Task status pill ---

task_file="$TASK_CACHE_DIR/${cache_key}.json"
if [[ -f "$task_file" ]]; then
  summarize_tasks "$task_file"
  update_task_sidebar
else
  "$CMUX_BIN" clear-status "tasks" >/dev/null 2>&1 || true
fi
