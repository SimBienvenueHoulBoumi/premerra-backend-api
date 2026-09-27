#!/usr/bin/env bash
# Formate les fichiers passés en argument (chemins relatifs à la racine du dépôt).
# Appelé par le hook pre-commit. Changer de techno = modifier uniquement ce fichier.
set -e
cd "$(git rev-parse --show-toplevel)"
. scripts/env.sh

regex=""
for f in "$@"; do
  case "$f" in *.java) regex="$regex\\Q$PWD/$f\\E," ;; esac
done
[ -n "$regex" ] || exit 0

./mvnw -B -q -ntp spotless:apply -DspotlessFiles="${regex%,}"
