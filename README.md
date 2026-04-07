# cchooks

Custom hooks for Claude Code, with optional cmux integration.

## Install

```sh
./install.sh
```

`install.sh` resolves paths relative to itself, so it works wherever you keep this repo. It creates:

- `~/.claude/CLAUDE.md` → `claude/instructions.md` (global user instructions)
- `~/.config/cmux/cmux.json` → `cmux/cmux.json` (only if cmux is detected)

Hook registration in `~/.claude/settings.json` is left manual — see below.

## Structure

```
install.sh            # One-shot symlink setup

claude/               # Works with Claude Code alone (no cmux)
  instructions.md     # → ~/.claude/CLAUDE.md
  statusline.sh       # StatusLine hook → terminal status line
  say-output.sh       # Stop hook       → TTS + sound (macOS)

cmux/                 # Requires cmux
  cmux.json           # → ~/.config/cmux/cmux.json (command palette entries)
  lib.sh              # Shared bash helpers
  sidebar-task.sh     # CC PostToolUse hook  → cmux task pill
  sidebar-focus.sh    # cmux pane-focus hook → restore task pill from cache
  resume-save.sh      # CC Stop hook         → save "claude --resume ..."
  bin/                # Manually-invoked CLIs
    resume-show.sh    # List saved resume commands
    new-workspace.sh  # Create a 7:3 split workspace (to be retired; see cmux.json)
```

The split is intentional: install `claude/` alone and everything works without cmux. Install `cmux/` too and you get sidebar task pills and session-resume recovery tied to cmux restarts.

## Hooks setup

After `install.sh`, register hooks in `~/.claude/settings.json`. In the snippets below, replace `/path/to/cchooks` with the absolute path to this repo on your machine.

Note: `statusLine` is a top-level config (single command), not a hook event. `hooks` events use the `{ matcher, hooks: [...] }` group form.

### Without cmux

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/to/cchooks/claude/statusline.sh"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "bash /path/to/cchooks/claude/say-output.sh" }
        ]
      }
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

Replace the above with this fuller version (adds a `PostToolUse` matcher group and one extra `Stop` command):

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/to/cchooks/claude/statusline.sh"
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Task*",
        "hooks": [
          { "type": "command", "command": "bash /path/to/cchooks/cmux/sidebar-task.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "bash /path/to/cchooks/claude/say-output.sh" },
          { "type": "command", "command": "bash /path/to/cchooks/cmux/resume-save.sh" }
        ]
      }
    ]
  }
}
```

Then register `cmux/sidebar-focus.sh` as a pane-focus hook in cmux settings (needed to restore the task pill when switching panes).

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
  ├─→ cmux/sidebar-task.sh     → cmux task pill + per-surface cache
  └─→ cmux/resume-save.sh      → resume command to /dev/tty + persistent file

cmux (pane-focus event)
  └─→ cmux/sidebar-focus.sh    → restore task pill from cache for focused surface
```

### Session Resume

`cmux/resume-save.sh` runs as a Claude Code Stop hook. On every session stop it:

1. Echoes `claude --resume <session_id>` to the terminal (best-effort — visible in pane scrollback if cmux preserves it across restart)
2. Saves the resume command to `~/.claude/cmux-resume/<project_key>`

After a cmux restart, run `cmux/bin/resume-show.sh` to list saved sessions:

```
$ /path/to/cchooks/cmux/bin/resume-show.sh
  /Users/you/project
    claude --resume abc-123  (2026-04-03 17:46)

$ /path/to/cchooks/cmux/bin/resume-show.sh --cwd
claude --resume abc-123
```

### Cache

- `/tmp/cmux-claude-tasks/<surface_key>.json` — task state (JSON)
- `~/.claude/cmux-resume/<project_key>` — resume commands (persistent)

The task cache is restored by `cmux/sidebar-focus.sh` on focus change.
