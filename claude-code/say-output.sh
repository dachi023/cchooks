#!/bin/bash
set -euo pipefail

input=$(cat)
[[ $(jq -r '.stop_hook_active' <<< "$input") == "true" ]] && exit 0

text=$(jq -r '.last_assistant_message // "No message"' <<< "$input")
text=${text:0:64}

say "$text" &
afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
