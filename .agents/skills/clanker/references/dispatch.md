# Harness dispatch reference

The orchestrator **defaults to subagent dispatch** for every AFK phase (slice, ralph, simplify, qa, review) — this is how the pipeline keeps each phase's transcript out of the orchestrator's context, and how ralph gets a clean room per ticket. Inline is the fallback when the harness lacks a subagent primitive, or for HITL phases (pre-flight, spec) which must talk to the user.

When `clanker/SKILL.md` says *"dispatch the X skill as a subagent"*, look up the row matching your current harness. If your harness is not listed, fall back to inline execution.

## Table A — Subagent dispatch (default for AFK phases)

| Harness | Primitive | Notes |
|---|---|---|
| **Claude Code** | `Task` / `Agent` tool. Pass the contents of `../<phase>/SKILL.md` plus the phase input as the prompt. `subagent_type: "general-purpose"` works without registering a custom agent. | Permission mode inherits from session. |
| **Codex** | `spawn_agent(prompt: "<SKILL.md body + input>")`. | Pass `model: "gpt-5-mini"` for non-core workers if cost matters. |
| **VS Code Copilot** | `Task` tool, same shape as Claude Code. | If the Copilot version in use doesn't expose a Task tool, use the inline fallback. |
| **Cursor** | Background-task / sub-task primitive. | Cursor docs change frequently; if unsure, inline. |
| **Fallback (any harness w/o subtasks)** | Read `../<phase>/SKILL.md` and execute its workflow inline in the current session. | Loses context isolation. Pipeline still produces the same on-disk artifacts. |

## Table B — User questions (HITL phases)

Used by the `spec` skill and the orchestrator's pre-flight when the human must answer.

| Harness | Primitive | Notes |
|---|---|---|
| **Claude Code** | `AskUserQuestion` — load schema first via `ToolSearch` with `select:AskUserQuestion`, then invoke. | One question per turn. Prefer single-select multiple choice (3–4 options). |
| **Codex** | `request_user_input(prompt: "...", options: [...])`. | Same one-question-per-turn discipline. |
| **VS Code Copilot** | Plain chat prompt — Copilot has no dedicated blocking-question tool. Write the question as the next chat message and wait. | The orchestrator waits for the human's next message before proceeding. |
| **Cursor** | Chat prompt. | Same as Copilot. |
| **Fallback** | Numbered options in chat (`1) … 2) … 3) …`) and wait for the user to reply with a number. | Never silently skip the question. |

## Dispatch hard rules

- CRITICAL: **Inline vs subtask must not change the artifact.** Whichever path you take, the on-disk output (`docs/prd-*`, `docs/tickets/*`, `qa/*`) is identical. If the subtask path produces different results, treat that as a bug in the prompt.
- CRITICAL: **Do not split a single phase across multiple primitives.** One dispatch per phase step.
- IMPORTANT: HITL phases must use Table B. Don't paraphrase user input — wait for it.
- IMPORTANT: The orchestrator's GATE checkpoints assume the phase's structured Output block. Whichever primitive you use, return that block verbatim to the caller.
