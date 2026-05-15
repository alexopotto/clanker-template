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

Open your project in Claude Code, Codex, Copilot, Cursor, or any agent that can run shell, and paste this prompt:

````markdown
Install the clanker skill pack from https://github.com/alexopotto/clanker-template
into this repository. Follow these steps exactly and ask before any destructive action.

1. Shallow-clone into a temp dir:
   git clone --depth 1 https://github.com/alexopotto/clanker-template /tmp/clanker-install

2. Detect which agent you are by the path conventions you read from:
   - `.claude/skills/` → Claude Code
   - `.agents/skills/` → Codex / Copilot / Cursor / other
   Skills get copied to `.agents/skills/` either way (it's the cross-agent path);
   only the Claude Code symlink differs.

3. Compatibility check — read the **target** repo's AGENTS.md (or CLAUDE.md) if
   present. Compare against the assumptions baked into the cloned skills
   (pnpm, Vitest, Playwright, Vue 3 layout — grep them in
   /tmp/clanker-install/.agents/skills/). List any mismatches (package
   manager, test runner, e2e tool) and tell me before copying. If no
   AGENTS.md exists in the target, copy /tmp/clanker-install/AGENTS.md over
   and flag it as "needs filling in".

4. Copy `/tmp/clanker-install/.agents/` into the current repo root. If
   `.agents/` already exists, list overlapping files and ask before
   overwriting any of them.

5. If I'm using Claude Code, create the symlink:
   mkdir -p .claude && ln -s ../.agents/skills .claude/skills
   (skip if `.claude/skills` already exists, or if I'm not on Claude Code.)

6. Delete /tmp/clanker-install.

7. Report: which skills were copied, which path the agent will read them from,
   and any AGENTS.md mismatches I need to resolve before running `/clanker`.

Do not modify any other files. Do not edit my AGENTS.md without asking.
````

The agent will halt before overwriting anything and surface stack mismatches you need to resolve.

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
