#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
skills="$(cd "$here/.." && pwd)"
root="$(cd "$here/../../.." && pwd)"
cd "$root"

found=0
shopt -s nullglob
for d in "$skills"/*/; do
  name="$(basename "$d")"
  if [[ "$name" == scripts ]]; then
    continue
  fi
  skillfile="${d}SKILL.md"
  if [[ ! -f "$skillfile" ]]; then
    echo "ERROR: missing ${skillfile}" >&2
    exit 1
  fi
  found=1
done

if [[ "$found" -eq 0 ]]; then
  echo "ERROR: no skills under ${skills}" >&2
  exit 1
fi

npx --yes skills add "$skills" -a cursor -a codex -a claude-code -g -y --skill '*'
