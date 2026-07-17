# context-pilot

**Protocole « safe-to-forget » pour la fenêtre de contexte de Claude Code.**

[English](README.md) | [中文](README-zh.md) | [Deutsch](README-de.md) | [Русский](README-ru.md)

« `/clear`, puis continue avec X » est une instruction qu'aucun modèle ne
peut exécuter : le contexte qui la prononce est détruit par elle.
context-pilot compile cette instruction imprononçable en trois étapes au
niveau du harness — écrire un handoff auto-suffisant avant le clear,
laisser l'humain appuyer sur `/clear`, puis livrer automatiquement le
handoff dans la session froide. Résultat : une longue session traverse un
effacement de contexte **sans perte**, au lieu de traîner un contexte
obèse (une taxe en tokens à chaque tour) ou de retomber sur l'auto-compact
avec pertes.

Plugin jumeau de [quota-pilot](https://github.com/easyfan/quota-pilot) :
quota-pilot gare une session au-delà d'une fenêtre de rate-limit
(hibernation) ; context-pilot fait traverser un effacement de contexte
(amnésie avec lettre à soi-même). Différence clé : le checkpoint de
quota-pilot est une assurance, le handoff de context-pilot est la
**mémoire entière** de la session suivante — d'où le droit de veto de sa
porte de sécurité.

## Composants

| Composant | Rôle |
|---|---|
| **Skill** (`context-pilot`) | Le protocole côté écriture : règle de décision (continuer / clear / compact), audit en six composantes de tout ce qui ne vit que dans la conversation, règles d'écriture « lecteur froid », et porte d'auto-suffisance avec veto. |
| **Commande** (`/clear-then <étape suivante>`) | Exécute le protocole avec l'étape suivante donnée explicitement, puis vous rend la touche `/clear`. |
| **Hook SessionStart** (`context_deliver.sh`) | Livraison agnostique de la source : après `/clear` (Claude natif *ou* l'app happy), un `context-handoff.md` frais est injecté avec un préambule lecteur-froid, puis consommé (renommé). |
| **Hook PostToolUse** (`context_sample.sh`) | Échantillonnage : surveille l'utilisation du contexte ; au-delà de 70 % (configurable), injecte une alerte d'évaluation de frontière, au plus une fois par cooldown. |

## La règle de décision

Trois entrées : **t** (travail restant), **H** (taille de handoff
nécessaire), **N** (distance au plafond — urgence seulement).

- **t petit** → finissez simplement ; tout transfert est du gaspillage.
- **Auto-suffisance inatteignable** → ne **pas** clear ; travailler
  jusqu'à une vraie frontière ou accepter l'auto-compact.
- **Porte franchie, H petit** → écrire le handoff, inviter `/clear`.
- **Zone grise** → compact. Le compact échoue *doucement* (le modèle sent
  le manque et peut relire) ; un mauvais clear échoue *silencieusement*
  (la nouvelle session ignore ce qu'elle ignore).

Le handoff consigne : objectif, étape suivante concrète, **décisions y
compris les alternatives explicitement rejetées**, pièges, état non
vérifié honnête, contraintes orales de l'utilisateur — plus une carte de
session pointant vers l'ancien transcript (qui survit au clear sur le
disque). Des pointeurs, jamais du contenu copié.

## Installation

En tant que plugin :

```
/plugin marketplace add easyfan/context-pilot
/plugin install context-pilot@context-pilot
```

Manuelle :

```bash
git clone https://github.com/easyfan/context-pilot.git
cd context-pilot && ./install.sh          # --dry-run aperçu, --uninstall retrait
```

## Configuration

`~/.claude/context-pilot/config.json` (optionnel) :

```json
{
  "context_window": 200000,
  "warn_pct": 70,
  "cooldown_minutes": 15,
  "check_seconds": 60
}
```

> **Remarque pour les modèles à fenêtre 1M :** `context_window` vaut `200000` par défaut. Si votre modèle dispose d'une fenêtre de contexte de 1M de tokens (p. ex. les identifiants de modèle `[1m]`), réglez-le sur `1000000` — avec la valeur par défaut, les alertes se déclenchent bien trop tôt et peuvent indiquer une utilisation supérieure à 100 %.

Fenêtre de fraîcheur de livraison : `CONTEXT_PILOT_FRESH_SECONDS`,
défaut 900.

## Fichiers

```
skills/context-pilot/SKILL.md   le protocole
commands/clear-then.md          /clear-then
hooks/context_deliver.sh        livraison SessionStart (consume-once)
hooks/context_sample.sh         échantillonnage PostToolUse
hooks/hooks.json                enregistrement des hooks du plugin
install.sh                      installateur manuel
evals/evals.json                jeu d'évaluation comportemental (+26pp vs sans skill)
```

## Licence

MIT
