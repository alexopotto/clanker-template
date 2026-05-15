---
name: slice
description: Reads a PRD and breaks it into 3–6 vertical-slice tickets under docs/tickets/, each independently shippable end-to-end (UI + state + route/composable + e2e test). Use after a PRD is written, when invoked as Phase 2 of the clanker pipeline, or when the user types /slice.
---

# slice — Phase 2 (AFK): Vertical Slices

## Purpose

Turn one PRD into 3–6 vertical-slice tickets, each small enough for a single Ralph loop and each shippable on its own. The whole pipeline downstream depends on getting the slicing right — bad slices = compaction, blocked dependencies, half-shipped features.

## Core principles

- **Vertical, not horizontal.** Each slice is one end-to-end strip: UI + state/store + (route or composable) + the one e2e test that proves it. Never split into "frontend / backend / tests".
- **Independently shippable.** Slice N must work even if slice N+1 never lands. Failure of one slice cannot brick the others.
- **One Ralph budget each.** 1–2 story points. If a slice has more than ~5 checkbox tasks, split it.
- **Smallest first.** The first slice should be the cheapest path to a green end-to-end test — even if it's a stub. Real value lands incrementally.

## Inputs

- The PRD path. If empty or missing, find the newest file matching `docs/prd-*.md`.
- If no PRD exists: STOP and return `BLOCKED: no PRD found. Run spec first.`

## Workflow

### Step 1 — Read the PRD

Read it in full. List, for yourself, the acceptance criteria and any explicit happy-path steps. These are the spine of the slicing.

### Step 2 — Identify the slice axis

For most features, the natural axis is **steps of the user's flow**: each step of the happy path that performs an observable action is a candidate slice. For features without a flow (e.g. a single component, a setting), slice by **independent concerns** that can each be tested end-to-end.

IMPORTANT: If you cannot describe each slice as "the user can do X and see Y" — without referring to a sibling slice — your slicing is horizontal. Redo it.

### Step 3 — Write the ticket files

For each slice, write `docs/tickets/NN-<kebab-slug>.md` (NN = `01`, `02`, …) using the skeleton in `assets/slice-template.md`. Keep the `Execution note: test-first` line — `ralph` honours it.

### Step 4 — Add an integration slice if needed

If the feature has more than 2 slices, the **last** slice is almost always cross-slice integration (state machine, navigation, happy-path-end-to-end). Add it explicitly.

### Step 5 — Sanity check

STOP. Before returning, re-check each ticket against this checklist:

- [ ] Each slice has its own e2e test step.
- [ ] No slice's "Scope (in)" depends on a later slice's output.
- [ ] No slice is purely backend or purely frontend.
- [ ] No slice has more than 5 checkboxes.

If any check fails, fix the affected slice. Do not return a known-bad set.

## Hard rules

- CRITICAL: No horizontal slices. "Backend for the wizard" is not a slice.
- IMPORTANT: Repo-relative paths only.
- IMPORTANT: Do not write production code from this skill. Slicing is planning, not implementation.
- Do not pad. 3 well-shaped slices beat 7 mushy ones.

## Output

```
Slices written: <N>
- 01-<slug>.md — <one-line goal>
- 02-<slug>.md — <one-line goal>
...
Integration slice: <yes/no, slice number if yes>
First slice to run: 01-<slug>.md
```

Phase 3 (`ralph`) consumes the list, in order.
