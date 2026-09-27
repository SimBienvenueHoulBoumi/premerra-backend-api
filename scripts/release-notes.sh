#!/usr/bin/env bash
# Notes de version en Markdown, d'après les commits depuis le dernier tag vX.Y.Z.
# Utilisées pour le corps de la PR de release et pour la GitHub Release.
#   ./scripts/release-notes.sh [ref]
set -e

ref=${1:-HEAD}
last=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)
range=${last:+$last..}$ref
tab=$(printf '\t')
commits=$(git log --no-merges --reverse --format="%s$tab%h" "$range")
breaking_body=$(git log --no-merges --format=%h -E --grep='^BREAKING[ -]CHANGE: ' "$range")

section() {  # titre, motif sur le sujet
  lines=$(printf '%s\n' "$commits" | grep -E "$2" | sed -E "s/^(.*)$tab(.*)$/- \1 (\2)/") || true
  [ -z "$lines" ] || printf '### %s\n\n%s\n\n' "$1" "$lines"
}

breaking=$(printf '%s\n' "$commits" | while IFS="$tab" read -r s h; do
  [ -n "$s" ] || continue
  if printf '%s' "$s" | grep -qE '^[a-z]+(\([a-z0-9-]+\))?!: ' || printf '%s\n' "$breaking_body" | grep -qx "$h"; then
    echo "- $s ($h)"
  fi
done)
[ -z "$breaking" ] || printf '### ⚠ Changements cassants\n\n%s\n\n' "$breaking"

section "Nouveautés"   '^feat(\([a-z0-9-]+\))?!?: '
section "Corrections"  '^(fix|perf)(\([a-z0-9-]+\))?!?: '
section "Maintenance"  '^(build|ci|chore|docs|refactor|style|test|revert)(\([a-z0-9-]+\))?!?: '

echo "_Depuis ${last:-le début du projet}._"
