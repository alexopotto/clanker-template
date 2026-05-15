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
CLAUDE.md                        repo-level conventions (you fill in your stack)
```

---

## Quickstart

1. **Adapt `CLAUDE.md`** to your stack. Fill in:
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

Tested on Claude Code. The skills themselves contain no Claude-specific assumptions beyond the file paths — adopters on other harnesses (Codex, Copilot, Cursor, etc.) may need to adjust the `.claude/skills/` path references and the dispatch primitive.

---

## How to use this as a starter

**Option A — Clone and build on top.**
```sh
git clone <this-repo> my-new-project
cd my-new-project
# edit CLAUDE.md for your stack, then start writing PRDs
```

**Option B — Copy the skills into an existing repo.**
```sh
cd existing-repo
cp -R /path/to/clanker-template/.agents .
ln -s ../.agents/skills .claude/skills
# adapt your existing CLAUDE.md to add the conventions this pipeline expects
```

---

## License + provenance

The "ralph loop" name comes from Geoffrey Huntley's post: <https://ghuntley.com/ralph/>. The pipeline shape (slice → ralph → simplify → qa → review) was developed in-house — feel free to fork, adapt, or rip it apart.

See `docs/clanker-walkthrough.md` for the full design rationale and a real worked example.
