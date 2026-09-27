#!/usr/bin/env bash
# Prochaine version d'après les commits depuis le dernier tag vX.Y.Z (Conventional Commits).
# Source unique pour tag.yml (version publiée) et release-pr.yml (version annoncée).
#   ./scripts/next-version.sh [ref]   → affiche X.Y.Z, ou rien s'il n'y a rien à publier
#   type! ou BREAKING CHANGE → MAJOR ; feat → MINOR ; fix/perf → PATCH ; autres types → rien
set -e

ref=${1:-HEAD}
# Tag le plus élevé, pas le plus proche : develop ne contient pas le merge commit tagué sur main
last=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)
range=${last:+$last..}$ref
subjects=$(git log --no-merges --format=%s "$range")

if printf '%s\n' "$subjects" | grep -qE '^[a-z]+(\([a-z0-9-]+\))?!: ' \
   || git log --no-merges --format=%b "$range" | grep -qE '^BREAKING[ -]CHANGE: '; then
  bump=major
elif printf '%s\n' "$subjects" | grep -qE '^feat(\([a-z0-9-]+\))?: '; then
  bump=minor
elif printf '%s\n' "$subjects" | grep -qE '^(fix|perf)(\([a-z0-9-]+\))?: '; then
  bump=patch
else
  echo "Aucun feat/fix/perf/breaking depuis ${last:-le début} : pas de nouvelle version." >&2
  exit 0
fi

IFS=. read -r major minor patch <<< "${last#v}"
major=${major:-0}; minor=${minor:-0}; patch=${patch:-0}
case "$bump" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac

echo "$bump depuis ${last:-aucun tag}" >&2
echo "$major.$minor.$patch"
