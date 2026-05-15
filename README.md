# Clanker — AFK coding pipeline skill pack

A reusable set of agent skills for driving a written spec (PRD) to a merge-ready PR with minimal human input. Drop into any repo, adapt the verification gates to your stack, and ship.

```
PRD ──► slice ──► ralph (×N) ──► simplify ──► qa ──► review ──► PR
        (P1)      (P2)            (P3)         (P4)   (P5)
```

This repo contains **only the skills** — no application code. Use it as a starting point for your own project, or copy `.agents/skills/` into an existing repo.

> 📖 **Read [`docs/clanker-walkthrough.md`](docs/clanker-walkthrough.md) first** — it's a 250-line concept doc + worked example. It explains every term in this README.

---

## What you get

```
.agents/skills/                  the 9 skills (markdown only, no code)
├── clanker/                     orchestrator — runs the 5-phase pipeline
├── spec/                        interview → PRD
├── grill-with-docs/             stress-test PRD against domain model
├── slice/                       PRD → vertical tickets
├── ralph/                       ticket → green TDD commits
├── simplify/                    refactor pass
├── qa/                          Playwright happy + negatives
├── review/                      push + open PR
└── write-a-skill/               meta — author new skills

.claude/skills                   symlink to .agents/skills (Claude Code convention)
docs/                            where the pipeline writes tickets, ADRs, etc.
specs/                           where PRDs live
qa/                              where the qa phase writes its reports
AGENTS.md                        repo-level conventions (you fill in your stack)
CLAUDE.md                        symlink to AGENTS.md (so Claude Code finds it)
```

---

## Quickstart

1. **Adapt `AGENTS.md`** to your stack. Fill in:
   - Your package manager (`pnpm` / `npm` / `bun` / `yarn`)
   - Your verify command (the one that runs type-check + lint + tests)
   - Your test runner (Vitest / Jest / Bun test / etc.)
   - Your e2e tool (Playwright / Cypress / etc.)
2. **Grep the skills for stack-specific commands.** The skills currently reference `pnpm verify`, `pnpm test:e2e`, `oxlint`, and a Vue 3 project layout. Find-and-replace:
   ```sh
   grep -rn "pnpm verify\|pnpm test\|oxlint\|vitest\|playwright" .agents/skills/
   ```
   Replace with your stack's equivalent. If your team also uses pnpm + Vitest + Playwright, you mostly don't need to change anything.
3. **Write your first PRD.** Either invoke `/spec` (interview-driven) or hand-write a markdown file under `specs/`.
4. **Run the pipeline:** `/clanker specs/<your-prd>.md`

---

## What this requires of your harness

The framework is harness-agnostic but assumes these primitives exist:

- **Slash-command-style skill invocation** — the user can type `/clanker`, `/spec`, etc. and the harness reads `.claude/skills/<name>/SKILL.md` (or your harness's equivalent path).
- **Subagent dispatch** — the orchestrator can spawn a fresh agent with its own context (Task tool, agent spawn, fork — whatever your harness calls it).
- **File read/write + shell** — agents can read/write markdown, run shell commands, and execute `git` / `gh`.
- **A user-question primitive** for pre-flight (branch name, harness hint). Falls back to chat if your harness lacks one.

The skills live under `.agents/skills/` (the convention Codex / VS Code Copilot read) and `.claude/skills/` is a symlink to the same directory (the path Claude Code reads). So Claude Code, Codex, and VS Code Copilot all work out of the box with no path edits. 

---

## How to install

**Option A — Ask your AI agent to install it (recommended).**

Open your project in Claude Code, Codex, Copilot, Cursor, or any agent that can run shell, and paste this prompt. It does two passes: **install + adapt**, then **audit the setup** (package manager, AGENTS.md quality, docs scaffolding, feedback loop) and propose fixes one at a time.

````markdown
Install the clanker skill pack from https://github.com/alexopotto/clanker-template
into this repository, then audit my setup so the agent feedback loops actually work.
Adapt the skills to my stack and conventions BEFORE copying them in. Follow these
steps exactly and ask before any destructive action.

## Phase 1 — Install & adapt

1. Shallow-clone into a temp dir:
   git clone --depth 1 https://github.com/alexopotto/clanker-template /tmp/clanker-install

2. Detect which agent you are by the path conventions you read from:
   - `.claude/skills/` → Claude Code
   - `.agents/skills/` → Codex / Copilot / Cursor / other
   Skills get copied to `.agents/skills/` either way (cross-agent path);
   only the Claude Code symlink differs.

3. Inspect the target repo to learn its stack and conventions:
   - Package manager: which lockfile exists (`pnpm-lock.yaml` / `package-lock.json`
     / `yarn.lock` / `bun.lock`).
   - Unit test runner: devDependencies in `package.json` (vitest / jest / bun test
     / mocha / none).
   - E2E tool: devDependencies (playwright / cypress / none).
   - Linter: devDependencies (oxlint / eslint / biome / none).
   - Verify command: scripts in `package.json` (look for `verify`, `lint`,
     `typecheck`, `test`).
   - Framework: devDependencies (vue / react / svelte / none).
   - Commit convention: run `git log --pretty=%s -50` and classify the style as
     conventional commits (`type(scope): subject`), ticket-prefixed
     (`JIRA-123:`), or freeform.

4. Read the target's AGENTS.md / CLAUDE.md if present. If AGENTS.md says one
   thing and the manifest says another, trust the manifest and flag the
   conflict for me. If no AGENTS.md exists, copy
   `/tmp/clanker-install/AGENTS.md` over and tell me it needs filling in.

5. Adapt the skills in `/tmp/clanker-install/.agents/skills/` **before**
   copying — they should reference only tools that exist in my repo:
   - Find-and-replace baked-in commands across all skill files:
     `pnpm verify` → my verify command, `pnpm test:e2e` → my e2e command,
     `pnpm test` → my unit-test command, `oxlint` → my linter, `pnpm` →
     my package manager, `vitest` / `playwright` → my equivalents.
   - **If no e2e tool exists:** delete the `qa/` skill folder and remove
     the QA phase from the `clanker/` orchestrator skill. Tell me what
     you stripped.
   - **If no unit test runner exists:** replace the verify step in the
     `ralph/` skill with a `# manual gate — replace with your verify command`
     placeholder. Tell me.
   - **If commits follow conventional-commits style:** append one line to
     the `ralph/` skill's commit step telling it to use `<type>: <subject>`
     prefixes. Otherwise leave the commit style freeform.

6. Copy the adapted `/tmp/clanker-install/.agents/` into the current repo
   root. If `.agents/` already exists, list overlapping files and ask
   before overwriting.

7. If I'm using Claude Code, create the symlink:
   mkdir -p .claude && ln -s ../.agents/skills .claude/skills
   (skip if `.claude/skills` already exists, or if I'm not on Claude Code.)

8. Delete /tmp/clanker-install.

## Phase 2 — Audit the setup

Now look at what's already here and find anything that will make the agent
loops unreliable. Collect findings first, then walk through them with me one
at a time — for each finding: state the problem, propose the fix, wait for my
go-ahead before editing. Do not auto-fix.

Check each of these dimensions:

A. **Package manager consistency** (one PM, used everywhere)
   - More than one lockfile present? (e.g. `pnpm-lock.yaml` and `package-lock.json`
     both exist — pick one, propose deleting the others.)
   - `packageManager` field in `package.json` missing or disagreeing with the lockfile?
   - Scripts in `package.json` invoke a different PM than the lockfile implies
     (e.g. `"test": "npm run ..."` in a pnpm repo)?
   - README / AGENTS.md / CI workflows reference a PM that doesn't match the lockfile?

B. **Feedback loop sanity** (the gate must actually exist and exit 0)
   - Does the verify command from AGENTS.md exist as a script in `package.json`?
   - Run it. Does it exit 0 on a clean tree? If not, capture the first failing
     step (typecheck / lint / unit) — that's the loop the agent will get stuck on.
   - Do unit tests exist at all? Run the test command and confirm the runner
     finds and executes at least one test. **Zero tests is a critical finding** —
     the ralph skill's red→green loop has nothing to drive against.
   - E2E missing is a **warning, not a blocker** — clanker can still ship slices
     without it, just without the qa phase.
   - If there is no feedback loop whatsoever (no verify, no tests, no typecheck),
     flag this as the highest-priority finding. Propose the minimum viable loop
     for the detected stack (e.g. `tsc --noEmit && <linter> && <test runner>`).

C. **AGENTS.md / CLAUDE.md quality**
   - Any `<placeholder>` text still unfilled in the Stack or Commands sections?
   - Do the commands listed actually exist as scripts in `package.json`?
   - Does the Stack line match what the manifest says (framework, test runner,
     PM)? Flag every mismatch.
   - Are the Hard Rules still the generic defaults, or has the user customized
     them? (Don't propose changes here — just note whether they look reviewed.)

D. **Docs scaffolding** (referenced by AGENTS.md → must exist or be stubbed)
   - For each of `docs/architecture.md`, `docs/conventions.md`, `docs/testing.md`,
     `docs/quality-pipeline.md`: does the file exist? If not, propose creating a
     short stub (one heading + a one-line "fill this in" placeholder) so the
     AGENTS.md links don't 404. Ask before creating each.

## Phase 3 — Report

After Phase 1 and Phase 2 walk-throughs, give me a final summary:
- Detected stack and commit convention.
- Which skills were copied, which were stripped/modified and why.
- Every audit finding (A–D), what was fixed, what was deferred, what I declined.
- The single most important thing left for me to do before running `/clanker`.

Do not modify any other files. Do not edit my AGENTS.md without asking.
````

The agent will halt before overwriting anything, surface stack mismatches, and walk you through setup gaps one at a time before you run `/clanker`.

**Option B — Clone the whole template.**
```sh
git clone https://github.com/alexopotto/clanker-template my-new-project
cd my-new-project
# edit AGENTS.md for your stack, then start writing PRDs
```

**Option C — Copy the skills manually.**
```sh
cd existing-repo
cp -R /path/to/clanker-template/.agents .
ln -s ../.agents/skills .claude/skills
# add (or update) AGENTS.md with the conventions this pipeline expects
```

---

## License + provenance

The "ralph loop" name comes from Geoffrey Huntley's post: <https://ghuntley.com/ralph/>. The pipeline shape (slice → ralph → simplify → qa → review) was developed in-house — feel free to fork, adapt, or rip it apart.

See `docs/clanker-walkthrough.md` for the full design rationale and a real worked example.
