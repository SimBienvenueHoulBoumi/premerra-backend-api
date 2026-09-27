#!/usr/bin/env bash
# Titre de PR déduit des commits d'une plage : celui qui porte l'impact de version le plus fort.
# En squash, seul ce titre arrive sur develop : il décide de la version (scripts/next-version.sh).
#   ./scripts/pr-title.sh <base> [head]   → ex. ./scripts/pr-title.sh origin/develop HEAD
# Utilisé par scripts/pr.sh et par le check « conventions » (PR redirigée).
set -e

range="$1..${2:-HEAD}"
subjects=$(git log --no-merges --reverse --format=%s "$range")
[ -n "$subjects" ] || { echo "✖ Aucun commit dans $range." >&2; exit 1; }

title=$(printf '%s\n' "$subjects" | grep -m1 -E '^[a-z]+(\([a-z0-9-]+\))?!: ' \
     || printf '%s\n' "$subjects" | grep -m1 -E '^feat(\([a-z0-9-]+\))?: ' \
     || printf '%s\n' "$subjects" | grep -m1 -E '^(fix|perf)(\([a-z0-9-]+\))?: ' \
     || printf '%s\n' "$subjects" | head -1)

# Pied BREAKING CHANGE dans un commit : le titre doit porter le « ! » pour survivre au squash
if git log --no-merges --format=%b "$range" | grep -qE '^BREAKING[ -]CHANGE: ' \
   && ! printf '%s' "$title" | grep -qE '^[a-z]+(\([a-z0-9-]+\))?!: '; then
  title=$(printf '%s' "$title" | sed -E 's/^([a-z]+(\([a-z0-9-]+\))?): /\1!: /')
fi

echo "$title"
