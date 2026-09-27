#!/usr/bin/env bash
# Active les hooks versionnés et le modèle de message de commit.
# À lancer une fois après chaque clone : ./scripts/setup-git.sh
set -e
cd "$(git rev-parse --show-toplevel)"

git config core.hooksPath .githooks
git config commit.template .gitmessage
chmod +x .githooks/*

echo "✔ Hooks git activés (.githooks) et modèle de commit configuré (.gitmessage)"
