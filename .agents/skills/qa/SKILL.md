---
name: qa
description: Drives the live dev server through one happy + two negative paths via Playwright, screenshots every state, writes qa/<slug>.md with PASS/FAIL summary and PR posture (ready or draft). Use after slices are implemented, when invoked as Phase 5 of the clanker pipeline, or when the user types /qa.
---

# qa — Phase 5 (AFK): Agentic QA

## Purpose

Unit tests prove the code works. Only a real browser session proves a user can finish the flow. This skill generates targeted Playwright tests, runs them against the live dev server, screenshots every state, and writes a markdown report a human can scan in two minutes.

## Core principles

- **Real browser, real server.** Drive `pnpm dev`, not a mocked harness.
- **Accessible selectors.** `getByRole`, `getByLabel`, `getByText`. Brittle CSS selectors mean the report ages badly.
- **One happy + two negatives.** Pick the two most likely failure modes (bad input, network/server failure, declined action, etc.). Resist the urge to test everything — that's what Vitest is for.
- **Report what happened, do not patch.** If QA fails, the report says so. Do not silently fix product code from this skill.

## Inputs

- A feature slug. If empty, derive from `git branch --show-current`.
- Identify the entry URL — default `http://localhost:5173/`. If the feature has a sub-route, navigate there.

## Workflow

### Step 1 — Boot the dev server

Check reachability: `curl -sf http://localhost:5173 -o /dev/null && echo up || echo down`.

- If `down`: start `pnpm dev` in the background. Poll the URL every 2s for up to 30s. If still down, STOP and return a blocked report.
- If `up`: continue.

### Step 2 — Pick three flows

Read the PRD (`docs/prd-*.md`) and slice tickets (`docs/tickets/`) to ground yourself. Choose:

- **1× happy path** — completes the feature with valid data.
- **2× negative paths** — pick the two most likely to fail in production, anchored to the PRD's "Edge cases" or "Error states" section if present.

Example for a form submission feature: happy (valid submit) + negative (invalid email format) + negative (network timeout on POST). State the three chosen flows in the report before writing tests.

### Step 3 — Write Playwright tests

Write `e2e/qa-<slug>.spec.ts`. Each test:

- Navigates to the feature.
- Drives the UI step by step using accessible selectors.
- Screenshots every meaningful state: `await page.screenshot({ path: 'qa/screenshots/<slug>-<flow>-<step>.png' })`.
- Asserts an observable outcome (URL, visible text, error message).

Use `test.describe('<feature> — QA', () => { ... })` to group.

### Step 4 — Run them

`pnpm test:e2e e2e/qa-<slug>.spec.ts`. Capture pass/fail per test. Do not retry to "smooth out" a flake — flaky tests are a finding.

### Step 5 — Write the report

Write `qa/<slug>.md`:

```markdown
# QA Report: <Feature>

Run: <ISO date> · Branch: <branch> · Commit: <short sha>
Server: http://localhost:5173

## Flow 1 — Happy path: <name>
- Steps:
  1. …
- Expected: …
- Actual: …
- Result: PASS | FAIL
- Screenshots:
  - qa/screenshots/<slug>-happy-1.png
  - qa/screenshots/<slug>-happy-2.png

## Flow 2 — Negative: <name>
- Steps: …
- Expected: …
- Actual: …
- Result: PASS | FAIL
- Screenshots: …

## Flow 3 — Negative: <name>
- (same shape)

## Summary
- Happy: PASS | FAIL
- Negatives: PASS | FAIL · PASS | FAIL
- Flake observed: yes/no — <note>
- Reviewer should look at: <one line>
```

### Step 6 — Commit QA artifacts (allowlist only)

The next phase (`review`) requires a clean working tree. QA owns its own outputs and must commit them before returning. Product code is **not** in QA's scope — the allowlist enforces this.

1. Stage with an explicit allowlist — never `git add -A` / `.`:
   ```
   git add qa/<slug>.md "qa/screenshots/<slug>-"*.png e2e/qa-<slug>.spec.ts
   ```
   Globs that match nothing are fine; `git add` silently no-ops on misses.
2. Verify the staged set: `git diff --cached --name-only`. If any staged path is **not** under `qa/` and not `e2e/qa-<slug>.spec.ts` → run `git reset` and STOP with `BLOCKED: qa staged unexpected paths: <list>`.
3. If `git diff --cached --quiet` (nothing staged — e.g. no screenshots produced) → skip the commit silently. Record `Committed: none`.
4. Otherwise commit: `git commit -m "test(<slug>): qa report and screenshots"`. Record `Committed: <git rev-parse --short HEAD>`.
5. If a pre-commit hook fails, surface `BLOCKED: pre-commit hook failed during qa commit — <hook output>`. **Never** `--no-verify`.

## Hard rules

- CRITICAL: **Do not change product code from this skill.** If you spot a bug, write it in "Reviewer should look at" — do not patch.
- CRITICAL: **QA MAY commit its own artifacts** (`qa/**`, `e2e/qa-<slug>.spec.ts`). **MUST NOT** stage anything else. Use an explicit `git add` allowlist; never `-A` / `.`. The Step 6 staged-paths check is the enforcement gate — if it trips, abort.
- CRITICAL: **Do not delete or skip a failing test** to make the report green. A failing flow is the whole point of running this.
- IMPORTANT: Accessible selectors only.
- IMPORTANT: Mark the run as **DRAFT** in the summary if any flow failed — the orchestrator will open the PR as a draft.
- Do not navigate the public internet from a QA test. Stay on `localhost`.

## Output

```
Report: qa/<slug>.md
Happy: PASS | FAIL
Negatives: PASS | FAIL · PASS | FAIL
Tests written: e2e/qa-<slug>.spec.ts
Screenshots: qa/screenshots/<slug>-*.png (<count>)
Committed: <short sha> | none
PR posture: ready | draft
```

Phase 6 (`review`) reads this report to attach to the PR.
