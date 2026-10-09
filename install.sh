#!/usr/bin/env bash
# Install the superreview skill and its three reviewer agents into a Claude Code config dir.
#
#   ./install.sh              # installs into ~/.claude
#   ./install.sh /path/.claude
#
# Existing files at the destination are overwritten. Nothing else in the config dir is touched.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${1:-$HOME/.claude}"

agents=(
  superreview-correctness-security-subagent.md
  superreview-code-quality-subagent.md
  code-review.md
)

mkdir -p "$target/skills" "$target/agents"

rm -rf "$target/skills/superreview"
cp -R "$repo_dir/skills/superreview" "$target/skills/superreview"
echo "installed $target/skills/superreview"

for agent in "${agents[@]}"; do
  cp "$repo_dir/agents/$agent" "$target/agents/$agent"
  echo "installed $target/agents/$agent"
done

chmod +x "$target/skills/superreview/scripts/"*.sh

bash "$target/skills/superreview/scripts/validate-static-review.sh"
