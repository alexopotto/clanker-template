---
name: simplify
description: Dedicated refactor pass over branch-changed files. Kills `any`s, duplication, dead code, primitive obsession, long files. Behaviour preserved; one offender per commit; tests green at every commit. Use after all slices are implemented, when invoked as Phase 4 of the clanker pipeline, or when the user types /simplify.
---

# simplify — Phase 4 (AFK): Refactor Pass

## Purpose

Ralph loops always cheat on refactoring — "refactor" shrinks to "rename a variable" while duplication piles up across slices. This skill is the dedicated cleanup the implementation loop will not do on its own. One offender per commit. Tests green at every commit.

## Core principles

- **Behaviour preserved.** Tests pass before and after every commit. No new features, no scope creep.
- **One offender per commit.** Each commit is independently revertable.
- **Branch scope only.** Touch only files that changed on this branch. The rest of the repo is out of scope.
- **Subtract, then reshape.** Deleting dead code is cheaper than reorganising live code. Do the easy wins first.

## Inputs

The input controls scope:

- empty or `branch` (default) → files in `git diff --name-only main...HEAD`
- `staged` → `git diff --cached --name-only`
- `last-commit` → `git show --name-only --pretty="" HEAD`
- a path → walk that directory

If the working tree is dirty: STOP and return `BLOCKED: uncommitted changes. Commit or stash before simplify.`

**Ralph notes (priority bias).** If `.clanker/simplify-notes.md` exists, read it. Each unchecked bullet under a `## NN-<slug>` heading is a candidate offender ralph flagged but couldn't fix in-scope. Use these to **bias** offender selection (see Workflow Step 2) — they do not override the category ordering below, and they do not expand branch scope.

Stale-note guard: ignore any heading whose ticket slug refers to a file that is **not** in `git diff --name-only main...HEAD`. The note belongs to a different feature.

## What to look for (in order)

1. **Unchecked type escapes** — replace with the real type or language-appropriate safe boundary. If unknown, narrow explicitly instead of suppressing the checker.
2. **Dead code** — unused exports, unreachable branches, commented-out blocks. Delete.
3. **Duplication** — same shape repeated 2+ times → extract a composable, util, or component.
4. **Primitive obsession** — three loose strings always passed together → a typed object.
5. **Long files / long functions** — split by responsibility, not by line count.
6. **Inconsistent naming** — pick one term, propagate. Verbs for actions, nouns for state.
7. **Implicit shared state** — module-level mutable singletons or global state that should live in the project's documented state-management boundary.

## Workflow

For each pass — repeat until no offenders remain:

1. `git status` — confirm clean working tree.
2. Pick **one** offender. Apply category ordering from the list above (any → dead → dup → ...). Among ties **within the same category**, prefer offenders flagged in `.clanker/simplify-notes.md`. When you commit a fix that resolves a note, tick its checkbox in place (`- [ ]` → `- [x]`). When you decide a note belongs in `Spotted but skipped:`, leave it unticked and add a reason in the output block.
3. Make the **smallest** change that removes it. No drive-by edits.
4. Run backpressure: the repository's documented verify command, plus targeted e2e/smoke checks if you touched behaviour boundaries.
5. **If any check fails**: revert, rethink, do not commit a broken state.
6. **If all green**: commit with `refactor(<scope>): <what you removed>`. Example: `refactor(booking): extract useBookingDraft composable`.
7. Loop.

STOP after ~8 commits even if more offenders remain. Diminishing returns plus reviewer overload. Log the rest as notes.

## Hard rules

- CRITICAL: **Do not change behaviour.** If a test starts failing, your refactor was not a refactor. Revert.
- CRITICAL: **Do not bypass type-checking or compiler checks.** No new unchecked casts, broad dynamic escapes, or suppressions. If an underlying API genuinely requires one, keep it in a single boundary file, narrow as soon as possible, and note it in the output.
- CRITICAL: **Do not delete tests.** If a test seems redundant, that is the reviewer's call, not yours.
- IMPORTANT: One offender per commit.
- IMPORTANT: Branch scope only.
- Do not add features. Do not "modernise" unrelated patterns.

## Output

```
Refactor commits: <N>
  - refactor(<scope>): <subject>
  - …
Spotted but skipped:
  - <one-liner> — <why: out of scope / behaviour change / needs a real ticket>
```

Phase 5 (`qa`) runs next.
