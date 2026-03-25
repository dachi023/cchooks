# cchooks

Custom hooks and status scripts for Claude Code.
cmux なしでも `claude-code/` 配下だけで使える。

## インストール

```sh
git clone https://github.com/dachi023/cchooks ~/.claude/scripts
```

## クイックスタート（cmux なし）

`claude-code/` 配下だけ使う場合。依存は jq のみ。

1. `~/.claude/settings.json` にフックを追加:
2. `~/.claude/settings.json` にフックを追加:

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

Claude Code を起動すると、ステータスラインにモデル名・レートリミット・セッション ID が表示される。

macOS なら say-output.sh も追加すると、応答完了時に音声読み上げ+効果音が鳴る:

```json
    "Stop": [
      {
        "type": "command",
        "command": "bash ~/.claude/scripts/claude-code/say-output.sh"
      }
    ]
```

```
Opus │ 5h:⣿⣿⣿⣿⡆⣀⣀⣀ 55%(20:00) │ 7d:⣿⣿⡆⣀⣀⣀⣀⣀ 30% │ claude --resume abc-123
```

cmux 連携も使いたい場合は下の「cmux 連携」セクションを参照。

## ディレクトリ構成

```
scripts/
  claude-code/          # Claude Code 単体で動くスクリプト
    statusline.sh       # StatusLine hook → stdout に状態表示
    say-output.sh       # Stop hook → 完了時に音声読み上げ + 効果音（macOS）
  cmux/                 # cmux 連携スクリプト（cmux がなければ何もしない）
    lib.sh              # 共有ライブラリ（定数・ヘルパー関数）
    on-focus.sh         # cmux pane-focus hook → サイドバー復元
    claude-code/        # Claude Code のフックから cmux を更新するもの
      context-tracker.sh  # StatusLine hook → コンテキスト使用率をサイドバーに表示
      task-tracker.sh     # PostToolUse hook → タスク進捗をサイドバーに表示
```

## 依存

- jq — 全スクリプト共通
- say, afplay — `say-output.sh` のみ（macOS 標準）
- cmux — `cmux/` 配下のみ。未インストールでも `exit 0` で安全にスキップ

## cmux 連携

statusline.sh に加えて、cmux サイドバーにコンテキスト使用率やタスク進捗を表示する。

`scripts/` ディレクトリ全体を `~/.claude/scripts/` に配置し、以下のフックを設定:

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

cmux 側の pane-focus フックに `on-focus.sh` を登録する（cmux の設定で行う）。

## 仕組み

### データフロー

```
Claude Code (JSON via stdin)
  │
  ├─→ statusline.sh ─→ stdout（ターミナル表示）
  │
  ├─→ context-tracker.sh ─→ cmux set-progress + キャッシュ書き込み
  │
  └─→ task-tracker.sh ─→ cmux set-status + タスク状態キャッシュ
                              │
cmux (pane-focus event)       │
  │                           │
  └─→ on-focus.sh ─→ キャッシュから復元して cmux サイドバー更新
```

### キャッシュ

- `/tmp/cmux-claude-status/<surface_key>` — コンテキスト使用率（`context_pct=42.5`）
- `/tmp/cmux-claude-tasks/<surface_key>.json` — タスク状態（JSON）

ペインごとにキャッシュされ、フォーカス切り替え時に `on-focus.sh` が復元する。
