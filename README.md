# mobile-game-template

`flib` のシーンベース構成で、スマホ向け縦持ち 16:9 (720x1280) の最小テンプレートです。

## Included

- 画像ロード: `game/assets/images`
- フォントロード: `game/assets/fonts`
- `text/v2` の `GoTextFace` で `Hello World` 表示
- SE/BGMロード: `game/assets/se`, `game/assets/bgm`
- JSONロード: `game/assets/data`

## Run

```bash
go run .
```

## Build all

```bash
go build ./...
```

## WASM (GitHub Pages)

```bash
make wasm
make serve
```

- `make wasm` builds `docs/game.wasm` and copies `web/index.html`, `web/wasm_exec.js`.
- `make serve` starts local preview at `http://localhost:8080`.

## GitHub Actions

- `.github/workflows/pages.yml`:
  - push to `main` -> build WASM -> deploy GitHub Pages
- `.github/workflows/pr-preview.yml`:
  - PR open/update -> deploy Pages preview -> comment preview URL to PR

## Local Codex Worker (Issue -> PR)

This template uses a local always-on machine (e.g. home Mac mini) to process issues with Codex CLI.
GitHub Actions is not used for Codex execution.

### Prerequisites

```bash
gh auth login
codex login
```

### Run once for a single issue

```bash
./scripts/run_issue.sh 123
```

### Run as polling worker

```bash
LABEL=autocodex POLL_INTERVAL=60 ./scripts/issue_worker.sh
```

- Only open issues with label `autocodex` are picked up.
- Worker creates `codex/issue-<number>` branch, commits, pushes, and opens a PR.
- Worker state/logs are saved under `.codex-worker/`.
- Before scanning each next issue, worker guarantees checkout/update of `main` (or waits if worktree is dirty).

### macOS launchd (optional)

1. Copy `scripts/launchd/com.ichibankunio.mobile-game-template.issue-worker.plist`
   to `~/Library/LaunchAgents/`
2. Replace `__REPO_PATH__` with your local repository path
3. Load service:

```bash
launchctl unload ~/Library/LaunchAgents/com.ichibankunio.mobile-game-template.issue-worker.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.ichibankunio.mobile-game-template.issue-worker.plist
```

## Mobile binding

```bash
ebitenmobile bind -v -target ios -o ./ios/Mobile.xcframework ./mobile
# or
# ebitenmobile bind -v -target android -javapkg com.example.mobilegametemplate -o ./android/mobile-game-template.aar ./mobile
```
