#!/usr/bin/env bash
# Pousse la branche courante et ouvre sa Pull Request vers la bonne cible, avec un titre conforme.
# Le titre est vérifié en local (mêmes règles que la CI repogarde) avant d'atteindre GitHub.
#   ./scripts/pr.sh                          → titre déduit des commits
#   ./scripts/pr.sh "feat(auth): …"          → titre imposé
# La fusion reste manuelle.
set -e
cd "$(git rev-parse --show-toplevel)"
command -v gh >/dev/null || { echo "✖ GitHub CLI (gh) requis : https://cli.github.com" >&2; exit 1; }

branch=$(git symbolic-ref --short HEAD)
case "$branch" in
  main|develop)       echo "✖ Pas de PR depuis '$branch' : crée une branche feature/…, fix/…" >&2; exit 1 ;;
  release/*|hotfix/*) bases="main develop" ;;
  *)                  bases="develop" ;;
esac
first_base=${bases%% *}

git fetch -q origin "$first_base"
range="origin/$first_base..HEAD"
subjects=$(git log --no-merges --reverse --format=%s "$range")
[ -n "$subjects" ] || { echo "✖ Aucun commit à proposer par rapport à '$first_base'." >&2; exit 1; }

# Titre imposé, sinon celui du commit le plus impactant pour la version
title=${1:-$(./scripts/pr-title.sh "origin/$first_base" HEAD)}

# Mêmes règles que repogarde (Conventional Commits, 72 caractères)
types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
if ! printf '%s' "$title" | grep -qE "^($types)(\([a-z0-9._-]+\))?!?: .+" || [ "${#title}" -gt 72 ]; then
  echo "✖ Titre non conforme : « $title » (<type>(<scope>): <description>, 72 caractères max)" >&2
  exit 1
fi

body="$(printf '%s\n' "$subjects" | sed 's/^/- /')"

git push -u origin HEAD

for base in $bases; do
  url=$(gh pr list --head "$branch" --base "$base" --state open --json url --jq '.[0].url // empty')
  if [ -n "$url" ]; then
    echo "✔ PR déjà ouverte vers $base : $url"
  else
    gh pr create --base "$base" --head "$branch" --title "$title" --body "$body"
  fi
done
