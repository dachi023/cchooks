# cchooks

Custom hooks for Claude Code, with optional cmux integration.

## Install

```sh
git clone https://github.com/dachi023/cchooks ~/.claude/scripts
cd ~/.claude/scripts
./install.sh
```

The clone location is up to you — `install.sh` resolves paths relative to itself. Subsequent examples assume `~/.claude/scripts`; adjust hook paths if you clone elsewhere.

`install.sh` creates:

- `~/.claude/CLAUDE.md` → `claude/instructions.md` (global user instructions)
- `~/.config/cmux/cmux.json` → `cmux/cmux.json` (only if cmux is detected)

Hook registration in `~/.claude/settings.json` is left manual — see below.

## Structure

```
scripts/
  install.sh            # One-shot symlink setup

  claude/               # Works with Claude Code alone (no cmux)
    instructions.md     # → ~/.claude/CLAUDE.md
    statusline.sh       # StatusLine hook → terminal status line
    say-output.sh       # Stop hook       → TTS + sound (macOS)

  cmux/                 # Requires cmux
    cmux.json           # → ~/.config/cmux/cmux.json (command palette entries)
    lib.sh              # Shared bash helpers
    sidebar-context.sh  # CC StatusLine hook   → cmux context progress bar
    sidebar-task.sh     # CC PostToolUse hook  → cmux task pill
    sidebar-focus.sh    # cmux pane-focus hook → restore sidebar from cache
    resume-save.sh      # CC Stop hook         → save "claude --resume ..."
    bin/                # Manually-invoked CLIs
      resume-show.sh    # List saved resume commands
      new-workspace.sh  # Create a 7:3 split workspace (to be retired; see cmux.json)
```

The split is intentional: install `claude/` alone and everything works without cmux. Install `cmux/` too and you get sidebar progress bars, task pills, and session-resume recovery tied to cmux restarts.

## Hooks setup

After `install.sh`, register hooks in `~/.claude/settings.json`.

### Without cmux

```json
{
  "hooks": {
    "StatusLine": [
      { "type": "command", "command": "bash ~/.claude/scripts/claude/statusline.sh" }
    ],
    "Stop": [
      { "type": "command", "command": "bash ~/.claude/scripts/claude/say-output.sh" }
    ]
  }
}
```

`statusline.sh` produces a line like:

```
Opus │ 5h:⣿⣿⣿⣿⡆⣀⣀⣀ 55%(20:00) │ 7d:⣿⣿⡆⣀⣀⣀⣀⣀ 30% │ claude --resume abc-123
```

`say-output.sh` uses macOS `say` + `afplay` for completion audio.

### With cmux

Stack these on top of the above:

```json
{
  "hooks": {
    "StatusLine": [
      { "type": "command", "command": "bash ~/.claude/scripts/claude/statusline.sh" },
      { "type": "command", "command": "bash ~/.claude/scripts/cmux/sidebar-context.sh" }
    ],
    "PostToolUse": [
      { "type": "command", "command": "bash ~/.claude/scripts/cmux/sidebar-task.sh" }
    ],
    "Stop": [
      { "type": "command", "command": "bash ~/.claude/scripts/claude/say-output.sh" },
      { "type": "command", "command": "bash ~/.claude/scripts/cmux/resume-save.sh" }
    ]
  }
}
```

Then register `cmux/sidebar-focus.sh` as a pane-focus hook in cmux settings (needed to restore the sidebar when switching panes).

## Custom Commands (cmux.json)

`cmux/cmux.json` defines entries for the cmux command palette (Cmd+P). `install.sh` symlinks it to `~/.config/cmux/cmux.json` automatically. cmux live-reloads the file on save — no restart needed.

Current entries:

- `New Workspace (7:3)` — creates a new workspace with a 7:3 left-right split. Will replace `cmux/bin/new-workspace.sh` once [manaflow-ai/cmux#2429](https://github.com/manaflow-ai/cmux/issues/2429) is fixed (currently the `split` ratio is ignored and falls back to 50:50).

## Dependencies

- `jq` — required by most scripts
- `say`, `afplay` — `claude/say-output.sh` only (macOS built-in)
- `cmux` — `cmux/` only. Scripts gracefully no-op if cmux is absent

## How It Works

### Data Flow

```
Claude Code (JSON via stdin)
  ├─→ claude/statusline.sh     → stdout (terminal status line)
  ├─→ claude/say-output.sh     → macOS TTS + completion sound
  ├─→ cmux/sidebar-context.sh  → cmux progress bar + per-surface cache
  ├─→ cmux/sidebar-task.sh     → cmux task pill + per-surface cache
  └─→ cmux/resume-save.sh      → resume command to /dev/tty + persistent file

cmux (pane-focus event)
  └─→ cmux/sidebar-focus.sh    → restore sidebar from cache for focused surface
```

### Session Resume

`cmux/resume-save.sh` runs as a Claude Code Stop hook. On every session stop it:

1. Echoes `claude --resume <session_id>` to the terminal (best-effort — visible in pane scrollback if cmux preserves it across restart)
2. Saves the resume command to `~/.claude/cmux-resume/<project_key>`

After a cmux restart, run `cmux/bin/resume-show.sh` to list saved sessions:

```
$ ~/.claude/scripts/cmux/bin/resume-show.sh
  /Users/you/project
    claude --resume abc-123  (2026-04-03 17:46)

$ ~/.claude/scripts/cmux/bin/resume-show.sh --cwd
claude --resume abc-123
```

### Cache

- `/tmp/cmux-claude-status/<surface_key>` — context usage (`context_pct=42.5`)
- `/tmp/cmux-claude-tasks/<surface_key>.json` — task state (JSON)
- `~/.claude/cmux-resume/<project_key>` — resume commands (persistent)

Per-pane caches are restored by `cmux/sidebar-focus.sh` on focus change.
