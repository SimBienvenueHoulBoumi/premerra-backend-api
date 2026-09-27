# Lot 1 — Socle

> Spec détaillée du premier lot de la V0. Contexte et découpage : [vision V0](2026-09-27-premerra-v0-vision.md).
> Statut : **à relire** · 2026-09-27

## 1. Objectif

Poser les fondations techniques communes à tous les lots, sans aucune règle métier :
un développeur clone le dépôt, lance **une commande**, et obtient une API qui démarre avec sa base de données
et son serveur d'identité, **authentifie** un utilisateur Keycloak et répond à `GET /api/moi`.

**Critères de réussite**

1. `./mvnw spring-boot:run` démarre PostgreSQL et Keycloak automatiquement (Docker requis), puis l'API.
2. Un utilisateur de test obtient un jeton Keycloak ; `GET /api/moi` renvoie son identifiant, son email et son rôle.
3. Sans jeton, toute route `/api/**` répond `401` au format d'erreur commun.
4. `GET /actuator/health` répond `UP` (base comprise) ; la documentation OpenAPI liste `/api/moi`.
5. `./mvnw verify` passe en local et en CI, avec un vrai PostgreSQL (Testcontainers) et la vérification des modules.

## 2. Périmètre

| Dans le lot 1                                            | Hors lot 1 (lots suivants)                    |
|----------------------------------------------------------|-----------------------------------------------|
| Dépendances web, JPA, Flyway, sécurité, OpenAPI, santé   | Toute table métier (première migration : lot 2) |
| Validation des JWT Keycloak, conversion des rôles        | Création de comptes par l'API                 |
| Environnement local : PostgreSQL + Keycloak + realm      | CORS et front                                 |
| Format d'erreur commun (RFC 9457)                        | Déploiement (image, Kubernetes)               |
| `GET /api/moi`                                           | Modules `referentiel`, `profil`, `parrainage`, `moderation` (créés par leur lot) |

## 3. Architecture

```
simdev.org.premerra
├── PremerraApplication
└── socle                      module transverse, seul module du lot 1
    ├── CompteCourant          API publique du module : qui appelle ? (id, email, rôles)
    ├── Role                   enum ARRIVANT, PARRAIN, ADMIN
    ├── securite/              configuration Spring Security, conversion des rôles Keycloak
    ├── erreur/                gestion centralisée des erreurs (ProblemDetail)
    └── compte/                MoiController (GET /api/moi)
```

- `socle` est un **module Spring Modulith**. Seuls `CompteCourant` et `Role` (à la racine du package) sont
  utilisables par les futurs modules ; `securite`, `erreur` et `compte` sont internes.
- Un test `ModularityTests` (`ApplicationModules.of(PremerraApplication.class).verify()`) fait échouer le build
  si une dépendance entre modules viole ces règles. Il protège les lots suivants dès maintenant.

## 4. Dépendances

Versions gérées par le parent Spring Boot 4.1.1, sauf mention.

| Dépendance                                              | Rôle                                               |
|---------------------------------------------------------|----------------------------------------------------|
| `spring-boot-starter-webmvc`                            | API REST                                           |
| `spring-boot-starter-validation`                        | validation des entrées (utilisée dès le lot 2)     |
| `spring-boot-starter-data-jpa` + `postgresql` (runtime) | persistance                                        |
| `spring-boot-starter-flyway` + `flyway-database-postgresql` | migrations versionnées                          |
| `spring-boot-starter-security-oauth2-resource-server`   | validation des JWT Keycloak                        |
| `spring-boot-starter-actuator`                          | santé                                              |
| `springdoc-openapi-starter-webmvc-ui` **3.1.1**         | OpenAPI + Swagger UI                               |
| `spring-modulith-starter-core` (BOM **2.1.1**)          | vérification des modules                           |
| `spring-boot-docker-compose` (optional, dev)            | démarre `compose.yaml` au lancement                |
| test : `spring-boot-starter-test`, `spring-security-test`, `spring-boot-testcontainers`, `testcontainers-postgresql`, `spring-modulith-starter-test` | tests |

Compatibilité springdoc 3.1 / Modulith 2.1 avec Boot 4.1 : **à confirmer au premier build du plan**.

## 5. Environnement local

Un `compose.yaml` **dans le dépôt** (le `Springboot/compose.yaml` existant, hors dépôt, n'est pas utilisé) :

| Service    | Image                          | Port hôte | Détail                                                    |
|------------|--------------------------------|-----------|-----------------------------------------------------------|
| `postgres` | `postgres:16`                  | 5433      | base `premerra`, identifiants de développement            |
| `keycloak` | `quay.io/keycloak/keycloak:26.7` | 8180    | `start-dev --import-realm`, realm importé au démarrage     |

- **Spring Boot Docker Compose** démarre ces services au `spring-boot:run` et configure la datasource.
  Il est inactif pendant les tests (Testcontainers prend le relais).
- **Realm `premerra`** versionné dans `docker/keycloak/premerra-realm.json` :
  - rôles de realm `ARRIVANT`, `PARRAIN`, `ADMIN` ;
  - client `premerra-api` (audience des jetons) ;
  - client public `premerra-dev` avec *direct access grants*, **réservé au développement**, pour obtenir un jeton en `curl` ;
  - trois utilisateurs de test, un par rôle, email vérifié, mot de passe `dev`.
- Ces identifiants sont **factices et locaux** ; aucun secret réel n'est versionné.

Obtenir un jeton en local :

```bash
curl -s -d client_id=premerra-dev -d grant_type=password \
     -d username=parrain@univ-exemple.fr -d password=dev \
     http://localhost:8180/realms/premerra/protocol/openid-connect/token | jq -r .access_token
```

## 6. Sécurité

- API **sans état** (pas de session), CSRF désactivé (pas de cookie d'authentification).
- `spring.security.oauth2.resourceserver.jwt.issuer-uri` = `${KEYCLOAK_ISSUER_URI:http://localhost:8180/realms/premerra}`.
  Le décodeur est initialisé à la première requête authentifiée : l'API démarre même si Keycloak est absent.
- **Rôles** : lus dans la claim `realm_access.roles` ; seuls `ARRIVANT`, `PARRAIN`, `ADMIN` sont retenus
  et deviennent `ROLE_ARRIVANT`, etc. Les rôles techniques de Keycloak (`offline_access`…) sont ignorés.

| Route                                       | Accès          |
|---------------------------------------------|----------------|
| `GET /actuator/health`                      | public         |
| `/v3/api-docs/**`, `/swagger-ui/**`         | public         |
| `/api/**`                                   | authentifié    |
| tout le reste                               | refusé : `401` anonyme, `403` authentifié (sécurisé par défaut) |

## 7. API

### `GET /api/moi`

Renvoie l'identité de l'appelant, telle que lue dans son jeton. Aucun accès à la base.

`200 OK`
```json
{
  "id": "5f0c8d1e-7a3b-4c2e-9f1a-2b6d8e4c1a90",
  "email": "parrain@univ-exemple.fr",
  "emailVerifie": true,
  "roles": ["PARRAIN"]
}
```

- `id` = claim `sub` (UUID Keycloak), identifiant de l'utilisateur dans toute l'API.
- `roles` peut être vide : un compte sans rôle Premerra est authentifié mais n'aura accès à aucune fonction métier.

## 8. Erreurs

Toutes les erreurs suivent la **RFC 9457** (`application/problem+json`), y compris `401` et `403`
produits par Spring Security.

```json
{
  "type": "urn:premerra:erreur:non-authentifie",
  "title": "Authentification requise",
  "status": 401,
  "detail": "Un jeton d'accès valide est requis.",
  "instance": "/api/moi"
}
```

| Statut | `type` (`urn:premerra:erreur:…`) | Cas                                          |
|--------|----------------------------------|----------------------------------------------|
| 400    | `requete-invalide`               | corps illisible, validation (champ `erreurs` : liste `{champ, message}`) |
| 401    | `non-authentifie`                | jeton absent, expiré ou invalide             |
| 403    | `acces-refuse`                   | rôle insuffisant                             |
| 404    | `introuvable`                    | route `/api/**` ou ressource inexistante (appelant authentifié) |
| 500    | `erreur-interne`                 | imprévu : message générique, détail uniquement dans les logs |

Aucune trace technique (stack trace, requête SQL) n'est renvoyée au client.

## 9. Tests

| Test                    | Type                            | Vérifie                                                        |
|-------------------------|---------------------------------|----------------------------------------------------------------|
| `ModularityTests`       | unitaire                        | frontières des modules                                         |
| `MoiControllerTest`     | `@WebMvcTest` + `jwt()`         | réponse de `/api/moi`, filtrage des rôles, `401` sans jeton    |
| `GestionErreursTest`    | `@WebMvcTest`                   | format RFC 9457 pour 400, 401, 403, 404, 500                   |
| `PremerraApplicationTests` | `@SpringBootTest` + Testcontainers PostgreSQL | démarrage complet, Flyway, `health` `UP`, OpenAPI accessible |

- Aucun Keycloak dans les tests : les jetons sont simulés par `spring-security-test`.
- Testcontainers nécessite **Docker**, en local (hook `pre-push`) comme en CI (disponible sur les runners GitHub).

## 10. Configuration

`application.yaml` (valeurs par défaut pour le développement, surchargées par variables d'environnement) :

| Clé                                   | Valeur                                   |
|---------------------------------------|------------------------------------------|
| `spring.jpa.hibernate.ddl-auto`       | `validate` (le schéma vient de Flyway)   |
| `spring.jpa.open-in-view`             | `false`                                  |
| `spring.mvc.problemdetails.enabled`   | `true`                                   |
| `management.endpoints.web.exposure.include` | `health`                           |
| `management.endpoint.health.show-details` | `never`                              |

## 11. Livraison

- Une PR `feat(socle): …` vers `develop` ; à la release suivante : **v0.2.0**.
- README : Docker ajouté aux prérequis, section « Obtenir un jeton en local ».

## 12. Décisions prises dans cette spec (à relire en priorité)

Ces points n'ont pas été discutés avant l'écriture :

1. `compose.yaml` et realm Keycloak **dans le dépôt** ; le `Springboot/compose.yaml` existant est ignoré.
   Au passage, son mapping `5432:5433` semble inversé (PostgreSQL écoute sur 5432 dans le conteneur).
2. **Démarrage automatique** des conteneurs par Spring Boot Docker Compose au `spring-boot:run`.
3. Ports hôte : PostgreSQL sur **5433** (ton conteneur `postgres-dev` occupe déjà 5432), Keycloak sur **8180**
   (8080 reste libre pour l'API). Spring Boot lit les ports réels de `compose.yaml`, rien à configurer.
4. Client `premerra-dev` avec *password grant*, **uniquement en local**, pour tester en `curl`.
5. Erreurs identifiées par des URN `urn:premerra:erreur:…` plutôt que par des URL d'un domaine encore inexistant.
6. Swagger UI et `/v3/api-docs` **publics** (aucun secret exposé) ; à restreindre au déploiement si besoin.
7. Seul le module `socle` est créé ; les autres modules naissent avec leur lot.
