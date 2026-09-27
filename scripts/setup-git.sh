#!/usr/bin/env bash
# Active les hooks versionnés et le modèle de message de commit.
# Facultatif : ./mvnw le fait automatiquement au premier build (profil git-hooks du pom.xml).
set -e
cd "$(git rev-parse --show-toplevel)"

git config core.hooksPath .githooks
git config commit.template .gitmessage
chmod +x .githooks/*

echo "✔ Hooks git activés (.githooks) et modèle de commit configuré (.gitmessage)"
