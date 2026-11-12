# Premerra V0 — vision

> Cap et découpage de la V0. Chaque lot a sa propre spec détaillée, écrite au moment de le coder.
> Décisions prises le 2026-09-27.

## Objectif

Aider les **nouveaux arrivants dans l'enseignement supérieur en France** à s'intégrer et à **éviter les pièges**
(arnaques au logement, erreurs de démarches, difficultés d'emploi), en les mettant en relation avec un
**parrain de confiance** déjà installé. D'autres publics viendront après la V0.

Premerra est une **API** : le front (web ou mobile) est hors périmètre.

## Acteurs

| Rôle      | Qui                                                   | Fait quoi en V0                                              |
|-----------|-------------------------------------------------------|--------------------------------------------------------------|
| `ARRIVANT`| Étudiant nouvellement arrivé                          | cherche des parrains, envoie une demande, signale un abus    |
| `PARRAIN` | Étudiant avancé ou alumni d'un établissement          | accepte ou refuse les demandes, gère sa disponibilité        |
| `ADMIN`   | Équipe Premerra                                       | gère les établissements, valide les parrains, suspend        |

Un compte a **un seul rôle** en V0.

## Décisions

| Sujet            | Décision                                                                                           |
|------------------|----------------------------------------------------------------------------------------------------|
| Mise en relation | L'arrivant filtre les parrains et envoie une demande ; le parrain accepte ou refuse.               |
| Filtres          | établissement, ville (celle de l'établissement), domaine d'études, pays d'origine, langues, domaines d'aide (`LOGEMENT`, `DEMARCHES_ADMIN`, `BANQUE`, `EMPLOI_STAGE`, `VIE_QUOTIDIENNE`) |
| Établissement    | **Site web obligatoire.** Chaque domaine d'email académique est le domaine du site ou un sous-domaine ; exception possible par un admin, avec justification. |
| Confiance        | Le parrain crée son compte avec son **email académique** (vérifié par Keycloak) ; son domaine doit appartenir à son établissement ; un **admin valide** son profil avant qu'il soit visible. |
| Échange          | À l'acceptation, chacun voit le **contact** choisi par l'autre. Pas de messagerie.                  |
| Sécurité         | **Signalement** (seulement d'une personne avec qui on a eu une demande) ; **suspension** par un admin, qui termine ses relations. |
| Cycle de vie     | Capacité du parrain (1 à 10, défaut 3), disponibilité ; **un seul parrain actif et une seule demande en attente** par arrivant ; demande expirée après **14 jours** ; fin libre par chacun. |
| Authentification | **Keycloak** (OIDC). L'API valide les jetons JWT ; les rôles viennent de Keycloak.                 |
| Stockage         | **PostgreSQL**, migrations **Flyway**.                                                             |
| Architecture     | **Monolithe modulaire** vérifié par Spring Modulith : `referentiel`, `profil`, `parrainage`, `moderation` (+ `socle` transverse). |

## Modèle de données (5 tables)

`etablissement` · `arrivant` · `parrain` · `parrainage` · `signalement`

- `parrainage` porte tout le cycle : `EN_ATTENTE` → `ACCEPTEE` → `TERMINEE`, ou `REFUSEE`, `ANNULEE`, `EXPIREE`.
- Pays et langues : codes ISO ; domaines d'études et d'aide : énumérations dans le code.
- Les règles d'unicité (une demande en attente, une relation active par arrivant) sont garanties par la base.

## Découpage en lots

Chaque lot est une PR `feat`, livrable seule, qui publie sa version.

| Lot | Contenu                                                                 | Résultat utilisable                          |
|-----|-------------------------------------------------------------------------|----------------------------------------------|
| 1   | **Socle** : web, PostgreSQL + Flyway, Keycloak, erreurs, OpenAPI, santé | appel authentifié à `GET /api/moi`           |
| 2   | **Établissements**                                                      | un admin crée un établissement               |
| 3   | **Parrains** : inscription, validation admin, disponibilité, capacité   | un parrain validé                            |
| 4   | **Arrivants et recherche**                                              | un arrivant trouve des parrains              |
| 5   | **Parrainage** : demande, réponse, contacts, fin, expiration            | le service de bout en bout                   |
| 6   | **Modération** : signalement, suspension                                | recours contre les abus                      |

## Hors V0 (évolutions)

Vérification d'email par l'API (SMTP) · historique de modération · référentiels administrables ·
événements entre modules · messagerie · avis et notes · attribution automatique · autres publics.
