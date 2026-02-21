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
RESPONSE_FILE="${TMP_DIR}/response.txt"

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
PR_TITLE="${RAW_TITLE}"

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
- Do not checkout or switch to another branch. Stay on ${BRANCH}.
- Never modify any file or directory outside this repository.
- Only modify files under: game/, mobile/, web/, docs/
- Additionally, only these root files may be modified: go.mod, go.sum, main.go, README.md, .gitignore
- Do not modify any other paths/files.
- Be extremely careful with shell commands executed on this PC.
- Never run destructive commands (e.g. rm -rf, git reset --hard, git clean -fd, force-push, or anything that can delete/overwrite data).
- Run relevant checks (at minimum: go test ./... and make wasm if applicable).
- Keep changes small and reviewable.
- Update docs if behavior or usage changed.
- In your final response, include a concise implementation summary for the PR comment.
- If you need reviewer input before further changes, add a line:
  QUESTION_FOR_REVIEWER: <your question>
EOF

codex exec --full-auto -C "$(pwd)" -o "${RESPONSE_FILE}" - < "${PROMPT_FILE}"

# Guard: ensure commit always happens on the issue branch.
if [[ "$(git branch --show-current)" != "${BRANCH}" ]]; then
  if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git checkout "${BRANCH}"
  else
    git checkout -b "${BRANCH}" "origin/${BRANCH}" 2>/dev/null || git checkout -B "${BRANCH}"
  fi
fi

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
  --title "${PR_TITLE}" \
  --body "${PR_BODY}")"

PR_NUMBER="$(printf '%s\n' "${PR_URL}" | sed -E 's#.*/pull/([0-9]+).*#\1#')"
RESPONSE_TEXT="$(cat "${RESPONSE_FILE}")"
if [[ -n "${RESPONSE_TEXT}" ]]; then
  gh pr comment "${PR_NUMBER}" --repo "${REPO}" --body $'Codex initial response:\n\n'"${RESPONSE_TEXT}"
fi

QUESTION_TEXT="$(sed -n 's/^QUESTION_FOR_REVIEWER:[[:space:]]*//p' "${RESPONSE_FILE}" | head -n 1)"
if [[ -n "${QUESTION_TEXT}" ]]; then
  gh pr comment "${PR_NUMBER}" --repo "${REPO}" --body $'Codex question for reviewer:\n\n'"${QUESTION_TEXT}"$'\n\nPlease answer in this PR with `@codex ...`.'
fi

gh issue comment "${ISSUE_NUMBER}" --repo "${REPO}" --body "Codex started and opened a PR: ${PR_URL}"
echo "created PR: ${PR_URL}"

# Return to base branch so the worker is ready for the next issue.
git checkout "${BASE_BRANCH}"
git pull --ff-only origin "${BASE_BRANCH}"
