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
- [ ] Pull the branch, run `pnpm dev`, click through the happy path
- [ ] Run `pnpm test:unit --run && pnpm test:e2e`
- [ ] Open the screenshots in `qa/screenshots/` and confirm they match expectations
- [ ] <feature-specific check>

## Notes
<extra notes from the user, or "—">
```
