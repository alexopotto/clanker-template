---
name: clanker
description: Five-phase AFK pipeline that takes an existing PRD file from slicing to PR. Phases (slice → ralph → simplify → qa → review) run in strict order with file-based handoff between phases. Input is a path to a PRD file (produced separately by `/spec`). Use when the user asks to orchestrate the full AFK ship process from a PRD, types /clanker <path>, or wants a feature driven end-to-end through the pipeline.
---

# clanker — Orchestrator

Drives the five AFK-coding phases in strict order, starting from an existing PRD on disk. Each phase is its own skill in this same `skills/` directory. The orchestrator's job is *sequencing* and *gating* — never reach into the body of another phase.

The interview/PRD step lives in the separate `spec` skill and is **not** part of this pipeline. Run `/spec` first (or write the PRD by hand); pass the resulting path to `/clanker`.

**Design rationale + workflow diagram:** see `references/design.md`. The orchestrator does not re-read it each run.
**Harness primitives (subagent dispatch, user-question tools):** see `references/dispatch.md`.

Phases dispatched, in order: `slice`, `ralph` (once per ticket), `simplify`, `qa`, `review` (sibling folders under `.agents/skills/`).

## Shared memory (markdown on disk)

Phases never pass data through prompts. They read and write markdown files. The orchestrator holds only the **paths** between phases, not the contents.

| File | Written by | Read by | Purpose |
|---|---|---|---|
| `docs/prd-<slug>.md` | **caller (e.g. `/spec`)** | slice (P1) | The PRD — input to this pipeline |
| `.clanker/context.md` | pre-flight | every subagent | Stack context (CLAUDE.md + docs concatenated) |
| `.clanker/baseline.md` | pre-flight | (informational) | Pre-pipeline test pass + commit SHA |
| `docs/tickets/NN-*.md` | slice (P1) | ralph (P2, one per ticket) | Per-slice spec + checklist |
| `.clanker/simplify-notes.md` | ralph (P2, appended) | simplify (P3) | Out-of-scope spots, ticket-scoped headings |
| Branch commits | ralph (P2), simplify (P3), qa (P4) | review (P5) | The implementation + cleanup + qa artifacts |
| `qa/<slug>.md` + screenshots | qa (P4) | review (P5) | QA report — happy + negative paths, posture |

Each phase **also** prints a slim structured Output block (paths + pass/fail flags, no raw transcripts). The orchestrator parses that block to evaluate the gate. The on-disk markdown is the source of truth; the Output block is a thin index.

## Slim subagent prompt

The orchestrator's dispatch prompt is small — well under 20 lines. Never paste the body of `SKILL.md` into the prompt. Subagents have `Read` access to the repo and load their own instructions from disk.

Template:

```
You are running phase <X> (<phase-name>) of the clanker pipeline.

Instructions:    .agents/skills/<phase>/SKILL.md   ← read this first, follow it
Context:         .clanker/context.md               ← project conventions, read once
Input artifact:  <path on disk>
Slug:            <slug>
Branch:          <branch-name>

Return the structured Output block defined at the bottom of your SKILL.md
verbatim. Do not summarise. Do not include the transcript.
```

If a subagent comes back asking *"what do I do?"* — the SKILL.md path was wrong. Verify the file exists before dispatching.

## Input

The user-supplied input **must be a path to an existing PRD file** (typically produced by `/spec`, e.g. `docs/prd-<slug>.md`).

- If a path is provided, verify the file exists and is readable. Derive `<slug>` from the filename (`docs/prd-<slug>.md` → `<slug>`).
- If no path is provided, **stop** and tell the user: *"clanker needs a PRD path. Run `/spec` first to generate one, or pass an existing PRD file path."* Do not start an interview. Do not invent a PRD.
- If the path does not exist, stop and surface the missing-file error verbatim. Do not create a stub.

This skill is the AFK loop only. Interviewing the user belongs to `/spec`.

## Pre-flight (once, before Phase 1, INLINE)

Runs in the orchestrator because it needs user interaction and shared-state commands. Steps in order — STOP and surface on the first failure.

1. **PRD path.** Confirm exists and record `<slug>`.
2. **Git state.** Confirm `git rev-parse --is-inside-work-tree`. Confirm we are NOT on `main`/`master`. If we are, ask the user for a feature branch name (default suggestion: `feat/<slug>`), then `git checkout -b <name>`.
3. **Dependencies.** Read the install command from `AGENTS.md`. If dependency artifacts are missing for the detected stack, run the documented install command. If no install command is documented, STOP with `BLOCKED: install command unset in AGENTS.md`.
4. **gh auth.** Confirm `gh auth status` succeeds. If not, warn — Phase 5 will fall back to printing the PR body.
5. **`.gitignore`.** Confirm `.clanker/` is gitignored. If not, append it (one line, with a header comment) and commit the gitignore change: `chore: ignore clanker scratch dir`.
6. **Baseline checks (clean room before slicing).** Run the documented verify command from `AGENTS.md`. Also run the documented e2e/smoke command if one exists and is not already included in verify.
   - If a tool reports missing runtime assets (for example browsers, containers, fixtures, databases, SDKs) → STOP with `BLOCKED: install required test/runtime assets — <tool output summary>`.
   - If any suite/check is red → STOP with `BLOCKED: pre-existing reds — fix or delete before slicing.` Print the failing test paths or command names. The user fixes/deletes scaffold failures and re-invokes `/clanker`.
   - If checks are green → write `.clanker/baseline.md`:
     ```
     verify: PASS
     e2e_or_smoke: PASS | not configured
     commit: <git rev-parse --short HEAD>
     ```
7. **Context snapshot.** If `.clanker/context.md` is missing OR older than the newest of `CLAUDE.md`, `docs/agent-setup.md`, `docs/architecture.md`, `docs/conventions.md`, `docs/testing.md`, `docs/quality-pipeline.md` → regenerate by concatenating those files into `.clanker/context.md`, each prefixed with `## <relative-path>`. **Verbatim concatenation, not summarisation.** Missing source files are fine — skip them.

After pre-flight, `<slug>`, `<branch>`, and the `.clanker/` paths are recorded and reused for every subagent dispatch below.

## How to dispatch (harness-specific primitive)

The orchestrator needs to know **which harness it is running in** to pick the right primitive. The user usually hints at this when invoking (e.g. *"running this in codex"*, *"on copilot"*). If no hint is given, ask once at pre-flight, then remember it for the rest of the pipeline.

With the harness known, look up the primitive in `references/dispatch.md` Table A and use the **slim prompt template above** as its prompt — never inline the SKILL.md body. After dispatch, read the subagent's final message, extract the structured Output block, and evaluate the gate.

**Fallback (no subagent primitive available in this harness).** Read `../<phase>/SKILL.md` and run its workflow inline in the current session. On-disk artifacts are identical; you only lose context isolation. If you must fall back for ralph, run the tickets sequentially in the same session — there is no parallel mode.

## Asking the user

The pipeline is AFK by design and has **no HITL phases** beyond pre-flight (branch name, harness hint). If pre-flight needs input, use your harness's question primitive (see `references/dispatch.md` Table B). If your harness lacks one, post a numbered-options question to chat and wait. Never silently skip.

## Pipeline

### Phase 1 — Slice (AFK, SUBAGENT)

Dispatch the `slice` skill as a subagent with the PRD path supplied by the user.

**GATE 1:** STOP until at least one `docs/tickets/NN-*.md` exists. The subagent's return must include `Slices written: N` with `N ≥ 1`. Record the ticket list, in order.

### Phase 2 — Ralph (AFK, SUBAGENT PER TICKET)

For each ticket in numeric order, dispatch a **fresh** `ralph` subagent with that ticket path. One subagent per ticket — never share a subagent across tickets. Read its return:

- If `Blockers (if any):` is non-empty → STOP the whole pipeline. Surface the blocker. Do not proceed to Phase 3.
- If all boxes ticked → continue to the next ticket with a new subagent.

Run tickets **sequentially**, never in parallel — ticket `NN+1` may depend on commits from ticket `NN`.

**GATE 2:** STOP until every ticket reports all boxes ticked, OR a blocker has been surfaced. Do not skip a stuck slice.

### Phase 3 — Simplify (AFK, SUBAGENT)

Dispatch the `simplify` skill as a subagent with default scope (`branch`). Simplify reads `.clanker/simplify-notes.md` to bias offender selection.

**GATE 3:** STOP until the subagent returns. If `Refactor commits` is 0, that is fine — clean branches are allowed.

### Phase 4 — QA (AFK, SUBAGENT)

Dispatch the `qa` skill as a subagent with the branch slug.

**GATE 4:** STOP until the subagent returns. Record `PR posture: ready | draft`. The subagent commits its own artifacts; the working tree must be clean before Phase 5 dispatches. If `git status --porcelain` is non-empty after Phase 4 → STOP with `BLOCKED: qa left uncommitted artifacts`.

### Phase 5 — Review (HITL handoff, SUBAGENT)

Dispatch the `review` skill as a subagent with any user-provided extra notes (empty input → `"—"`). The phase itself is non-interactive — it pushes and opens the PR; the HITL part happens *after* on the PR page.

**GATE 5:** STOP until the subagent returns a PR URL or a `BLOCKED:` reason. Do not retry on `BLOCKED:` — surface it.

## Orchestration rules

- CRITICAL: **Do not interview the user.** This skill consumes a PRD; it does not produce one. If the user did not pass a PRD path, stop and point them at `/spec`.
- CRITICAL: **Do not skip phases.** Even if a slice looks trivial, the pipeline is the value.
- CRITICAL: **Do not run phases in parallel.** Each phase consumes the previous phase's artifact. This includes ralph tickets — sequential only.
- CRITICAL: **One subagent per ralph ticket.** Never reuse a ralph subagent across tickets. Context isolation is the whole point.
- IMPORTANT: If any AFK phase reports a hard block, STOP and report. Do not auto-recover by deleting work or reverting commits.
- IMPORTANT: Status updates are terse — one line per phase as it starts, one line per phase as it ends. For ralph, one line per ticket dispatched and one line per ticket completed.
- IMPORTANT: Subagent vs inline must not change the on-disk artifact. If a subagent's return block conflicts with what is on disk, trust disk and treat the discrepancy as a bug in the phase prompt.

## Final output

When every gate has been satisfied, print this block exactly once:

```
Pipeline complete.
PRD:       docs/prd-<slug>.md   (input)
Baseline:  .clanker/baseline.md (unit/e2e PASS @ <sha>)
Slices:    <N> tickets, all boxes ticked: yes/no
Refactors: <M> commits
QA:        qa/<slug>.md — happy: PASS/FAIL · negatives: PASS/FAIL · PASS/FAIL
PR:        <url>  (posture: ready | draft)
```

Stop. The human takes it from here.
