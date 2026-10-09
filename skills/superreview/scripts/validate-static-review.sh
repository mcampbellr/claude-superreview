#!/usr/bin/env bash
set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
claude_dir="$(cd "$skill_dir/../.." && pwd)"

required=(
  "$skill_dir/SKILL.md"
  "$skill_dir/references/review-policy.md"
  "$claude_dir/agents/superreview-correctness-security-subagent.md"
  "$claude_dir/agents/superreview-code-quality-subagent.md"
  "$claude_dir/agents/code-review.md"
)
for file in "${required[@]}"; do
  [[ -f "$file" ]] || { echo "missing $file" >&2; exit 1; }
done

for agent in "${required[@]:2}"; do
  grep -q 'references/review-policy.md' "$agent" || {
    echo "agent does not reference canonical policy: $agent" >&2
    exit 1
  }
  grep -q 'Do not run tests, lint, typecheck, builds' "$agent" || {
    echo "agent lacks static-only boundary: $agent" >&2
    exit 1
  }
  tools_line="$(grep '^tools:' "$agent")"
  if grep -Eq '(^| )Bash($| )|Bash\((npm|pnpm|yarn|bun|jest|vitest|go test|cargo|make|docker)|(^| )(Write|Edit)( |$)|Bash\(gh \*\)|Bash\(glab \*\)' <<<"$tools_line"; then
    echo "agent exposes a dynamic or mutating tool: $agent" >&2
    exit 1
  fi
done

grep -q 'do not execute it in Superreview' "$skill_dir/SKILL.md"
grep -q 'Equivalent requests collapse to one entry' "$skill_dir/references/review-policy.md"
echo "superreview static policy validation passed"
