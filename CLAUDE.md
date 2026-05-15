# CLAUDE.md

<!--
  This file is the repo-level convention doc your agents read on every task.
  Fill in the placeholders below with your stack and conventions.
  The clanker pipeline's skills read this file (via .clanker/context.md) and
  expect it to define a `verify` gate, a test layout, and a package manager.
-->

## Stack

<your stack here — e.g. "pnpm · Vue 3 · Vite · Vitest · Playwright">

## Commands

- `<dev command>` — local dev server (e.g. `pnpm dev`)
- `<verify command>` — type-check + lint + unit/component tests. **Run before claiming a task is done.** (e.g. `pnpm verify`)
- `<test command>` — test runner in watch mode (e.g. `pnpm test`)
- `<e2e command>` — end-to-end tests (e.g. `pnpm test:e2e`)
- `<build command>` — production build (e.g. `pnpm build`)

Tests live in `<your test layout>`. The clanker pipeline assumes a separation between unit / component / e2e — adjust the skills if your layout differs.

## IMPORTANT: read relevant docs before starting a task

- [`docs/architecture.md`](docs/architecture.md) — what lives where (create when you have one)
- [`docs/conventions.md`](docs/conventions.md) — code conventions
- [`docs/testing.md`](docs/testing.md) — test strategy
- [`docs/quality-pipeline.md`](docs/quality-pipeline.md) — what `verify` checks and how to fix red

## Hard rules

- **One package manager only.** No mixing. (Pick one in the Stack section.)
- **`<verify command>` is the gate.** A task isn't done until it exits 0.
- **No `any`, no unchecked casts.** If the type system pushes back, fix the type, don't silence it.
- **No premature scaffolding.** Don't create empty folders, stub components, or "TODO" files. Create files only when they're actually needed.
- **Prefer role/label queries** in tests over brittle CSS selectors.

## What tooling already enforces (don't restate)

Linters handle style. The type-checker handles types. The formatter handles formatting. If a tool can enforce it, this file doesn't repeat it.

---

## How the clanker pipeline uses this file

When you run `/clanker <prd>`, the pre-flight step concatenates this file plus everything under `docs/*.md` into `.clanker/context.md`. Every subagent reads that context before doing work. So:

- Anything you put here propagates to every phase.
- Don't put PRD-specific or task-specific guidance here — that goes in the PRD or the ticket.
- Keep this file focused on **durable conventions**: stack, gates, hard rules.
