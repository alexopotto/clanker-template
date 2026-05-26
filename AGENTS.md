# AGENTS.md

<!--
  This file is the repo-level convention doc your agents read on every task.
  It is the canonical name (AGENTS.md — the cross-harness convention used by
  Codex, Cursor, Aider, and others). CLAUDE.md in this repo is a symlink to
  this file so Claude Code finds it too. Edit this file; the symlink follows.

  Fill in the project-specific values below after copying this template.
  The clanker pipeline's skills read this file plus the setup docs listed below
  via .clanker/context.md and expect it to define a verify gate, test layout,
  and package manager.
-->

## Stack

Template default: unset. Replace this line with the real stack, for example
`pnpm · Vue 3 · Vite · Vitest · Playwright`, `Maven · Java 21 · JUnit`, or
`uv · Python · pytest`.

## Commands

Fill this table with commands that work in this repository. If a capability does
not exist, write `none` and explain why in `docs/quality-pipeline.md`.

| Purpose | Command |
|---|---|
| Install dependencies | unset |
| Start local app/service | unset |
| Verify before completion | unset |
| Unit tests | unset |
| End-to-end or smoke tests | unset |
| Production build | unset |

Tests live in: unset. Replace with the real unit/component/e2e layout.

Agents must use the command table above instead of guessing package-manager,
language, or framework commands.

## IMPORTANT: read relevant docs before starting a task

- [`docs/architecture.md`](docs/architecture.md) — what lives where (create when you have one)
- [`docs/agent-setup.md`](docs/agent-setup.md) — command contract and QA modes
- [`docs/conventions.md`](docs/conventions.md) — code conventions
- [`docs/testing.md`](docs/testing.md) — test strategy
- [`docs/quality-pipeline.md`](docs/quality-pipeline.md) — what `verify` checks and how to fix red

## Hard rules

- **One package manager only.** No mixing. Declare it in the Stack section.
- **The verify command is the gate.** A task isn't done until it exits 0.
- **No unchecked type escapes.** If the type system pushes back, fix the type, don't silence it.
- **No premature scaffolding.** Don't create empty folders, stub components, or "TODO" files. Create files only when they're actually needed.
- **Prefer role/label queries** in tests over brittle CSS selectors.

## What tooling already enforces (don't restate)

Linters handle style. The type-checker handles types. The formatter handles formatting. If a tool can enforce it, this file doesn't repeat it.

---

## How the clanker pipeline uses this file

When you run `/clanker <prd>`, the pre-flight step concatenates this file plus the setup docs listed above into `.clanker/context.md`. Every subagent reads that context before doing work. So:

- Anything you put here propagates to every phase.
- Don't put PRD-specific or task-specific guidance here — that goes in the PRD or the ticket.
- Keep this file focused on **durable conventions**: stack, gates, hard rules.
- Run `scripts/agent-doctor.sh` after adapting the template to catch missing docs, stale placeholders, broken symlinks, and hardcoded stack commands.
