---
name: qa
description: Drives the implemented feature through one happy + two negative paths using the repo's documented QA mode, captures evidence, writes qa/<slug>.md with PASS/FAIL summary and PR posture (ready or draft). Use after slices are implemented, when invoked as Phase 5 of the clanker pipeline, or when the user types /qa.
---

# qa — Phase 5 (AFK): Agentic QA

## Purpose

Automated tests prove pieces of the code work. QA proves the implemented feature works through the repository's documented user-facing or integration path. This skill runs the documented QA mode, captures evidence where possible, and writes a markdown report a human can scan in two minutes.

## Core principles

- **Real target.** Use the repo's documented QA mode: browser e2e, API smoke, CLI smoke, service integration test, or manual-disabled mode.
- **Stable interactions.** Prefer accessible selectors for UI, public API contracts for services, and documented CLI flags/fixtures for command-line tools.
- **One happy + two negatives.** Pick the two most likely failure modes (bad input, network/server failure, declined action, etc.). Resist the urge to test everything — that's what lower-level tests are for.
- **Report what happened, do not patch.** If QA fails, the report says so. Do not silently fix product code from this skill.

## Inputs

- A feature slug. If empty, derive from `git branch --show-current`.
- The QA mode, target command, and entry point from `AGENTS.md`, `docs/testing.md`, and `docs/quality-pipeline.md`.

## Workflow

### Step 1 — Identify the QA mode

Read the project docs and select one mode:

- **Browser e2e** — start the documented local app/service command, wait for the documented URL, and drive the feature in a browser.
- **API smoke** — start the documented service command, wait for the health endpoint, and exercise public endpoints with test data.
- **CLI smoke** — run the documented CLI command against fixtures or a temp workspace.
- **Library/package** — run documented integration examples or smoke tests that exercise the public API.
- **QA disabled** — if docs explicitly say no e2e/smoke mode exists, write a report with `PR posture: draft`, explain the missing QA loop, and skip test generation.

If the required command, URL, health check, or fixture is missing, STOP and return a blocked report that names the missing setup detail.

### Step 2 — Pick three flows

Read the PRD (`docs/prd-*.md`) and slice tickets (`docs/tickets/`) to ground yourself. Choose:

- **1× happy path** — completes the feature with valid data.
- **2× negative paths** — pick the two most likely to fail in production, anchored to the PRD's "Edge cases" or "Error states" section if present.

Example for a form submission feature: happy (valid submit) + negative (invalid email format) + negative (network timeout on POST). State the three chosen flows in the report before writing tests.

### Step 3 — Write or run QA checks

For browser e2e projects, write the test in the documented e2e location using the repository's naming convention. Each test:

- Navigates to the feature.
- Drives the UI step by step using stable selectors.
- Screenshots every meaningful state into `qa/screenshots/` when the test tool supports screenshots.
- Asserts an observable outcome (URL, visible text, error message).

For API, CLI, service, or library projects, create the smallest repo-conventional smoke/integration check if the project has a place for such checks; otherwise run the documented command manually and record exact commands, inputs, outputs, and evidence in the report.

### Step 4 — Run them

Run the documented e2e/smoke command, narrowed to the QA check when the tool supports it. Capture pass/fail per flow. Do not retry to "smooth out" a flake — flaky tests are a finding.

### Step 5 — Write the report

Write `qa/<slug>.md`:

```markdown
# QA Report: <Feature>

Run: <ISO date> · Branch: <branch> · Commit: <short sha>
Mode: browser e2e | API smoke | CLI smoke | library smoke | QA disabled
Target: <URL, command, fixture, or "none">

## Flow 1 — Happy path: <name>
- Steps:
  1. …
- Expected: …
- Actual: …
- Result: PASS | FAIL
- Screenshots:
  - qa/screenshots/<slug>-happy-1.png
  - <or command output / response excerpt / log path>

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
   git add qa/<slug>.md "qa/screenshots/<slug>-"*.png
   git add <exact QA test/check path you created>
   ```
   Skip the second command if no QA test/check file was created. Globs that match nothing are fine; `git add` silently no-ops on misses.
2. Verify the staged set: `git diff --cached --name-only`. If any staged path is **not** under `qa/` and is not the QA test/check file you created → run `git reset` and STOP with `BLOCKED: qa staged unexpected paths: <list>`.
3. If `git diff --cached --quiet` (nothing staged — e.g. no screenshots produced) → skip the commit silently. Record `Committed: none`.
4. Otherwise commit: `git commit -m "test(<slug>): qa report and screenshots"`. Record `Committed: <git rev-parse --short HEAD>`.
5. If a pre-commit hook fails, surface `BLOCKED: pre-commit hook failed during qa commit — <hook output>`. **Never** `--no-verify`.

## Hard rules

- CRITICAL: **Do not change product code from this skill.** If you spot a bug, write it in "Reviewer should look at" — do not patch.
- CRITICAL: **QA MAY commit its own artifacts** (`qa/**` plus the exact QA test/check file it created). **MUST NOT** stage anything else. Use an explicit `git add` allowlist; never `-A` / `.`. The Step 6 staged-paths check is the enforcement gate — if it trips, abort.
- CRITICAL: **Do not delete or skip a failing test** to make the report green. A failing flow is the whole point of running this.
- IMPORTANT: Use stable, user-facing selectors/contracts/fixtures.
- IMPORTANT: Mark the run as **DRAFT** in the summary if any flow failed — the orchestrator will open the PR as a draft.
- Do not navigate the public internet from a QA test. Stay on `localhost`.

## Output

```
Report: qa/<slug>.md
Happy: PASS | FAIL
Negatives: PASS | FAIL · PASS | FAIL
Tests/checks written: <path> | none
Evidence: qa/screenshots/<slug>-*.png (<count>) | command output | response excerpts | logs | none
Committed: <short sha> | none
PR posture: ready | draft
```

Phase 6 (`review`) reads this report to attach to the PR.
