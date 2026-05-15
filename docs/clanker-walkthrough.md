# The Clanker Framework — How It Works

A walkthrough of the AFK ("away from keyboard") coding pipeline used in this repo, with a real end-to-end run as the worked example: the **Pokedex MVP**, which went from a 206-line PRD to a merge-ready PR (#2) in five orchestrated phases, 44 commits on `feat/pokedex-v2`.

---

## TL;DR

Clanker is a **multi-phase orchestrator** that takes a written spec (PRD) and drives it through five specialist sub-skills until a PR is open. The orchestrator only handles *sequencing* and *gating* — every phase is its own self-contained skill, dispatched as a fresh subagent, and they hand off via **markdown files on disk**, not by passing data through prompts.

```
PRD ──► slice ──► ralph (×N) ──► simplify ──► qa ──► review ──► PR
        (P1)      (P2)            (P3)         (P4)   (P5)
```

The headline trick: every subagent gets a ~10-line prompt that just points at its `SKILL.md` and its input file. The subagent loads its own instructions from disk. This keeps the orchestrator's context tiny (1.4k tokens of skill metadata for the whole run) while each phase runs in fresh, isolated context.

---

## Concepts you need to know first

This pipeline is **harness-agnostic** — it works in any coding-agent harness that supports the primitives below (subagent dispatch, file read/write, shell execution). The skill files in this repo happen to use one harness's filesystem convention, but the framework itself doesn't care. If you've never seen these terms, read this glossary first.

### Subagent

A **subagent** is a fresh agent instance spawned by the main (orchestrator) session. It gets:
- Its own **isolated context window** (it does *not* see the parent's conversation).
- Only the prompt the parent gives it.
- Its own tool calls and its own tool-call history.
- A single final return message back to the parent — that's all the parent ever sees.

Think of it as `fork()` for a conversation. The parent says "go do this", the child does it from scratch, the child reports back one summary, the child is discarded. The parent never sees the child's tool calls, file reads, or intermediate reasoning.

**Why we use them:** isolation. The orchestrator does not want 100 tool calls' worth of ralph debugging in its context. The orchestrator only wants the final "5/5 boxes ticked, here are the commits" line. Spawning a subagent gives you exactly that.

Different harnesses expose this differently — the orchestrator looks up the right dispatch primitive for your harness (Task / spawn / agent-call / whatever it's named) and uses it. In this doc, every time you see "dispatched" or "the X subagent returned", that's the parent (`/clanker` orchestrator) spawning a child running one phase.

### Skill (`SKILL.md`)

A **skill** is a self-contained set of instructions for a recurring task, stored as a markdown file the agent reads on demand. The user invokes a skill via slash command (e.g. `/ralph`), or — more importantly here — the orchestrator dispatches a subagent and tells it "read `<path>/SKILL.md` and follow it".

Skills in this repo:
```
skills/
├── clanker/         orchestrator (this doc)
├── spec/            interview → PRD
├── slice/           PRD → tickets
├── ralph/           ticket → green TDD commits
├── simplify/        refactor pass
├── qa/              Playwright happy + negatives
├── review/          push + open PR
├── grill-with-docs/ stress-test plan vs. project docs
└── write-a-skill/   meta — author new skills
```

(The exact directory varies by harness — what matters is that each skill is one markdown file the subagent can `Read`.)

The orchestrator never inlines a skill's body into a prompt — it points the subagent at the file path and lets the subagent read it. That's why the orchestrator's own context stays tiny.

### Ralph loop

The **ralph loop** is the TDD cycle the `/ralph` skill runs **per ticket**:

```
                ┌──────────────────────────────────────────┐
                │                                          │
                ▼                                          │
   1. Read next unchecked checkbox in ticket               │
   2. Write the failing test (RED)                         │
   3. Make it pass with minimum code (GREEN)               │
   4. Refactor if obvious (REFACTOR)                       │
   5. `pnpm verify` — must exit 0                          │
   6. Commit (one iteration = one commit)                  │
   7. Tick the checkbox in the ticket file                 │
   8. Commit the tick                                      │
                │                                          │
                └──── more unchecked boxes? ───────────────┘
                                │
                                ▼
                          All ticked → return
```

The name "ralph loop" comes from a [Geoffrey Huntley blog post](https://ghuntley.com/ralph/) where "Ralph" is shorthand for an AI agent that grinds through a checklist mechanically. The point is *mechanical*: ralph does not invent scope, does not skip items, does not stop early. One checkbox = one iteration = one feat/test/refactor commit + one tick commit.

If ralph gets stuck (test that won't go green, ambiguous requirement) it appends to `.clanker/simplify-notes.md` and surfaces a blocker rather than fudging.

### Fetch (HTTP fetch from the agent)

When you see "fetch the PokeAPI" or "verify external API shapes by fetching" in this repo, it means an agent calling its **web-fetch primitive** — a tool that performs an HTTP GET on a URL and returns the response body. Most harnesses expose this (often named `WebFetch`, `http`, `fetch_url`, or similar); `curl` from the shell is the universal fallback. There is also a JavaScript `fetch()` in the application code; context tells you which is meant.

This matters because there's a documented preference in this repo: *"verify external API shapes by curl/WebFetch before recommending data shapes; don't reason from memory."* When a PRD references PokeAPI, the slice/ralph subagents should hit an actual endpoint to confirm the JSON shape before they generate types — not guess from training data.

### Search (two kinds)

Two different things, both called "search":

- **Web search** — the harness's tool for googling. Returns titles + snippets + URLs. Used when you need recent docs, library versions, error messages. (Named `WebSearch` in some harnesses; `gh search` / `curl` of a search API works as a fallback.)
- **Code search** — finding things inside the repo. Either a literal `ripgrep`/`grep` call, or a read-only sub-search agent that does multi-step lookups ("where is X defined / which files reference Y").

In the pipeline these come up most during slice (looking up API shapes, finding existing patterns to follow) and ralph (locating the right file to edit). The orchestrator itself rarely searches — it just dispatches.

### Gate

A **gate** is the orchestrator's check after a phase returns. It reads the structured Output block and inspects disk; if the gate fails (e.g. zero tickets written, qa left an uncommitted file), the orchestrator **stops** rather than auto-recovering. Gates exist because subagents can lie about what they did — disk is the source of truth.

### AFK / HITL

- **AFK** = "away from keyboard". A phase is AFK if it runs without user input.
- **HITL** = "human in the loop". A phase is HITL if it pauses for user input.

In clanker, the **entire pipeline is AFK** except for pre-flight (which asks once about branch name and harness). The HITL part happens *after* the pipeline finishes — on the PR page, where a human reviews and merges.

---

## Core design principles

### 1. File-based handoff

Phases never pass data through prompts. They read and write `.md` files:

| File | Written by | Read by | Purpose |
|---|---|---|---|
| `docs/prd-<slug>.md` (or `specs/<slug>.md`) | the user / `/spec` | `slice` | the spec — input to the whole pipeline |
| `.clanker/context.md` | pre-flight | every subagent | concatenated `AGENTS.md` (or `CLAUDE.md`) + `docs/*.md` |
| `.clanker/baseline.md` | pre-flight | (informational) | pre-pipeline test pass + commit SHA |
| `docs/tickets/NN-*.md` | `slice` | `ralph` (one per ticket) | per-slice spec with TDD checklist |
| `.clanker/simplify-notes.md` | `ralph` (appended) | `simplify` | out-of-scope spots flagged during implementation |
| `qa/<slug>.md` + screenshots | `qa` | `review` | happy + negative path PASS/FAIL, PR posture |
| branch commits | every phase | `review` | the actual work |

Each phase also returns a **slim structured Output block** (paths + flags, no transcripts). Disk is the source of truth; the Output block is a thin index the orchestrator parses to evaluate the gate.

### 2. Subagent isolation

Each phase is dispatched as a fresh subagent. The orchestrator's prompt to it is tiny:

```
You are running phase 1 (slice) of the clanker pipeline.

Instructions:    .claude/skills/slice/SKILL.md   ← read this first, follow it
Context:         .clanker/context.md             ← project conventions, read once
Input artifact:  specs/pokedex-mvp.md
Slug:            pokedex-mvp
Branch:          feat/pokedex-v2

Return the structured Output block defined at the bottom of your SKILL.md
verbatim. Do not summarise. Do not include the transcript.
```

Why this matters:
- The orchestrator never sees implementation details, code, or test output — it sees only the structured return block.
- Each ralph ticket gets a fresh subagent, so context never bleeds between tickets.
- The orchestrator's context stays small enough that all five phases plus pre-flight fit in a tiny fraction of a large-context window. After this entire Pokedex run, the orchestrator was at ~6% context usage of a 1M-token budget — most of that was the conversation itself, not skill content.

### 3. Hard gates between phases

After every phase the orchestrator checks the on-disk artifacts and the return block. If a gate fails, it **stops** rather than auto-recovering. Examples:

- `GATE 1` (post-slice): at least one `docs/tickets/NN-*.md` must exist.
- `GATE 2` (post-ralph): every ticket must report all boxes ticked, OR a blocker is surfaced and the pipeline stops.
- `GATE 4` (post-qa): `git status --porcelain` must be empty — qa is supposed to commit its own artifacts.

### 4. AFK by design

There are **no human-in-the-loop checkpoints** beyond pre-flight (branch name, harness hint). Once pre-flight is green, the orchestrator runs all five phases without user input. The HITL part happens *after* the PR is opened — on the PR page, with a human reviewer.

---

## The five phases

| # | Phase | Input | Output | What it does |
|---|---|---|---|---|
| 1 | **slice** | PRD file | `docs/tickets/NN-*.md` | breaks the PRD into 3–6 vertical, end-to-end slices |
| 2 | **ralph** | one ticket | branch commits | TDD loop on the ticket (red → green → refactor → tick), one subagent per ticket, sequential |
| 3 | **simplify** | branch | refactor commits | one-offender-per-commit refactor pass over branch-changed files |
| 4 | **qa** | branch slug | `qa/<slug>.md` + screenshots | drives the dev server through happy + 2 negatives via Playwright |
| 5 | **review** | branch + qa report | PR URL | pushes branch, opens PR via `gh`, marks draft if qa failed |

`spec` (the interview that *produces* the PRD) is a **separate** skill and not part of the pipeline. Run `/spec` first or write the PRD by hand, then pass the path to `/clanker`.

---

## Before clanker: how a PRD and its tickets get created

A ticket doesn't appear out of nowhere — it's the **third** artifact in a chain. Two doc-creation skills run *before* `/clanker` and produce the inputs the pipeline needs:

```
   /spec   ──►   /grill-with-docs   ──►   /clanker (slice phase)
   (PRD)         (CONTEXT.md + ADRs)      (docs/tickets/NN-*.md)
```

### Step 1 — `/spec` writes the PRD

`/spec` is an **interview-driven** skill. You invoke it for a new feature, and it asks you one question at a time:

- What are you trying to build, for whom, and why?
- What's the happy path? Walk me through it.
- What are the edge cases? What should happen if X?
- What does "done" look like? What's the validation?
- What's explicitly *out of scope*?

It synthesises your answers into a single `docs/prd-<slug>.md` (or `specs/<slug>.md`) file with sections like Background, Scope (in / out), Acceptance criteria, Suggested slice breakdown. That file is the **input** to `/clanker`.

If you already have a PRD written by a PM or by hand, you skip this step — you just need the file on disk.

### Step 2 (optional but recommended) — `/grill-with-docs` sharpens it

For non-trivial features, `/grill-with-docs` is a **stress-test** session. It reads your PRD, then challenges it against your repo's existing domain model and documented decisions. It will:

- Push back on ambiguous terms ("you said 'user' — is that an authenticated account, a guest, or both?")
- Ask which existing module is the source of truth for a concept
- Force decisions about edge cases the PRD glossed over
- Write `CONTEXT.md` (the domain glossary) and ADRs (`docs/adr/NNNN-*.md`) inline as decisions crystallise

The output is durable docs your future self and the slice phase can both rely on. The Pokedex PRD opens with:

> This spec is the synthesis of a `/grill-with-docs` session. Two artifacts capture the locked-in language and rationale and **MUST** be read before implementation: `CONTEXT.md` … and `docs/adr/0001-base-species-only.md` …

That's not narrative filler — that's the slice subagent being told exactly which files to read so it doesn't reinvent terminology.

### Step 3 — `/clanker` runs `slice` as Phase 1, which produces the tickets

This is where tickets are actually created. The `slice` skill (Phase 1 of clanker, but also runnable standalone via `/slice`) reads the PRD + any CONTEXT.md + ADRs and emits 3–6 markdown files under `docs/tickets/`. Each ticket is:

- **Vertically scoped** — it ships an end-to-end thin slice (UI + state + route + e2e test), not a horizontal layer.
- **Independently shippable** — passes `pnpm verify` on its own; later tickets build on earlier ones but don't *require* them mid-flight.
- **TDD-checklist-shaped** — the body is a list of unchecked boxes (`- [ ]`) that `ralph` ticks one at a time.

You can run `/slice` directly if you only want the tickets (e.g. to hand-implement them yourself), or let `/clanker` invoke it as Phase 1 of the full AFK pipeline.

### Where each kind of doc lives

| Doc | Created by | Path | Lifespan |
|---|---|---|---|
| PRD | `/spec` (or human) | `docs/prd-<slug>.md` or `specs/<slug>.md` | until feature ships, then archive |
| Domain glossary | `/grill-with-docs` | `CONTEXT.md` | forever — code uses these terms verbatim |
| ADR | `/grill-with-docs` | `docs/adr/NNNN-*.md` | forever — append-only |
| Ticket | `/slice` (Phase 1 of `/clanker`) | `docs/tickets/NN-<slug>.md` | until the ticket's boxes are all ticked |
| QA report | `/qa` (Phase 4 of `/clanker`) | `qa/<slug>.md` | forever — committed alongside the PR |

---

## Worked example: Pokedex MVP

### Input

A single PRD at `specs/pokedex-mvp.md` — 206 lines specifying:
- A read-only Pokedex SPA (list + detail page, no auth, no caching)
- Domain types (Slug, DisplayName, BaseStats, etc.) with TS shapes
- PokeAPI endpoints to call and their expected response shapes
- Acceptance criteria split into one golden path + two negative paths
- A suggested 5-slice breakdown (advisory; final call is `/slice`'s)

The PRD also linked to a `CONTEXT.md` glossary and three ADRs from a prior `/grill-with-docs` session — domain knowledge the implementer needed to share verbatim with code/tests.

### Pre-flight (orchestrator, inline)

1. **PRD path:** `specs/pokedex-mvp.md` ✓ — slug = `pokedex-mvp`
2. **Git state:** on `main`, asked for a branch name → user picked `feat/pokedex` → branch already existed with prior work → asked again → user chose "fresh branch" → created `feat/pokedex-v2` from `main`
3. **Dependencies:** `node_modules` present ✓
4. **gh auth:** `gh auth status` OK ✓
5. **`.gitignore`:** appended `.clanker/`, committed as `chore: ignore clanker scratch dir`
6. **Baseline tests:** `pnpm test:unit --run` → no tests but exit 0; `pnpm test:e2e` → 3 passed → wrote `.clanker/baseline.md`:
   ```
   unit: PASS
   e2e: PASS
   commit: 95673fe
   ```
7. **Context snapshot:** concatenated `CLAUDE.md` + `docs/architecture.md` + `docs/conventions.md` + `docs/testing.md` + `docs/quality-pipeline.md` into `.clanker/context.md` (314 lines)

The "stop and ask before doing anything destructive" rule was load-bearing here: the orchestrator found pre-existing `feat/pokedex` work and refused to touch it without explicit user confirmation.

### Phase 1 — slice

**Dispatched:** one general-purpose subagent with the slim prompt above.

**Returned (the orchestrator only sees this):**
```
Slices written: 5
- 01-pokemon-index-bare-list.md — Cold-load `/` shows a responsive grid …
- 02-name-search.md — Typing in the search input filters the grid …
- 03-load-more-pagination.md — Clicking "Load More" appends the next 24 …
- 04-detail-page-core.md — `/pokemon/:slug` renders artwork, types, …
- 05-stat-bars-and-type-matchups.md — Detail page adds accessible stat bars …
Integration slice: yes, slice 05
First slice to run: 01-pokemon-index-bare-list.md
```

**On disk:** 5 files in `docs/tickets/`, each with its own TDD checklist. The orchestrator committed them as `docs(pokedex): slice PRD into 5 tickets`.

**Token usage:** 38.5k total / 13 tool calls / 135s wall clock.

### Phase 2 — ralph (5× sequential, one subagent each)

Each ticket got its own fresh subagent. Ralph's job per ticket: red → green → refactor → tick → commit, repeated until every checkbox is ticked.

| Ticket | Boxes | Commits | Wall clock | Notable |
|---|---|---|---|---|
| 01 | 5/5 | 10 | 559s | textbook TDD: 2 commits per task (feat + tick chore) |
| 02 | 4/4 | 8 | 816s | introduced URL-synced search; also surfaced two `simplify` notes |
| 03 | 4/4 | 6 | 343s | added `visibleCount` + Load More button |
| 04 | 5/5 | **1** | 700s | **deviated** — squashed all work into one commit, not per-iteration |
| 05 | 7/7 | 7 | 549s | biggest slice: type matchup table, StatBar, e2e golden path |

**Observation: ticket 04 deviated from the "one iteration per commit" ideal** (1 commit for 5 boxes vs. the expected ~10). The orchestrator caught this and **explicitly verified the disk state** before continuing — boxes were ticked, working tree clean, `pnpm verify` green, so it proceeded. The skill's gate is "all boxes ticked", not "N commits", so disk-truth wins.

Throughout, ralph appended to `.clanker/simplify-notes.md` whenever it spotted an out-of-scope offender (e.g., unused scaffold `counter.ts`, duplicated `capitalise` across three files, `playwright.config.ts` using `npm` instead of `pnpm`). These notes biased the next phase.

### Phase 3 — simplify

**Dispatched** with default scope (branch). Read `.clanker/simplify-notes.md` to pick offenders.

**Returned:** 8 refactor commits, each fixing one offender, each leaving tests green:
1. delete unused `counter.ts` scaffold store
2. switch `playwright.config.ts` to `pnpm` scripts (caught by ralph note from slice 01)
3. skip `vue-devtools` plugin under Vitest (root-causes a hack from slice 02)
4. type `vi.fn` fetch mocks to satisfy oxlint
5. extract `stubPokeapi` helper from PokedexListView spec
6. extract `paddedPokedexId` helper (used by card + detail header)
7. consolidate `capitalise` into `displayName` module
8. rename `usePokemonArtwork` → `usePokemonCardData` (composable now exposes types too)

**Spotted but skipped** (returned in the Output block for follow-up tickets): extract `TypeMatchupSummary.vue` child, add `scripts/generate-type-matchups.ts` to a tsconfig.

### Phase 4 — qa

**Dispatched** with slug `pokedex-mvp`. The subagent spins up the dev server, drives Playwright through the PRD's acceptance criteria, screenshots every state, writes a markdown report, and commits it all itself.

**Returned:**
```
Report: qa/pokedex-mvp.md
Happy: PASS
Negatives: PASS · PASS
Tests written: e2e/qa-pokedex-mvp.spec.ts
Screenshots: qa/screenshots/pokedex-mvp-*.png (6)
Committed: bce3f30
PR posture: ready
```

The orchestrator verified `git status --porcelain` was empty (GATE 4) before dispatching review.

### Phase 5 — review

**Dispatched** with the branch + qa report. Non-interactive: push, open PR via `gh`, mark draft if any qa flow failed (none did).

**Returned:**
```
Branch: feat/pokedex-v2
Pushed: yes
PR: https://github.com/alexopotto/vue-project/pull/2
Posture: ready
QA: happy PASS · negatives PASS · PASS
Commits: 46
```

### Final ledger

```
Pipeline complete.
PRD:       specs/pokedex-mvp.md   (input)
Baseline:  .clanker/baseline.md (unit/e2e PASS @ 95673fe)
Slices:    5 tickets, all boxes ticked: yes
Refactors: 8 commits
QA:        qa/pokedex-mvp.md — happy PASS · negatives PASS · PASS
PR:        https://github.com/alexopotto/vue-project/pull/2  (posture: ready)
```

44 commits on the branch. Orchestrator context still at ~6% after the entire run — the slim-prompt + on-disk-handoff pattern paid for itself.

---

## How to use it yourself

### Prerequisites

1. **A PRD.** Write one by hand or use `/spec` (the interview-driven generator). It must live at a path you can pass to `/clanker`.
2. **A clean repo.** Pre-flight will refuse to run if baseline `pnpm test:unit --run` or `pnpm test:e2e` are red on the base state.
3. **Playwright browsers installed.** If you've never run e2e here: `pnpm test:e2e:install` once.
4. **`gh` authenticated.** Phase 5 falls back to printing the PR body if `gh auth status` fails.

### Invocation

```
/clanker specs/pokedex-mvp.md
```

The orchestrator will ask once for a branch name (defaults to `feat/<slug>`) and then go AFK. Plan for ~30–60 minutes of wall clock for a 5-slice feature; this run was ~50 minutes end-to-end across all phases.

### When *not* to use it

- The change is one file and one test — no slicing needed, just edit.
- The PRD doesn't exist yet — run `/spec` first.
- The baseline is red — fix the reds first, the gate exists for a reason.
- You want a refactor-only PR — skip the pipeline and use `/simplify` directly.

---

## What we observed

**The framework's value is the gates, not the agents.** Any of the five phases could be done by a human or a different agent. What makes the pipeline reliable is that each gate forces a hard checkpoint: tickets exist, all boxes ticked, working tree clean, qa passed. When ticket 04 cut corners and committed everything at once, the gate said "boxes ticked → proceed" — because that's what the gate actually checks. The gate is the contract; the agent is the implementation.

**Slim prompts + on-disk handoff = cheap orchestration.** The orchestrator never reads the PRD itself, never sees the ticket contents, never reads the implementation code. It just reads the Output blocks (a few dozen tokens each) and runs `git status`. That's why a single orchestrator session can drive a 44-commit feature without ever pressing against its context limit, regardless of which agent model is doing the driving.

**Trust but verify, especially after agents.** "Trust but verify" is in this repo's CLAUDE.md for a reason. The agent's summary describes what it *intended* to do; disk describes what it *did*. When ticket 04 reported 1 commit, the orchestrator checked disk before proceeding. Always check disk.

**Pre-flight matters as much as the phases.** Most of the user-facing decisions happen before any phase runs: branch name, what to do about pre-existing branches, whether dependencies are installed. Getting those right means the rest can run unattended.
