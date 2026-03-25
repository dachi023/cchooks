# cchooks

Custom hooks and status scripts for Claude Code.

## Install

```sh
git clone https://github.com/dachi023/cchooks ~/.claude/scripts
```

## Quick Start (without cmux)

Only requires jq. Add hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "StatusLine": [
      {
        "type": "command",
        "command": "bash ~/.claude/scripts/claude-code/statusline.sh"
      }
    ]
  }
}
```

This displays model name, rate limits, and session ID in the status line:

```
Opus │ 5h:⣿⣿⣿⣿⡆⣀⣀⣀ 55%(20:00) │ 7d:⣿⣿⡆⣀⣀⣀⣀⣀ 30% │ claude --resume abc-123
```

On macOS, you can also add say-output.sh for text-to-speech and sound on completion:

```json
    "Stop": [
      {
        "type": "command",
        "command": "bash ~/.claude/scripts/claude-code/say-output.sh"
      }
    ]
```

For cmux sidebar integration, see the "cmux Integration" section below.

## Directory Structure

```
scripts/
  claude-code/            # Standalone Claude Code scripts
    statusline.sh         # StatusLine hook → stdout status display
    say-output.sh         # Stop hook → text-to-speech + sound (macOS)
  cmux/                   # cmux integration (no-op if cmux is unavailable)
    lib.sh                # Shared library (constants & helpers)
    on-focus.sh           # cmux pane-focus hook → restore sidebar from cache
    claude-code/          # Claude Code hooks that update cmux sidebar
      context-tracker.sh  # StatusLine hook → context usage in sidebar
      task-tracker.sh     # PostToolUse hook → task progress in sidebar
```

## Dependencies

- jq — required by all scripts
- say, afplay — say-output.sh only (macOS built-in)
- cmux — `cmux/` only. Gracefully exits if not installed

## cmux Integration

Displays context window usage and task progress in the cmux sidebar.

Add these hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "StatusLine": [
      {
        "type": "command",
        "command": "bash ~/.claude/scripts/claude-code/statusline.sh"
      },
      {
        "type": "command",
        "command": "bash ~/.claude/scripts/cmux/claude-code/context-tracker.sh"
      }
    ],
    "PostToolUse": [
      {
        "type": "command",
        "command": "bash ~/.claude/scripts/cmux/claude-code/task-tracker.sh"
      }
    ]
  }
}
```

Register `on-focus.sh` as a pane-focus hook in cmux settings.

## How It Works

### Data Flow

```
Claude Code (JSON via stdin)
  ├─→ statusline.sh        ─→ stdout (terminal display)
  ├─→ context-tracker.sh   ─→ cmux set-progress + cache write
  └─→ task-tracker.sh      ─→ cmux set-status + task state cache

cmux (pane-focus event)
  └─→ on-focus.sh          ─→ restore sidebar from cache
```

### Cache

- `/tmp/cmux-claude-status/<surface_key>` — context usage (`context_pct=42.5`)
- `/tmp/cmux-claude-tasks/<surface_key>.json` — task state (JSON)

Cached per pane. `on-focus.sh` restores the sidebar when switching focus.
