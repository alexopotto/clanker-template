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
   - Your package/build tool (`npm`, `pnpm`, `Maven`, `Gradle`, `uv`, etc.)
   - Your install, dev, verify, test, e2e/smoke, and build commands
   - Your test layout and QA mode
2. **Fill in the setup docs.** Start with:
   - `docs/agent-setup.md`
   - `docs/architecture.md`
   - `docs/conventions.md`
   - `docs/testing.md`
   - `docs/quality-pipeline.md`
3. **Run the agent setup doctor:**
   ```sh
   scripts/agent-doctor.sh
   ```
   Fix every failure and review warnings before running the pipeline.
4. **Write your first PRD.** Either invoke `/spec` (interview-driven) or hand-write a markdown file under `specs/`.
5. **Run the pipeline:** `/clanker specs/<your-prd>.md`

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

Open your project in Claude Code, Codex, Copilot, Cursor, or any agent that can run shell, and paste this prompt. It does two passes: **install + document the command contract**, then **audit the setup** (package manager/build tool, AGENTS.md quality, docs scaffolding, feedback loop) and propose fixes one at a time.

````markdown
Install the clanker skill pack from https://github.com/alexopotto/clanker-template
into this repository, then audit my setup so the agent feedback loops actually work.
Install the stack-agnostic skills, then adapt AGENTS.md and docs to my stack and
conventions. Follow these steps exactly and ask before any destructive action.

## Phase 1 — Install & document

1. Shallow-clone into a temp dir:
   git clone --depth 1 https://github.com/alexopotto/clanker-template /tmp/clanker-install

2. Detect which agent you are by the path conventions you read from:
   - `.claude/skills/` → Claude Code
   - `.agents/skills/` → Codex / Copilot / Cursor / other
   Skills get copied to `.agents/skills/` either way (cross-agent path);
   only the Claude Code symlink differs.

3. Inspect the target repo to learn its stack and conventions:
   - Package/build tool: lockfiles and manifests (`package-lock.json`,
     `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`, `pom.xml`, `build.gradle`,
     `pyproject.toml`, `requirements.txt`, `go.mod`, etc.).
   - Unit/integration test runner: manifest dependencies, build plugins, or
     existing test commands.
   - E2E/smoke tool: browser e2e, API smoke, CLI smoke, library examples, or none.
   - Linter/formatter/type checker/compiler checks.
   - Verify command: manifest scripts, Makefile targets, CI workflows, or the
     smallest existing command that combines compile/lint/test.
   - Framework/runtime: detected from manifests and source layout.
   - Commit convention: run `git log --pretty=%s -50` and classify the style as
     conventional commits (`type(scope): subject`), ticket-prefixed
     (`JIRA-123:`), or freeform.

4. Read the target's AGENTS.md / CLAUDE.md if present. If AGENTS.md says one
   thing and the manifest says another, trust the manifest and flag the
   conflict for me. If no AGENTS.md exists, copy
   `/tmp/clanker-install/AGENTS.md` over and tell me it needs filling in.

5. Copy or update the setup docs from `/tmp/clanker-install/docs/`:
   - Ensure `docs/agent-setup.md`, `docs/architecture.md`,
     `docs/conventions.md`, `docs/testing.md`, and
     `docs/quality-pipeline.md` exist.
   - If a file already exists, do not overwrite it without asking.
   - Fill in the command contract in AGENTS.md and document the QA mode in
     `docs/testing.md` or `docs/quality-pipeline.md`.
   - If no e2e/smoke loop exists, document `QA disabled` with the reason instead
     of deleting the `qa/` skill.
   - If no unit test runner exists, document the missing feedback loop as the
     highest-priority setup gap.

6. Copy `/tmp/clanker-install/.agents/` and `/tmp/clanker-install/scripts/` into the current repo
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

A. **Package/build tool consistency** (one toolchain path, used everywhere)
   - More than one lockfile present? (e.g. `pnpm-lock.yaml` and `package-lock.json`
     both exist — pick one, propose deleting the others.)
   - `packageManager` field in `package.json` missing or disagreeing with the lockfile?
   - Scripts or Makefile/CI targets invoke a different tool than the manifest implies?
   - README / AGENTS.md / CI workflows reference a tool that doesn't match the detected stack?

B. **Feedback loop sanity** (the gate must actually exist and exit 0)
   - Does the verify command from AGENTS.md exist as a script, target, or executable command?
   - Run it. Does it exit 0 on a clean tree? If not, capture the first failing
     step (typecheck / lint / unit) — that's the loop the agent will get stuck on.
   - Do unit tests exist at all? Run the test command and confirm the runner
     finds and executes at least one test. **Zero tests is a critical finding** —
     the ralph skill's red→green loop has nothing to drive against.
   - E2E/smoke missing is a **warning, not a blocker** if documented as
     `QA disabled`; otherwise it is an AGENTS.md/docs gap.
   - If there is no feedback loop whatsoever (no verify, no tests, no typecheck),
     flag this as the highest-priority finding. Propose the minimum viable loop
     for the detected stack (e.g. `tsc --noEmit && <linter> && <test runner>`).

C. **AGENTS.md / CLAUDE.md quality**
   - Any `unset` or placeholder text still unfilled in the Stack or Commands sections?
   - Do the commands listed actually exist as scripts, targets, or executable commands?
   - Does the Stack line match what the manifest says (framework, test runner,
     PM)? Flag every mismatch.
   - Are the Hard Rules still the generic defaults, or has the user customized
     them? (Don't propose changes here — just note whether they look reviewed.)

D. **Docs scaffolding** (referenced by AGENTS.md → must exist or be stubbed)
   - For each of `docs/agent-setup.md`, `docs/architecture.md`,
     `docs/conventions.md`, `docs/testing.md`, and
     `docs/quality-pipeline.md`: does the file exist? If not, propose creating a
     short stub so the AGENTS.md links don't 404. Ask before creating each.

E. **Doctor check**
   - Run `scripts/agent-doctor.sh`.
   - Treat failures as setup blockers.
   - Review warnings with me one at a time.

## Phase 3 — Report

After Phase 1 and Phase 2 walk-throughs, give me a final summary:
- Detected stack and commit convention.
- Which skills were copied, which were stripped/modified and why.
- Every audit finding (A–E), what was fixed, what was deferred, what I declined.
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
