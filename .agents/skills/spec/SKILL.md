---
name: spec
description: Interview-driven PRD generation. Asks the user one question at a time about goals, users, happy path, edge cases, validation, error states, and non-goals; synthesises agreement; writes docs/prd-<slug>.md. Use when starting a new feature, when the user types /spec, or when invoked as Phase 1 of the clanker pipeline.
---

# spec — Phase 1 (HITL): Interview-Driven Spec

## Purpose

Take a vague feature topic from the user and produce a PRD that is small enough to fit one Ralph slice budget but sharp enough that the rest of the pipeline does not have to guess. This is the **HITL edge** of the pipeline — every cascading mistake downstream starts here.

> "A flawed specification cascades through hundreds of lines; flawed research generates thousands of bad lines." — Dex Horthy

## Core principles

- **Interview, do not generate.** Ask the human. Do not invent goals, users, or acceptance criteria.
- **One question per turn.** Even when sub-questions feel related. Wait for the answer before the next question.
- **Cover the right ground, not all the ground.** Goals · users · happy path · edge cases · validation · error states · non-goals. Skip what they already answered inline.
- **Stop when you have enough.** 5–8 questions is the usual range. More than 10 is a smell.
- **Repo-relative paths only.** Never absolute paths in the PRD.

## Inputs

- The topic — either a sentence from the user, or the prompt passed by the orchestrator. If empty, the first question must be "what are we building?"
- Project facts (do not re-ask): read `AGENTS.md` and the relevant `docs/*.md` files for stack, package manager, test layout, architecture, terminology, and quality gates. If those docs are unset or contradict the manifest/build files, ask one setup clarification before writing a PRD that depends on stack details.

## Workflow

### Step 1 — Pick your question primitive

Use your harness's blocking-question primitive:

- **Claude Code**: `AskUserQuestion` — load via `ToolSearch select:AskUserQuestion`, then invoke. Prefer single-select multiple choice (3–4 options).
- **Codex**: `request_user_input(prompt, options)`.
- **VS Code Copilot / Cursor / other**: post the question as a chat message and wait.
- **Fallback**: numbered options in chat (`1) … 2) … 3) …`) and wait for a numeric reply.

Never silently skip a question.

### Step 2 — Interview, one question at a time

Prefer single-select multiple choice (3–4 distinct options) when the answer chooses one direction. Use multi-select rarely, only for compatible sets (goals, constraints, non-goals). Use open prose only when the answer is genuinely narrative or options would leak your priors.

Cover, in roughly this order, skipping what is already settled:

1. **Goal** — what changes for the user once this ships.
2. **User** — who, what they're trying to do.
3. **Happy path** — the steps a user takes when nothing goes wrong.
4. **Edge cases** — what makes this hard.
5. **Validation** — field-level rules, allowed inputs.
6. **Error states** — how the UI surfaces failure.
7. **Non-goals** — what we are explicitly not building this pass.

### Step 3 — Synthesise (do not skip)

STOP. Before writing the PRD, write a 3–5 bullet synthesis back to the user in chat: **what we agreed**, **what we are explicitly not building**, **the riskiest part**. This is a scope checkpoint, not the PRD.

Ask one final blocking question: **"Ship this synthesis to a PRD? (yes / refine X / refine Y)"**. If they pick refine, loop back to Step 2 with one targeted question.

### Step 4 — Write the PRD

Write to `docs/prd-<kebab-slug>.md` (slug from the topic) using the skeleton in `assets/prd-template.md`.

## Hard rules

- CRITICAL: Do not write the PRD without running the interview. If the user says "just write it," push back once with a one-sentence reminder of why the interview saves them downstream pain, then proceed if they insist — but mark the PRD with `> Generated without interview — verify before slicing.` at the top.
- IMPORTANT: One question per turn. Batching three sub-questions into one message defeats the point.
- IMPORTANT: No code, no file paths in the PRD beyond what the user explicitly named. Implementation choices belong to `slice` and `ralph`.
- Do not pad the PRD with template sections the user did not answer. Sections may be one bullet if that is all the truth there is.

## Output

Final return to the parent (orchestrator or user):

```
PRD: docs/prd-<slug>.md
Topic: <one line>
Risky bits: <one line — the part most likely to bite>
Open questions logged: <count or "none">
```

Then stop. Phase 2 (`slice`) consumes the PRD path.
