---
name: review
description: Pushes the branch, opens a PR via `gh` with diff + slices + QA summary linked, drafts the PR if any QA flow failed. Hand-off to a human reviewer — does not merge. Use as the final phase before human review, when invoked as Phase 6 of the clanker pipeline, or when the user types /review.
---

# review — Phase 6 (HITL handoff): Open the PR

## Purpose

This skill does not approve anything. It packages the branch — pushed, with a PR body that links the PRD, slices, and QA report — and hands it to a human to merge. Review is the HITL edge of the pipeline.

> "An agent cannot be held accountable." Issues get delegated to agents but assigned to humans.

## Core principles

- **Package, don't merge.** A human merges. Always.
- **Honest title.** Use the dominant change type as the conventional-commit type. Don't dress up a refactor as a feat.
- **Draft if QA red.** Any failing QA flow → open the PR as `--draft`.
- **Stop if state is unsafe.** If the branch is `main`, the working tree is dirty, or `gh` is not authed — stop and surface, do not paper over.

## Inputs

- Optional extra notes the human wants in the PR body. Empty → "—".

## Preconditions (check, do not bypass)

- `git status --porcelain` is empty.
- `git branch --show-current` is not `main` or `master`.
- `gh auth status` succeeds.
- `git log --oneline main..HEAD` has at least one commit.

If any precondition fails: STOP and return `BLOCKED: <which one>`. Do not commit, stash, or push on the user's behalf to force a fix.

## Workflow

### Step 1 — Inspect state

- `git branch --show-current` → record as `<branch>`.
- `git log --oneline main..HEAD` → record commit subjects.
- `git diff --stat main...HEAD` → record files changed + insertions/deletions.
- Find latest `qa/*.md` matching the branch slug — record its summary.

### Step 2 — Push

`git push -u origin <branch>`. If the branch already tracks a remote, plain `git push`. If push is rejected because remote has diverged: STOP and return `BLOCKED: remote diverged — needs human intervention`. Never `--force`.

### Step 3 — Draft the PR body

Use the template in `assets/pr-body-template.md`. Substitute placeholders from Step 1's recorded state.

### Step 4 — Open the PR

Title: `<type>(<scope>): <summary>` — pick the dominant change type from the commit log (`feat`, `fix`, `refactor`). Example: `feat(booking): multi-step booking wizard`.

Run via `gh pr create` with the body passed through a HEREDOC. Pass `--draft` if any QA flow failed:

```bash
gh pr create \
  --title "<title>" \
  --draft \   # only if QA had a FAIL
  --body "$(cat <<'EOF'
<the body from Step 3>
EOF
)"
```

### Step 5 — Verify and return

- `gh pr view --json url,isDraft` to confirm.
- Print the PR URL and posture.

## Hard rules

- CRITICAL: **Do not merge.** Not `gh pr merge`, not `git merge`, not `git push origin main`.
- CRITICAL: **Do not force-push.** Not `--force`, not `--force-with-lease` from this skill.
- CRITICAL: **Do not push to `main`.**
- IMPORTANT: Draft posture is mandatory when QA has any FAIL. Reviewers will be paged less if the PR is honest about its state.
- IMPORTANT: If `gh` is unavailable, print the PR body to stdout and tell the user to create the PR manually. Do not silently fall back.

## Output

```
Branch: <name>
Pushed: yes
PR: <url>
Posture: ready | draft
QA: happy PASS|FAIL · negatives PASS|FAIL · PASS|FAIL
Commits: <N>  (slices: <N1>, refactors: <N2>)
```

That is the entire hand-off. The pipeline is done.
