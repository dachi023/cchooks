#!/bin/bash
# pane-focus hook: refresh cmux sidebar with the focused surface's cached data.
#
# Restores the task status pill from per-surface cache.

set -euo pipefail
source "$(dirname "$0")/lib.sh"

focused_ref=$(get_focused_ref)
[[ -z "$focused_ref" ]] && exit 0

cache_key=$(surface_ref_to_key "$focused_ref")

# --- Task status pill ---

task_file="$TASK_CACHE_DIR/${cache_key}.json"
if [[ -f "$task_file" ]]; then
  summarize_tasks "$task_file"
  update_task_sidebar
else
  "$CMUX_BIN" clear-status "tasks" >/dev/null 2>&1 || true
fi
