#!/usr/bin/env sh
set -eu

failures=0
warnings=0

warn() {
  warnings=$((warnings + 1))
  printf 'WARN: %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$1"
}

pass() {
  printf 'PASS: %s\n' "$1"
}

exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

printf 'Agent setup doctor\n'
printf '==================\n'

if exists AGENTS.md; then
  pass 'AGENTS.md exists'
else
  fail 'AGENTS.md is missing'
fi

if [ -L CLAUDE.md ]; then
  target=$(readlink CLAUDE.md)
  if [ "$target" = "AGENTS.md" ]; then
    pass 'CLAUDE.md points to AGENTS.md'
  else
    warn "CLAUDE.md symlink points to $target, expected AGENTS.md"
  fi
elif exists CLAUDE.md; then
  warn 'CLAUDE.md exists but is not a symlink to AGENTS.md'
else
  warn 'CLAUDE.md is missing; Claude Code may not see AGENTS.md automatically'
fi

if [ -L .claude/skills ]; then
  target=$(readlink .claude/skills)
  if [ "$target" = "../.agents/skills" ]; then
    pass '.claude/skills points to .agents/skills'
  else
    warn ".claude/skills symlink points to $target, expected ../.agents/skills"
  fi
elif exists .claude/skills; then
  warn '.claude/skills exists but is not the expected symlink'
else
  warn '.claude/skills is missing; Claude Code skill discovery may need setup'
fi

for file in docs/agent-setup.md docs/architecture.md docs/conventions.md docs/testing.md docs/quality-pipeline.md; do
  if exists "$file"; then
    pass "$file exists"
  else
    fail "$file is missing"
  fi
done

if exists AGENTS.md; then
  if grep -Eq '(^|[| ])unset([ |]|$)|<your|<verify command>|<dev command>|<test command>|<e2e command>|<build command>' AGENTS.md; then
    warn 'AGENTS.md still contains unset command-contract values or template placeholders'
  else
    pass 'AGENTS.md command contract appears filled'
  fi
fi

if command -v grep >/dev/null 2>&1; then
  hardcoded=$(grep -RInE 'pnpm|npm run|yarn |bun |mvn |gradle |pytest|vitest|playwright|Vue|React|Svelte|Django|Spring' .agents/skills 2>/dev/null || true)
  if [ -n "$hardcoded" ]; then
    warn 'stack-specific assumptions found in .agents/skills:'
    printf '%s\n' "$hardcoded"
  else
    pass 'no obvious stack-specific assumptions found in .agents/skills'
  fi
else
  warn 'grep not available; skipped skill hardcoding scan'
fi

printf '\nSummary: %s failure(s), %s warning(s)\n' "$failures" "$warnings"

if [ "$failures" -gt 0 ]; then
  exit 1
fi
