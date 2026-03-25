#!/bin/bash
# PostToolUse hook: track TaskCreate/TaskUpdate and update cmux sidebar.
#
# Maintains per-surface task state in a JSON cache file.
# When the calling surface is focused, updates the sidebar task pill.

set -euo pipefail
source "$(dirname "$0")/../lib.sh"

cmux_available || exit 0

json=$(cat)

tool_name=$(jq -r '.tool_name // ""' <<< "$json")
case "$tool_name" in
  TaskCreate|TaskUpdate) ;;
  *) exit 0 ;;
esac

mkdir -p "$TASK_CACHE_DIR"

read -r caller_ref focused_ref <<< "$(get_caller_and_focused_refs)"
[[ -z "$caller_ref" ]] && exit 0

cache_key=$(surface_ref_to_key "$caller_ref")
state_file="$TASK_CACHE_DIR/${cache_key}.json"

[[ -f "$state_file" ]] || echo '{"tasks":{}}' > "$state_file"

# --- State mutation ---

if [[ "$tool_name" == "TaskCreate" ]]; then
  task_id="" subject=""
  {
    IFS= read -r -d '' task_id
    IFS= read -r -d '' subject
  } < <(jq -j '
    (.tool_response.task.id // ""), "\u0000",
    (.tool_input.subject // ""), "\u0000"
  ' <<< "$json") || true
  [[ -z "$task_id" ]] && exit 0

  jq_update_state "$state_file" \
    '.tasks[$id] = {"subject": $subj, "status": "pending"}' \
    --arg id "$task_id" --arg subj "$subject"

elif [[ "$tool_name" == "TaskUpdate" ]]; then
  task_id="" new_status="" new_subject=""
  {
    IFS= read -r -d '' task_id
    IFS= read -r -d '' new_status
    IFS= read -r -d '' new_subject
  } < <(jq -j '
    .tool_input |
    (.taskId // ""), "\u0000",
    (.status // ""), "\u0000",
    (.subject // ""), "\u0000"
  ' <<< "$json") || true
  [[ -z "$task_id" ]] && exit 0

  if [[ "$new_status" == "deleted" ]]; then
    jq_update_state "$state_file" 'del(.tasks[$id])' --arg id "$task_id"
  else
    filter=""
    args=( --arg id "$task_id" )
    if [[ -n "$new_status" ]]; then
      filter+='.tasks[$id].status = $st'
      args+=( --arg st "$new_status" )
    fi
    if [[ -n "$new_subject" ]]; then
      [[ -n "$filter" ]] && filter+=' | '
      filter+='.tasks[$id].subject = $subj'
      args+=( --arg subj "$new_subject" )
    fi
    [[ -n "$filter" ]] && jq_update_state "$state_file" "$filter" "${args[@]}"
  fi
fi

# --- Sidebar update (only if focused) ---

[[ "$caller_ref" != "$focused_ref" ]] && exit 0

summarize_tasks "$state_file"
update_task_sidebar
