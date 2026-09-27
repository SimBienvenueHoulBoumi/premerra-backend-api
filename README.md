# Premerra

API backend Spring Boot 4.1 · Java 21 · Maven.

## Démarrage

```bash
git clone git@github.com:SimBienvenueHoulBoumi/premerra-backend-api.git
cd premerra-backend-api
./scripts/setup-git.sh     # une fois : active les hooks git et le modèle de commit
./mvnw spring-boot:run     # lance l'application
./mvnw verify              # build + tests
```

Prérequis : JDK 21. Le wrapper Maven (`./mvnw`) télécharge Maven, rien d'autre à installer.

## Ce qui est automatique

| Quand                           | Quoi                                                                 | Où                                  |
|---------------------------------|----------------------------------------------------------------------|-------------------------------------|
| `git commit`                    | Format du message (Conventional Commits)                             | `.githooks/commit-msg`              |
| `git commit`                    | Refus sur `main`/`develop` ; build + tests si le code change         | `.githooks/pre-commit` → `scripts/check.sh` |
| `git push`                      | Nom de branche valide ; refus de pousser `main`/`develop`            | `.githooks/pre-push`                |
| Pull Request                    | Mêmes règles rejouées côté GitHub (branche, cible, titre, commits)   | `.github/workflows/conventions.yml` |
| PR, push sur `main`/`develop`   | Build + tests                                                        | `.github/workflows/ci.yml`          |
| Push sur `main`                 | Calcul de la version, tag `vX.Y.Z`, GitHub Release avec le jar       | `.github/workflows/tag.yml`         |

## Versions

Les versions ne se gèrent plus à la main : ni tag, ni version dans le `pom.xml`.
À chaque fusion sur `main`, la version suivante est déduite des commits depuis le dernier tag :

| Commits                                   | Exemple depuis `v1.4.2` |
|-------------------------------------------|-------------------------|
| `feat(api)!: …` ou pied `BREAKING CHANGE:` | `v2.0.0` (majeure)      |
| `feat: …`                                 | `v1.5.0` (mineure)      |
| `fix: …` ou `perf: …`                     | `v1.4.3` (correctif)    |
| uniquement `docs`, `chore`, `refactor`…   | pas de nouvelle version |

La CI construit le jar avec cette version (`-Drevision=X.Y.Z`) ; en local, le projet reste en `0.0.0-SNAPSHOT`.
Les versions publiées sont listées dans les [Releases](https://github.com/SimBienvenueHoulBoumi/premerra-backend-api/releases).

## Contribuer

`main` et `develop` sont en lecture seule : on les récupère (`git pull`), on ne les pousse jamais.
Tout changement passe par une branche `feature/…`, `fix/…`, etc. puis une Pull Request vers `develop`.

```bash
git switch develop && git pull
git switch -c feature/auth-jwt
git commit -m "feat(auth): ajouter la connexion par JWT"
git push -u origin feature/auth-jwt
gh pr create --base develop --title "feat(auth): ajouter la connexion par JWT"
```

Hiérarchie des branches, releases, hotfix et convention de commit : voir [CONTRIBUTING.md](CONTRIBUTING.md).

## Adapter à une autre techno

Seuls ces fichiers dépendent de Java/Maven : `scripts/check.sh`, `.github/workflows/ci.yml`,
l'étape de build de `.github/workflows/tag.yml` et `pom.xml`. Les hooks et les conventions restent identiques.
