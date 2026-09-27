#!/usr/bin/env bash
# Vérifications propres à la techno du projet (build + tests), appelées par le hook pre-commit.
# Changer de techno = modifier uniquement ce fichier.
set -e
cd "$(git rev-parse --show-toplevel)"

# Rien à tester si le commit ne touche ni le code ni le build
if [ "$1" = "--staged" ] && ! git diff --cached --name-only | grep -qE '^(src/|pom\.xml|\.mvn/)'; then
  exit 0
fi

# Le projet cible Java 21 : sur macOS, on le sélectionne s'il n'est pas le JDK par défaut
if [ -x /usr/libexec/java_home ] && java21=$(/usr/libexec/java_home -v 21 2>/dev/null); then
  export JAVA_HOME=$java21
fi

echo "▶ Tests (./mvnw verify)…"
./mvnw -B -q -ntp verify
