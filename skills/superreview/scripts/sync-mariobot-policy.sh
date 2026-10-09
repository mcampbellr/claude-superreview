#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 [--check] <mariobot-root>" >&2
  exit 2
}

mode=sync
if [[ "${1:-}" == "--check" ]]; then
  mode=check
  shift
fi
[[ $# -eq 1 ]] || usage

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_policy="$(cd "$script_dir/.." && pwd)/references/review-policy.md"
target_root="$1"
target_policy="$target_root/policy/review-policy.md"

[[ -f "$source_policy" ]] || { echo "missing canonical policy: $source_policy" >&2; exit 1; }

if [[ "$mode" == check ]]; then
  cmp -s "$source_policy" "$target_policy" || {
    echo "mariobot policy drift: run $0 $target_root" >&2
    exit 1
  }
  echo "mariobot policy is synchronized"
  exit 0
fi

mkdir -p "$(dirname "$target_policy")"
tmp="$(mktemp "${target_policy}.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
cp "$source_policy" "$tmp"
if [[ -f "$target_policy" ]] && cmp -s "$tmp" "$target_policy"; then
  echo "mariobot policy already synchronized"
else
  mv "$tmp" "$target_policy"
  echo "updated $target_policy"
fi
