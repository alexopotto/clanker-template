# Slice ticket template

Write each slice to `docs/tickets/NN-<kebab-slug>.md` (NN = `01`, `02`, …).

```markdown
# Slice NN: <Title>

## Goal
<one sentence — the observable outcome a user can verify>

## Scope (in)
- <bullet — what this slice owns>

## Scope (out)
- <bullet — what this slice explicitly does NOT do, even if related>

## Tasks
- [ ] Write failing Playwright e2e in `e2e/<slug>.spec.ts` asserting <observable behaviour>
- [ ] Implement <component/store/route>
- [ ] Wire <data flow>
- [ ] Make the e2e green
- [ ] Refactor while green (within this slice's files only)

## Acceptance
- <copy-paste-able, observable; matches the PRD's acceptance criteria for this strip>

Execution note: test-first
```

The last line is a lightweight signal `ralph` honours during execution.
