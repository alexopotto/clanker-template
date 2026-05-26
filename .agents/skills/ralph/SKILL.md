---
name: ralph
description: TDD loop on one ticket — red → green → refactor → backpressure → commit → tick the box, repeated until every checkbox is checked. One iteration per commit. Use to implement a vertical slice from docs/tickets/, when invoked as Phase 3 of the clanker pipeline, or when the user types /ralph.
---

# ralph — Phase 3 (AFK): TDD Loop Per Slice

## Purpose

Ship one vertical slice by walking its checklist with strict red-green-refactor. Tests are the agent's permission slip to commit. Backpressure (tests, types, lint) keeps the loop honest.

## Core principles

- **One box per iteration.** Do not bundle tasks.
- **Tests first, always.** Red before green. The failing test must fail for the *right reason* before you write production code.
- **Tests are inviolate.** A failing test means the implementation is wrong, not the test.
- **Refactor only within scope.** Cleanup that touches files outside the slice belongs to `simplify` (Phase 4).
- **Commit per iteration.** One small green commit per box ticked.

## Inputs

- A path to one `docs/tickets/NN-*.md`. If empty, pick the lowest-numbered ticket that still has unchecked `- [ ]` lines.
- If no tickets exist: STOP and return `BLOCKED: no tickets found. Run slice first.`

## Workflow (the loop)

For the ticket file you picked, run this loop until every `- [ ]` is `- [x]` or you hit a hard block:

### Iteration loop

1. **Read the ticket fresh.** Treat the previous iteration's working state as discarded. The ticket file is the only source of truth.
2. **Pick the first unchecked task** (`- [ ]`).
3. **RED** — write the failing test that proves the task's behaviour.
   - Put the test in the repository's documented test location from `AGENTS.md` / `docs/testing.md`.
   - Use the documented unit, integration, e2e, smoke, or language-specific test command for the behaviour under test.
   - CRITICAL: confirm the test **fails for the right reason**. "Failed because the file doesn't exist yet" counts. "Failed because of a typo in the assertion" does not.
4. **GREEN** — write the minimum code to pass that one test. No bonus features. No "while I'm in here."
5. **REFACTOR** — with tests still green, do **in-slice** cleanup only: extract one composable, rename one symbol, kill one duplication you just created. STOP before refactoring anything outside the slice.
6. **Backpressure** — run the repository's documented verify command. If the verify command is unset, run the smallest documented equivalent set of checks from `docs/quality-pipeline.md` (for example lint/typecheck/unit tests, compiler checks, or language-specific test suites). Also run any targeted e2e/smoke tests you authored for this ticket. Fix what trips before committing.
7. **Commit** — conventional commit, scoped to the slice. Example: `feat(booking): add guest-info form (slice 01)`. One iteration = one commit.
8. **Tick the box** — flip `- [ ]` to `- [x]` in the ticket file. Commit this edit with the same message or as a `chore` follow-up.
9. **Loop** back to step 1.

### Exit

- All boxes ticked → exit success.
- Same task fails 3 attempts in a row → exit blocked. Surface what you tried.

## Hard rules

- CRITICAL: **Never delete or skip a failing test to make CI green.** If a test fails, fix the implementation. If the test itself is wrong, edit it explicitly and explain in the commit body which requirement changed.
- CRITICAL: **Never weaken an assertion** without naming the requirement that changed.
- CRITICAL: **Never `--no-verify`** a commit, **never `git push --force`**, **never `git reset --hard`** to escape a stuck state. Surface the blocker instead.
- IMPORTANT: One box per iteration. One iteration per commit.
- IMPORTANT: Do not change behaviour outside this slice's scope. Out-of-scope refactors get logged as a note for Phase 4.
- IMPORTANT: If a type checker or compiler fails, fix the type. Do not add unchecked casts, suppressions, or broad dynamic escapes to silence it.

## Notes for simplify (on-disk handoff)

When you spot out-of-scope cleanup during the loop (a stale test file, a module-level mutable singleton, a duplicated helper across slices), do **not** fix it — your scope is this slice. Instead, **append** the note to `.clanker/simplify-notes.md` under a heading scoped to this ticket:

```
## NN-<slug>

- [ ] <one-line description of the offender> — <relative/path/to/file.ts>
- [ ] <next note>
```

Rules:

- **Append, do not overwrite.** Multiple ralph subagents add to this file across tickets; never truncate it.
- **One heading per ticket.** If the heading already exists (re-run), append new bullets under it rather than duplicating the heading.
- **Unchecked boxes only.** Ralph never ticks these — that is simplify's job when it commits the fix.
- Skip the file entirely if you have no notes for this ticket. An empty `.clanker/simplify-notes.md` is fine.

## Output

```
Ticket: docs/tickets/NN-<slug>.md
Boxes ticked: <X / Y>
Commits added: <N>
  - feat(...): ...
  - feat(...): ...
Blockers (if any):
  - <task> — <what you tried, why you stopped>
Notes for simplify:
  - <out-of-scope cleanup spotted but not done>
Notes file: .clanker/simplify-notes.md   (or "none" if no notes appended)
```

If `Boxes ticked` equals total, the slice is done. The orchestrator moves to the next ticket. If blocked, the pipeline stops — do not silently proceed.
