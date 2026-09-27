#!/usr/bin/env bash
# Configure le dépôt GitHub pour le workflow décrit dans CONTRIBUTING.md. À lancer une fois, par un admin.
# Idempotent : relançable sans créer de doublon (les règles sont mises à jour par leur nom).
#   ./scripts/setup-github.sh             → applique
#   ./scripts/setup-github.sh --dry-run   → affiche ce qui serait fait, sans rien modifier
#
# La relecture reste humaine : main et develop n'acceptent que des Pull Requests, fusionnées à la main.
set -e
cd "$(git rev-parse --show-toplevel)"
command -v gh >/dev/null || { echo "✖ GitHub CLI (gh) requis : https://cli.github.com" >&2; exit 1; }

dry=0; [ "$1" = "--dry-run" ] && dry=1
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
api="repos/$repo"
actions_app=15368   # GitHub Actions : source des checks « build » et « conventions »

run() {  # description, puis commande
  local desc=$1; shift
  if [ $dry -eq 1 ]; then echo "  [dry-run] $desc"; else "$@" >/dev/null && echo "  ✔ $desc"; fi
}

ruleset_json() {  # nom, branche, méthodes de fusion (JSON)
  cat <<EOF
{
  "name": "$1 : lecture seule",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/$2"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": $3 } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [
          { "context": "build", "integration_id": $actions_app },
          { "context": "conventions", "integration_id": $actions_app } ] } }
  ]
}
EOF
}

apply_ruleset() {  # nom, branche, méthodes de fusion
  local id
  id=$(gh api "$api/rulesets" --jq ".[] | select(.name == \"$1 : lecture seule\") | .id")
  if [ -n "$id" ]; then
    run "règle « $1 : lecture seule » mise à jour" gh api -X PUT "$api/rulesets/$id" --input <(ruleset_json "$@")
  else
    run "règle « $1 : lecture seule » créée" gh api -X POST "$api/rulesets" --input <(ruleset_json "$@")
  fi
}

echo "Dépôt : $repo"
git ls-remote --exit-code --heads origin develop >/dev/null || { echo "✖ La branche develop doit exister sur GitHub." >&2; exit 1; }

echo "1. Réglages du dépôt"
run "branche par défaut : develop (PR et Dependabot visent develop)" \
  gh api -X PATCH "$api" -f default_branch=develop
run "fusion : squash et merge commit (rebase désactivé) ; titre du squash = titre de la PR" \
  gh api -X PATCH "$api" -F allow_rebase_merge=false -F allow_squash_merge=true -F allow_merge_commit=true \
    -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY
run "suppression des branches fusionnées (en plus du workflow cleanup-branches)" \
  gh api -X PATCH "$api" -F delete_branch_on_merge=true

echo "2. Protection de main et develop (PR obligatoire, checks build + conventions, ni force push ni suppression)"
apply_ruleset main main '["merge"]'
apply_ruleset develop develop '["squash","merge"]'

echo "3. PR de release automatique (workflow release-pr)"
if gh secret list -R "$repo" 2>/dev/null | grep -q '^RELEASE_PR_TOKEN'; then
  echo "  ✔ secret RELEASE_PR_TOKEN déjà présent"
elif [ $dry -eq 1 ]; then
  echo "  [dry-run] secret RELEASE_PR_TOKEN absent : demandé à l'exécution"
else
  cat <<MSG
  Un jeton personnel permet à la PR de release de déclencher les checks (obligatoires pour la fusionner).
  Créer un jeton fine-grained limité à $repo : https://github.com/settings/personal-access-tokens/new
    permissions : Pull requests → Read and write ; Contents → Read
MSG
  printf '  Colle le jeton (Entrée pour passer) : '
  read -rs token; echo
  if [ -n "$token" ]; then
    printf '%s' "$token" | gh secret set RELEASE_PR_TOKEN -R "$repo" >/dev/null && echo "  ✔ secret RELEASE_PR_TOKEN enregistré"
  else
    echo "  ⚠ Sans jeton : autorisation des Actions à créer des PR (les checks ne se lanceront pas seuls sur la PR de release)"
  fi
  unset token
fi
if ! gh secret list -R "$repo" 2>/dev/null | grep -q '^RELEASE_PR_TOKEN'; then
  run "Actions autorisées à créer des PR (repli sans jeton)" \
    gh api -X PUT "$api/actions/permissions/workflow" -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
fi

echo
[ $dry -eq 1 ] && echo "Rien n'a été modifié (--dry-run)." || echo "✔ Dépôt configuré. Relancer à tout moment : ./scripts/setup-github.sh"
