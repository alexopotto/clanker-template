# PR body template

Pass through `gh pr create --body` via HEREDOC. Substitute placeholders; keep section names verbatim so reviewers always know where to look.

```markdown
## Summary
<1–3 bullets — what changed and why, in plain language>

## Slices shipped
- 01-<slug>: <one line>
- 02-<slug>: <one line>
- …

## QA
- Happy path: PASS | FAIL
- Negatives: PASS | FAIL · PASS | FAIL
- Report: qa/<slug>.md
- Screenshots: qa/screenshots/

## Refactors
- <commit subjects from simplify>

## Test plan for reviewer
- [ ] Pull the branch and run the documented local app/service command from `AGENTS.md`
- [ ] Run the documented verify command and any e2e/smoke command from `AGENTS.md`
- [ ] Open the screenshots in `qa/screenshots/` and confirm they match expectations
- [ ] <feature-specific check>

## Notes
<extra notes from the user, or "—">
```
