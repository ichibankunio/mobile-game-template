#!/usr/bin/env bash
set -euo pipefail

ISSUE_NUMBER="${1:-}"
if [[ -z "${ISSUE_NUMBER}" ]]; then
  echo "usage: $0 <issue-number>" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh command is required." >&2
  exit 1
fi
if ! command -v codex >/dev/null 2>&1; then
  echo "codex command is required." >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "git command is required." >&2
  exit 1
fi

REPO="${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
BASE_BRANCH="${BASE_BRANCH:-main}"
BRANCH="codex/issue-${ISSUE_NUMBER}"
TMP_DIR="$(mktemp -d)"
PROMPT_FILE="${TMP_DIR}/prompt.txt"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

if [[ -n "$(git status --porcelain)" ]]; then
  echo "worktree is dirty. commit/stash changes before running." >&2
  exit 1
fi

if gh pr list --repo "${REPO}" --state open --head "${BRANCH}" --json number --jq 'length > 0' | grep -q true; then
  echo "open PR already exists for ${BRANCH}; skipping."
  exit 0
fi

RAW_TITLE="$(gh issue view "${ISSUE_NUMBER}" --repo "${REPO}" --json title --jq .title)"
RAW_BODY="$(gh issue view "${ISSUE_NUMBER}" --repo "${REPO}" --json body --jq .body)"
ISSUE_URL="$(gh issue view "${ISSUE_NUMBER}" --repo "${REPO}" --json url --jq .url)"

git fetch origin "${BASE_BRANCH}"
git checkout "${BASE_BRANCH}"
git pull --ff-only origin "${BASE_BRANCH}"
git checkout -B "${BRANCH}"

cat > "${PROMPT_FILE}" <<EOF
You are working in repository ${REPO}.
Implement GitHub Issue #${ISSUE_NUMBER}.

Issue title:
${RAW_TITLE}

Issue body:
${RAW_BODY}

Requirements:
- Implement only what is necessary to satisfy this issue.
- Do not commit or push directly.
- Run relevant checks (at minimum: go test ./... and make wasm if applicable).
- Keep changes small and reviewable.
- Update docs if behavior or usage changed.
EOF

codex exec --full-auto -C "$(pwd)" - < "${PROMPT_FILE}"

if [[ -z "$(git status --porcelain)" ]]; then
  gh issue comment "${ISSUE_NUMBER}" --repo "${REPO}" --body "Codex ran for this issue but produced no file changes."
  git checkout "${BASE_BRANCH}"
  git branch -D "${BRANCH}"
  exit 0
fi

git add -A
git commit -m "feat: resolve issue #${ISSUE_NUMBER}"
git push -u origin "${BRANCH}"

PR_BODY="$(cat <<EOF
Automated implementation for #${ISSUE_NUMBER}.

Source issue:
- ${ISSUE_URL}

Closes #${ISSUE_NUMBER}
EOF
)"

PR_URL="$(gh pr create \
  --repo "${REPO}" \
  --base "${BASE_BRANCH}" \
  --head "${BRANCH}" \
  --title "Codex: resolve issue #${ISSUE_NUMBER}" \
  --body "${PR_BODY}")"

gh issue comment "${ISSUE_NUMBER}" --repo "${REPO}" --body "Codex started and opened a PR: ${PR_URL}"
echo "created PR: ${PR_URL}"
