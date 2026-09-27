# Premerra

API backend Spring Boot 4.1 · Java 21 · Maven.

Le dépôt est outillé pour que le développeur se concentre sur le code : formatage, tests, pull requests,
versions, releases, dépendances et ménage des branches sont automatiques. **Deux décisions restent humaines :
fusionner une PR (la relecture valide le code) et fusionner la PR de release (le moment de livrer).**

## Démarrage

```bash
git clone git@github.com:SimBienvenueHoulBoumi/premerra-backend-api.git
cd premerra-backend-api
./mvnw verify              # build + formatage + tests ; configure aussi git (hooks, modèle de commit)
./mvnw spring-boot:run     # lance l'application
```

Prérequis : JDK 21 et, pour ouvrir les PR, [GitHub CLI](https://cli.github.com) (`gh auth login`).
Sur macOS, les scripts sélectionnent le JDK 21 s'il est installé à côté d'un autre JDK.

## Au quotidien

```bash
git switch develop && git pull                  # à jour ; supprime les branches locales déjà fusionnées
git switch -c feature/auth-jwt
# … coder …
git commit -am "feat(auth): ajouter la connexion par JWT"
./scripts/pr.sh                                 # pousse et ouvre la PR vers la bonne branche
```

Puis relire la PR sur GitHub et la fusionner (squash). C'est tout.

| Moment               | Ce qui se passe automatiquement                                                   |
|----------------------|-----------------------------------------------------------------------------------|
| `git commit`         | Code Java reformaté et ré-indexé · message vérifié · refus sur `main`/`develop`    |
| `git push`           | Nom de branche vérifié · refus sur `main`/`develop` · build + tests si le code a changé |
| `./scripts/pr.sh`    | PR vers la bonne cible (`develop`, ou `main` + `develop` pour `release/*` et `hotfix/*`) avec un titre conforme |
| PR ouverte           | Checks `build` (compilation, formatage, tests) et `conventions` (branche, cible, titre, commits) |
| PR mal ciblée        | Corrigée au lieu d'échouer : doublon fermé, sinon redirigée vers la bonne branche |
| PR fusionnée         | Branche supprimée sur GitHub, puis en local au `git pull` suivant                 |
| Fusion sur `develop` | PR de release `develop` → `main` ouverte ou mise à jour : prochaine version + changelog |
| Fusion sur `main`    | Tag `vX.Y.Z` · jar construit à cette version · GitHub Release avec changelog       |
| Chaque lundi         | Dependabot ouvre des PR groupées de mises à jour vers `develop`                    |

## Versions et releases

Rien à gérer à la main : ni tag, ni version dans le `pom.xml` (injectée au build depuis le tag).
La version se déduit des messages de commit ([Conventional Commits](https://www.conventionalcommits.org/fr/v1.0.0/)) :

| Commits depuis la dernière version                 | Exemple depuis `v1.4.2` |
|----------------------------------------------------|-------------------------|
| `feat(api)!: …` ou pied `BREAKING CHANGE:`         | `v2.0.0` (majeure)      |
| `feat: …`                                          | `v1.5.0` (mineure)      |
| `fix: …`, `perf: …`, `fix(deps): …` (Dependabot)   | `v1.4.3` (correctif)    |
| uniquement `chore`, `ci`, `docs`, `build`, `test`… | pas de nouvelle version |

**Pour livrer : fusionner la PR `chore(release): vX.Y.Z`** en merge commit. Elle s'ouvre toute seule dès que
`develop` contient une nouveauté ou une correction, et annonce la version exacte qui sera publiée.
Versions publiées : [Releases](https://github.com/SimBienvenueHoulBoumi/premerra-backend-api/releases).

Dependabot suit la même logique : une dépendance embarquée dans le jar arrive en `fix(deps)` (nouvelle version,
le jar change), une dépendance de test en `build(deps-dev)` et une GitHub Action en `ci(deps)` (pas de version).

## Commandes utiles

| Commande                       | Rôle                                                       |
|--------------------------------|------------------------------------------------------------|
| `./scripts/pr.sh [titre]`      | Pousse et ouvre la PR ; titre déduit des commits si absent |
| `./mvnw verify`                | Build + formatage + tests, comme la CI                     |
| `./mvnw spotless:apply`        | Formate tout le code                                       |
| `./scripts/check.sh`           | Build + tests, comme le hook `pre-push`                    |
| `./scripts/next-version.sh`    | Prochaine version qui serait publiée (rien si aucune)      |
| `./scripts/release-notes.sh`   | Changelog depuis la dernière version                       |
| `./scripts/setup-github.sh`    | Configure le dépôt GitHub (admin, une fois ; `--dry-run`)  |
| `git commit --no-verify`       | Contourne les hooks locaux ; la CI revérifie tout          |

## Configuration GitHub (admin, une fois)

```bash
./scripts/setup-github.sh --dry-run   # prévisualiser, rien n'est modifié
./scripts/setup-github.sh             # appliquer
```

Le script est idempotent. Il définit `develop` comme branche par défaut, protège `main` et `develop`
(PR obligatoire, checks `build` et `conventions`, ni force push ni suppression) et enregistre le jeton
qui permet à la PR de release de déclencher les checks. Détails : [CONTRIBUTING.md](CONTRIBUTING.md#règles-github).

## Questions fréquentes

**Pourquoi aucune nouvelle release ?**
Seuls `feat`, `fix`, `perf` et les changements cassants créent une version. Des commits `chore`, `ci` ou `docs`
ne changent pas l'application livrée : pas de PR de release, pas de tag. `./scripts/next-version.sh origin/develop`
indique ce qui serait publié.

**Un check `conventions` est rouge sur ma PR alors qu'elle est correcte.**
Souvent une seconde PR ouverte sur la même branche vers `main` (bouton « Compare & pull request »). Les checks
sont attachés au commit : l'échec de l'une s'affiche sur l'autre. Ouvrir les PR avec `./scripts/pr.sh`.

**Ma PR a été fermée ou redirigée automatiquement.**
Elle visait la mauvaise branche. Doublon d'une PR bien ciblée : fermée ; sinon : redirigée, avec un titre corrigé.

**Le commit est refusé : « Fichiers reformatés mais en partie indexés ».**
Un fichier ajouté en partie (`git add -p`) a dû être reformaté. Vérifier le résultat, puis `git add` le fichier.

**« Aucun changement de code : tests ignorés » au push.**
Normal : les tests ne tournent que si `src/`, `pom.xml` ou `.mvn/` changent. La CI les lance toujours.

**Une branche locale n'a pas été supprimée après `git pull`.**
Son travail n'est pas dans `develop` : elle est signalée, jamais supprimée. `git branch -D <branche>` si c'est voulu.

## Contribuer

`main` et `develop` sont en lecture seule : on les récupère (`git pull`), on ne les pousse jamais.
Hiérarchie des branches, releases, hotfix, convention de commit : [CONTRIBUTING.md](CONTRIBUTING.md).

## Adapter à une autre techno

Seuls ces fichiers dépendent de Java/Maven : `scripts/env.sh`, `scripts/format.sh`, `scripts/check.sh`,
`pom.xml`, `.github/workflows/ci.yml`, l'étape de build de `.github/workflows/tag.yml`
et l'écosystème `maven` de `.github/dependabot.yml`. Hooks, conventions, versions et releases restent identiques.
