# Contribuer à Premerra

## Installation

Rien à faire : le premier `./mvnw` (build, tests…) active les hooks versionnés dans `.githooks/`
et le modèle de message `.gitmessage` (profil `git-hooks` du `pom.xml`).
Sans Maven : `./scripts/setup-git.sh`.

| Hook         | Rôle                                                                              |
|--------------|-----------------------------------------------------------------------------------|
| `commit-msg` | Le message respecte la convention de commit                                       |
| `pre-commit` | Aucun commit direct sur `main`/`develop` ; reformate et ré-indexe le code Java (`scripts/format.sh`) |
| `pre-push`   | Nom de branche valide ; aucun push sur `main`/`develop` ; build + tests (`scripts/check.sh`) si les commits poussés touchent `src/`, `pom.xml` ou `.mvn/` |

Un fichier en partie indexé (`git add -p`) qui doit être reformaté bloque le commit : vérifier puis `git add`.
Les commandes propres à la techno sont isolées dans `scripts/` : les hooks restent génériques.

Les mêmes règles sont vérifiées sur GitHub pour chaque PR (`.github/workflows/conventions.yml`),
et `.github/workflows/ci.yml` compile, vérifie le formatage et teste chaque PR et chaque push sur `main`/`develop`.

## Dépendances

Dependabot (`.github/dependabot.yml`) ouvre chaque lundi une PR groupée vers `develop` :
`build(deps): …` pour Maven, `ci(deps): …` pour GitHub Actions. Ces types ne créent pas de version.
La fusion reste humaine : relire le changelog des dépendances, vérifier la CI, puis fusionner (squash).
Sur ces PR uniquement, la CI accepte un titre de plus de 72 caractères.

## Hiérarchie des branches

```
main ─────●───────────────●──────────●────────   production, tags vX.Y.Z
          │               ↑          ↑  │
          │        release/1.1.0     │  hotfix/token-expire
          ↓               ↑          │  │
develop ──●──●─────●──────●──────────●──●─────   intégration
             │     ↑
             feature/auth-jwt
```

| Branche             | Part de   | Fusionne dans       | Rôle                                   |
|---------------------|-----------|---------------------|----------------------------------------|
| `main`              | —         | —                   | Code en production. Jamais de commit direct. Tags automatiques. |
| `develop`           | `main`    | —                   | Intégration de la prochaine version.   |
| `feature/<nom>`     | `develop` | `develop`           | Nouvelle fonctionnalité.               |
| `fix/<nom>`         | `develop` | `develop`           | Correction de bug non urgente.         |
| `refactor/<nom>`    | `develop` | `develop`           | Restructuration sans changement fonctionnel. |
| `chore/<nom>`       | `develop` | `develop`           | Dépendances, config, outillage.        |
| `docs/<nom>`        | `develop` | `develop`           | Documentation.                         |
| `test/<nom>`        | `develop` | `develop`           | Ajout ou correction de tests.          |
| `release/<X.Y.Z>`   | `develop` | `main` + `develop`  | Préparation d'une version (derniers fixes). |
| `hotfix/<nom>`      | `main`    | `main` + `develop`  | Correction urgente en production.      |

**Règles de nommage** : minuscules, kebab-case, court et explicite.
`feature/auth-jwt` ✔ — `Feature/AuthJWT` ✖ — `ma-branche` ✖

## Utilisation au quotidien

### Fonctionnalité / correctif

```bash
git switch develop && git pull
git switch -c feature/auth-jwt
# ... commits ...
git push -u origin feature/auth-jwt
gh pr create --base develop --title "feat(auth): ajouter la connexion par JWT"
# → fusion (squash) puis suppression automatique de la branche
```

### Release

```bash
git switch develop && git pull
git switch -c release/1.1.0
# derniers correctifs éventuels (la version du pom est injectée par la CI depuis le tag)
git push -u origin release/1.1.0

gh pr create --base main    --title "chore(release): version 1.1.0"
gh pr create --base develop --title "chore(release): version 1.1.0"
# → fusionner les deux PR (merge commit, pas squash) : le tag est créé automatiquement
```

### Hotfix

```bash
git switch main && git pull
git switch -c hotfix/token-expire
git commit -am "fix(auth): corriger l'expiration du token"
git push -u origin hotfix/token-expire

gh pr create --base main    --title "fix(auth): corriger l'expiration du token"
gh pr create --base develop --title "fix(auth): corriger l'expiration du token"
# → fusionner les deux PR : le tag est créé automatiquement
```

### Tags automatiques

À chaque push sur `main`, le workflow `.github/workflows/tag.yml` lit les commits depuis le dernier tag `vX.Y.Z` et crée le suivant :

| Commits depuis le dernier tag                  | Tag              |
|------------------------------------------------|------------------|
| au moins un `type!:` ou `BREAKING CHANGE:`     | MAJOR (`v2.0.0`) |
| sinon au moins un `feat`                       | MINOR (`v1.2.0`) |
| sinon au moins un `fix` ou `perf`              | PATCH (`v1.1.1`) |
| uniquement `docs`, `chore`, `refactor`…        | pas de tag       |

Le workflow compile et teste avec `-Drevision=X.Y.Z`, pousse le tag, puis publie la GitHub Release avec le jar.
Ne jamais créer de tag à la main. Nommer `release/<X.Y.Z>` avec la version que le workflow calculera.

## Règles GitHub

`main` et `develop` sont en lecture seule (règle de dépôt « branches protégées ») :
- modification uniquement par Pull Request, pour tout le monde (push direct refusé)
- les checks `conventions` (nom de branche, cible, titre de PR, messages de commit) et `build` (CI) doivent passer
- force push et suppression interdits
- méthodes de fusion : `develop` ← squash (merge commit pour `release/*` et `hotfix/*`) ; `main` ← merge commit uniquement

Les tags `v*` sont réservés au workflow `tag.yml` (règle de dépôt « tags de version ») : création, modification et suppression manuelles refusées.

La branche par défaut est `develop` : les PR s'y ouvrent par défaut, et la branche source est supprimée après fusion.
Le titre de la PR suit la convention de commit : il devient le message du commit en cas de squash.

## Convention de commit

Basée sur [Conventional Commits](https://www.conventionalcommits.org/fr/v1.0.0/). Messages en français.

```
<type>(<scope>): <description>

[corps : le pourquoi]

[pied : BREAKING CHANGE, Refs]
```

| Type       | Usage                                              | Version |
|------------|----------------------------------------------------|---------|
| `feat`     | Nouvelle fonctionnalité                            | MINOR   |
| `fix`      | Correction de bug                                  | PATCH   |
| `perf`     | Amélioration de performance                        | PATCH   |
| `refactor` | Restructuration sans changement de comportement    | —       |
| `test`     | Ajout ou modification de tests                     | —       |
| `docs`     | Documentation                                      | —       |
| `style`    | Formatage, sans impact sur le code                 | —       |
| `build`    | Maven, dépendances                                 | —       |
| `ci`       | Pipeline CI/CD                                     | —       |
| `chore`    | Maintenance diverse                                | —       |
| `revert`   | Annulation d'un commit                             | —       |

Un `!` après le type (`feat(api)!:`) ou un pied `BREAKING CHANGE:` signale un changement cassant → **MAJOR**.

**Règles**
- Description à l'impératif, sans majuscule initiale ni point final
- Première ligne ≤ 72 caractères
- Scope = module concerné, en minuscules (`auth`, `api`, `user`, `config`…)
- Un commit = un changement logique

**Exemples**

```
feat(auth): ajouter la connexion par JWT
fix(user): empêcher la création d'un email en double
build(deps): mettre à jour spring-boot en 4.1.2
refactor(api)!: renommer /users en /accounts

BREAKING CHANGE: les clients doivent utiliser /accounts
```
