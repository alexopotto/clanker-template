# Agent setup contract

This template is stack-agnostic. After copying it into a project, fill in
`AGENTS.md` so agents can discover the package manager, commands, test layout,
and quality gate without guessing.

## Required command contract

Every adapted project should define these values in `AGENTS.md`:

| Purpose | Requirement |
|---|---|
| Install dependencies | Exact command, or `none` for dependency-free repos |
| Start local app/service | Exact command, or `none` for libraries/packages |
| Verify before completion | Single command agents must run before claiming done |
| Unit tests | Exact command, or `none` with a reason |
| End-to-end or smoke tests | Exact command, QA mode, or `none` with a reason |
| Production build | Exact command, or `none` with a reason |

The phase skills should read this contract from `.clanker/context.md`; they
must not assume pnpm, npm, Maven, Gradle, pytest, Playwright, or any framework.

## QA modes

Pick one mode in `docs/testing.md` or `docs/quality-pipeline.md`:

| Mode | Use when | Evidence |
|---|---|---|
| Browser e2e | Web UI exists | Screenshots plus e2e output |
| API smoke | HTTP service exists | Requests, responses, and logs |
| CLI smoke | Command-line tool exists | Commands, fixture paths, and output |
| Library smoke | Public API/package exists | Example/integration output |
| QA disabled | No meaningful e2e/smoke loop exists yet | Draft PR report explaining the gap |

## Self-check

Run:

```sh
scripts/agent-doctor.sh
```

The doctor checks for broken agent symlinks, missing docs, unset command
contract values, and stack-specific command assumptions left inside skills.
