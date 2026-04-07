#!/usr/bin/env bash
# Install cchooks: symlink config files into place.
#
# Creates:
#   ~/.claude/CLAUDE.md          -> claude/instructions.md
#   ~/.config/cmux/cmux.json     -> cmux/cmux.json (only if cmux is installed)
#
# Hook registration in ~/.claude/settings.json is left to the user
# — see README.md for the snippets to paste.

set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)

# Create a symlink, but refuse to clobber a real file.
# Usage: link_safe <source> <target>
link_safe() {
  local source=$1 target=$2
  if [[ -L "$target" ]]; then
    ln -sfn "$source" "$target"
    echo "relinked: $target -> $source"
  elif [[ ! -e "$target" ]]; then
    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
    echo "linked:   $target -> $source"
  else
    echo "skip:     $target already exists and is not a symlink" >&2
    echo "          move it aside first if you want to replace it" >&2
    return 1
  fi
}

# --- claude/instructions.md -> ~/.claude/CLAUDE.md ---
link_safe "$script_dir/claude/instructions.md" "$HOME/.claude/CLAUDE.md" || true

# --- cmux/cmux.json -> ~/.config/cmux/cmux.json (only if cmux is around) ---
if command -v cmux >/dev/null 2>&1 \
  || [[ -x /Applications/cmux.app/Contents/Resources/bin/cmux ]]; then
  link_safe "$script_dir/cmux/cmux.json" "$HOME/.config/cmux/cmux.json" || true
else
  echo "skip:     cmux not detected; not linking cmux.json"
fi

cat <<'EOF'

---
Next steps:
  1. Register hooks in ~/.claude/settings.json (see README.md "Hooks setup")
  2. If using cmux, register cmux/sidebar-focus.sh as a pane-focus hook
     in cmux settings
EOF
