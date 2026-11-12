# Contribuer à Premerra

## Installation

Les règles git viennent de [repogarde](https://github.com/SimBienvenueHoulBoumi/repogarde) (`lefthook.yml`, version figée ;
réglages du projet dans `.repogarde.conf`). Une fois par poste, installer [lefthook](https://lefthook.dev)
(`brew install lefthook`, `npm i -g lefthook` ou `scoop install lefthook`) : le premier `./mvnw` installe ensuite les hooks,
le modèle de message `.gitmessage` et `fetch.prune` (profil `git-hooks` du `pom.xml`). Sans Maven : `lefthook install`.

| Hook         | Rôle                                                                              |
|--------------|-----------------------------------------------------------------------------------|
| `commit-msg` | Le message respecte la convention de commit (72 caractères max)                   |
| `pre-commit` | Aucun commit direct sur `main`/`develop` ; secrets bloqués ; reformate et ré-indexe le code Java (`scripts/format.sh`) |
| `pre-push`   | Nom de branche valide ; aucun push sur `main`/`develop` ; build + tests (`scripts/check.sh`) si les commits poussés touchent `src/`, `pom.xml` ou `.mvn/` |
| `post-merge` | Après `git pull` : supprime les branches locales fusionnées et supprimées sur GitHub (merge ou squash) ; une branche non fusionnée est conservée |

Le formatage ne touche que le contenu indexé : le travail non indexé est préservé.
Les commandes propres à la techno sont isolées dans `scripts/` (`format`, `test` de `.repogarde.conf`).

`scripts/pr.sh` crée la PR avec la bonne cible (déduite du type de branche) et un titre vérifié. En squash,
ce titre devient le commit sur `develop` et décide de la version : le script retient le commit le plus impactant (`!` > `feat` > `fix`).

Les mêmes règles sont vérifiées sur GitHub pour chaque PR (`.github/workflows/repogarde.yml`, non contournable),
et `.github/workflows/ci.yml` compile, vérifie le formatage et teste chaque PR et chaque push sur `main`/`develop`.

## Dépendances

Dependabot (`.github/dependabot.yml`) ouvre chaque lundi des PR groupées vers `develop`.
Le préfixe dit si le livrable change, donc s'il faut une nouvelle version :

| PR Dependabot                         | Préfixe            | Version                                  |
|---------------------------------------|--------------------|------------------------------------------|
| Dépendance embarquée dans le jar      | `fix(deps): …`     | PATCH : le jar change, il faut le redéployer |
| Dépendance de test ou de build        | `build(deps-dev): …` | aucune : le jar ne change pas          |
| GitHub Actions                        | `ci(deps): …`      | aucune                                   |

Production et développement sont dans des groupes séparés : une PR ne mélange jamais les deux.
La fusion reste humaine : relire le changelog des dépendances, vérifier la CI, puis fusionner (squash).
Sur ces PR uniquement (commits de Dependabot), la CI accepte un titre de plus de 72 caractères.

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
./scripts/pr.sh   # pousse + PR vers develop, titre = commit le plus impactant (vérifié en local)
# → fusion (squash) puis suppression automatique de la branche
```

### Release

```bash
git switch develop && git pull
git switch -c release/1.1.0
# derniers correctifs éventuels (la version du pom est injectée par la CI depuis le tag)
./scripts/pr.sh "chore(release): version 1.1.0"   # pousse + PR vers main ET develop
# → fusionner les deux PR (merge commit, pas squash) : le tag est créé automatiquement
```

### Hotfix

```bash
git switch main && git pull
git switch -c hotfix/token-expire
git commit -am "fix(auth): corriger l'expiration du token"
./scripts/pr.sh   # pousse + PR vers main ET develop
# → fusionner les deux PR : le tag est créé automatiquement
```

### Livraison : PR de release automatique

À chaque push sur `develop`, `.github/workflows/release.yml` (repogarde, mode tag) crée ou met à jour la PR `develop` → `main`
intitulée `chore(release): vX.Y.Z`, avec le changelog (changements incompatibles, fonctionnalités, corrections, maintenance).
S'il n'y a que de la maintenance, elle s'intitule `chore(release): livrer develop sur main` : il n'y a pas de version à publier.

**Livrer = fusionner cette PR en merge commit.** Le moment de la livraison reste une décision humaine.

La version annoncée dans la PR est celle qui sera publiée : même calcul à la création de la PR et au tag.
Aucun jeton à configurer : les checks requis sont ceux du dernier commit de `develop`, déjà lancés par le push.

### Tags automatiques

À chaque push sur `main`, `.github/workflows/release.yml` lit les commits depuis le dernier tag `vX.Y.Z` et crée le suivant :

| Commits depuis le dernier tag                  | Tag              |
|------------------------------------------------|------------------|
| au moins un `type!:` ou `BREAKING CHANGE:`     | MAJOR (`v2.0.0`) |
| sinon au moins un `feat`                       | MINOR (`v1.2.0`) |
| sinon au moins un `fix` ou `perf`              | PATCH (`v1.1.1`) |
| uniquement `docs`, `chore`, `refactor`…        | pas de tag       |

Puis, après approbation de l'environnement `production` (un clic sur le run), il compile et teste avec `-Drevision=X.Y.Z` et joint le jar à la GitHub Release, qui porte le même changelog que la PR de livraison.
Ne jamais créer de tag à la main. Nommer `release/<X.Y.Z>` avec la version que le workflow calculera.

## Règles GitHub

Tout ce qui suit se configure en une commande, par un admin du dépôt, depuis ce dépôt
(relançable sans risque, `--dry-run` pour prévisualiser ; `<repogarde>` = clone de repogarde) :

```bash
<repogarde>/bin/proteger --checks "repogarde,build"
```

`main` et `develop` sont en lecture seule (ruleset « repogarde ») :
- modification uniquement par Pull Request (push direct refusé)
- les checks `repogarde` (nom de branche, cible, titre de PR, messages de commit, secrets, formatage) et `build` (CI) doivent passer
- force push et suppression interdits
- méthodes de fusion : `develop` ← squash (merge commit pour `release/*` et `hotfix/*`) ; `main` ← merge commit uniquement

Les tags `v*` sont réservés au workflow de release : création, modification et suppression manuelles refusées.

La branche par défaut est `develop` : les PR s'y ouvrent par défaut.
La branche source d'une PR fusionnée est supprimée par `.github/workflows/nettoyage-branches.yml`
(sauf `main`, `develop` et une branche encore source d'une autre PR ouverte, cas de `release/*` et `hotfix/*`).
Le titre de la PR suit la convention de commit : il devient le message du commit en cas de squash.

PR ouverte vers la mauvaise cible (typiquement le bouton « Compare & pull request ») : le check `repogarde`
la corrige au lieu d'échouer. Doublon d'une PR bien ciblée → fermée ; sinon → reciblée vers la bonne branche,
avec un titre recalculé s'il est invalide (commit le plus impactant).

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
| `fix`      | Correction de bug, mise à jour d'une dépendance embarquée | PATCH   |
| `perf`     | Amélioration de performance                        | PATCH   |
| `refactor` | Restructuration sans changement de comportement    | —       |
| `test`     | Ajout ou modification de tests                     | —       |
| `docs`     | Documentation                                      | —       |
| `style`    | Formatage, sans impact sur le code                 | —       |
| `build`    | Maven, dépendances de test ou de build             | —       |
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
fix(deps): mettre à jour spring-boot en 4.1.2
refactor(api)!: renommer /users en /accounts

BREAKING CHANGE: les clients doivent utiliser /accounts
```
