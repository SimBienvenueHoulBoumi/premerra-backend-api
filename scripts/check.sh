#!/usr/bin/env bash
# Build + tests du projet. Appelé par le hook pre-push. Changer de techno = modifier uniquement ce fichier.
#   ./scripts/check.sh                   → lance toujours
#   … | ./scripts/check.sh --if-changed  → lance seulement si la liste de fichiers (stdin) touche le code
set -e
cd "$(git rev-parse --show-toplevel)"
. scripts/env.sh

if [ "$1" = "--if-changed" ] && ! grep -qE '^(src/|pom\.xml$|\.mvn/)'; then
  echo "▷ Aucun changement de code : tests ignorés."
  exit 0
fi

echo "▶ Build + tests (./mvnw verify)…"
./mvnw -B -q -ntp verify
