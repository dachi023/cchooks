#!/bin/bash
# Claude Code status line → stdout (single line)
#
# Output: model │ rate limits │ session resume command
# Reads Claude Code status JSON from stdin.

set -euo pipefail

# --- Constants ----------------------------------------------------------------

readonly RED='\033[31m'
readonly YEL='\033[33m'
readonly GRN='\033[32m'
readonly DIM='\033[90m'
readonly RST='\033[0m'

# --- Helper functions ---------------------------------------------------------

# Round a float percentage to the nearest integer (shell builtin, no subprocess).
round_pct() { printf '%.0f' "$1"; }

# Return the ANSI color escape for a given usage percentage.
color_for_usage() {
  local u=$1
  if   (( u > 90 )); then printf '%b' "$RED"
  elif (( u > 70 )); then printf '%b' "$YEL"
  else                     printf '%b' "$GRN"
  fi
}

# Braille dot bar: 8 chars wide, gradient color per segment.
# ⠀⡀⡄⡆⡇⣇⣧⣷⣿ = 9 levels per char → 64 steps total resolution.
make_bar() {
  local usage=$1 width=8
  local braille=("⠀" "⡀" "⡄" "⡆" "⡇" "⣇" "⣧" "⣷" "⣿")
  local total_steps=$(( usage * width * 8 / 100 ))
  local bar="" color steps
  for ((c = 0; c < width; c++)); do
    local seg_pct=$(( c * 100 / width ))
    if   (( seg_pct >= 75 )); then color=$RED
    elif (( seg_pct >= 38 )); then color=$YEL
    else                           color=$GRN
    fi
    steps=$(( total_steps - c * 8 ))
    if   (( steps >= 8 )); then bar+="${color}⣿"
    elif (( steps >  0 )); then bar+="${color}${braille[$steps]}"
    else                        bar+="${DIM}⣀${RST}"
    fi
  done
  bar+=$RST
  printf '%b' "$bar"
}

# Append a rate-limit section to the global `parts` array.
# Usage: format_rate_limit <label> <pct> [<resets_at>]
format_rate_limit() {
  local label=$1 pct=$2 resets_at=${3:-}
  [[ -z "$pct" || "$pct" == "null" ]] && return

  local used bar color reset_part=""
  used=$(round_pct "$pct")
  bar=$(make_bar "$used")
  color=$(color_for_usage "$used")

  if [[ -n "$resets_at" && "$resets_at" != "null" ]]; then
    local reset_time
    # macOS: date -r <epoch>, Git Bash/MSYS: date -d @<epoch>
    reset_time=$(date -r "$resets_at" "+%H:%M" 2>/dev/null \
              || date -d "@$resets_at" "+%H:%M" 2>/dev/null \
              || echo "??:??")
    reset_part="(${reset_time})"
  fi

  parts+=("${label}:${bar} ${color}${used}%${RST}${reset_part}")
}

# --- Parse input JSON ---------------------------------------------------------

json=$(cat)

# NUL-delimited output + read: avoids eval and shell interpretation of data.
{
  IFS= read -r -d '' session_id
  IFS= read -r -d '' five_hour_pct
  IFS= read -r -d '' five_hour_resets
  IFS= read -r -d '' seven_day_pct
  IFS= read -r -d '' model
} < <(jq -j '
  (.session_id            // "unknown"), "\u0000",
  (.rate_limits.five_hour.used_percentage // ""), "\u0000",
  (.rate_limits.five_hour.resets_at       // ""), "\u0000",
  (.rate_limits.seven_day.used_percentage // ""), "\u0000",
  (.model.display_name    // "unknown"), "\u0000"
' <<< "$json") || true

# --- Build stdout status line -------------------------------------------------

parts=("$model")

format_rate_limit "5h" "$five_hour_pct" "$five_hour_resets"
format_rate_limit "7d" "$seven_day_pct"

parts+=("claude --resume $session_id")

div="${DIM}│${RST}"
output=""
for i in "${!parts[@]}"; do
  (( i > 0 )) && output+=" $div "
  output+="${parts[$i]}"
done
printf '%b\n' "$output"
