# Premerra

API backend Spring Boot 4.1 · Java 21 · Maven.

## Démarrage

```bash
git clone git@github.com:SimBienvenueHoulBoumi/premerra-backend-api.git
cd premerra-backend-api
./mvnw verify              # build + tests ; active aussi les hooks git au passage
./mvnw spring-boot:run     # lance l'application
```

Prérequis : JDK 21 (sur macOS, les scripts le sélectionnent s'il est installé à côté d'un autre JDK).
Le wrapper Maven télécharge Maven, et le premier `./mvnw` configure git : rien d'autre à installer.

## Au quotidien : coder, commiter, pousser

```bash
git switch develop && git pull
git switch -c feature/auth-jwt
# … coder …
git commit -am "feat(auth): ajouter la connexion par JWT"
git push -u origin feature/auth-jwt
gh pr create --base develop --fill
```

Le reste est pris en charge :

| Quand           | Automatiquement                                                                  |
|-----------------|----------------------------------------------------------------------------------|
| `git commit`    | Code Java reformaté et ré-indexé (Palantir Java Format) · message vérifié · refus sur `main`/`develop` |
| `git push`      | Nom de branche vérifié · refus sur `main`/`develop` · build + tests si le code a changé |
| Pull Request    | Mêmes règles rejouées sur GitHub · build, formatage et tests (`build`, `conventions`) |
| Fusion sur `main` | Version calculée · tag `vX.Y.Z` · GitHub Release avec le jar                   |
| Chaque lundi    | Dependabot ouvre une PR groupée de mises à jour (Maven, GitHub Actions) vers `develop` |

**Ce qui reste humain, volontairement : la fusion.** Une PR n'est jamais fusionnée automatiquement,
y compris celles de Dependabot : c'est la relecture qui valide que le code est correct et compris.

## Versions

Rien à gérer à la main : ni tag, ni version dans le `pom.xml`.
À chaque fusion sur `main`, la version suivante est déduite des commits depuis le dernier tag :

| Commits                                    | Exemple depuis `v1.4.2` |
|--------------------------------------------|-------------------------|
| `feat(api)!: …` ou pied `BREAKING CHANGE:` | `v2.0.0` (majeure)      |
| `feat: …`                                  | `v1.5.0` (mineure)      |
| `fix: …` ou `perf: …`                      | `v1.4.3` (correctif)    |
| uniquement `docs`, `chore`, `build`…       | pas de nouvelle version |

Pour livrer : PR `develop` → `main`, fusionnée en merge commit. Titre invalide (« Develop » proposé par GitHub) :
la CI le remplace par `chore(release): livrer develop sur main`.
Versions publiées : [Releases](https://github.com/SimBienvenueHoulBoumi/premerra-backend-api/releases).

## Commandes utiles

| Commande                  | Rôle                                         |
|---------------------------|----------------------------------------------|
| `./mvnw spotless:apply`   | Formate tout le code                         |
| `./mvnw verify`           | Build + formatage + tests (comme la CI)      |
| `./scripts/check.sh`      | Ce que lance le hook `pre-push`              |
| `git commit --no-verify`  | Contourne les hooks (la CI revérifie tout)   |

## Contribuer

`main` et `develop` sont en lecture seule : on les récupère (`git pull`), on ne les pousse jamais.
Hiérarchie des branches, releases, hotfix et convention de commit : [CONTRIBUTING.md](CONTRIBUTING.md).

## Adapter à une autre techno

Seuls ces fichiers dépendent de Java/Maven : `scripts/env.sh`, `scripts/format.sh`, `scripts/check.sh`,
`pom.xml`, `.github/workflows/ci.yml`, l'étape de build de `.github/workflows/tag.yml`
et l'écosystème `maven` de `.github/dependabot.yml`. Les hooks et les conventions restent identiques.
