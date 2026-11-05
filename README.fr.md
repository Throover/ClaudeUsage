<img src="docs/icon.png" width="128" alt="Icône de ClaudeUsage">

# ClaudeUsage

**Votre consommation Claude Code dans la barre de menus du Mac, sans demande de mot de passe.**

Une petite app gratuite pour macOS. Elle affiche où vous en êtes de vos limites de session et de semaine, et quand elles se réinitialisent.

[English](README.md)

> **Bêta.** Testée pour l'instant sur un seul abonnement Claude. Si quelque chose vous semble anormal, merci d'[ouvrir un ticket](../../issues).

<img src="docs/panel.png" width="300" alt="Panneau affichant la consommation de session et de semaine">

- **Aucune demande de mot de passe :** l'app ne lit jamais votre trousseau ni votre jeton de connexion. Elle interroge Claude Code lui-même avec `/usage`.
- **Aucun coût :** dans nos tests, lire votre consommation a utilisé 0 token.
- **Toujours à jour :** elle s'actualise toutes les 5 minutes, à l'ouverture du panneau et au clic sur le bouton d'actualisation.
- **Dans votre langue :** suit la langue de votre Mac (anglais, français, espagnol, italien, allemand, portugais, chinois, japonais).
- **Ligne facultative dans le terminal :** `Session 16% · Semaine 12%` sous la zone de saisie de Claude Code, avec vos rappels de raccourcis toujours visibles. À activer dans les réglages de l'app.

## Installation

```sh
curl -fsSL https://raw.githubusercontent.com/Throover/ClaudeUsage/main/install.sh | sh
```

Ou téléchargez `ClaudeUsage.zip` depuis la [dernière version](../../releases/latest), décompressez-le et placez l'app dans **Applications**. L'app n'est pas notarisée par Apple, donc la première fois :

- **macOS 13–14 :** clic droit sur l'app → **Ouvrir** → **Ouvrir**.
- **macOS 15 et plus :** essayez de l'ouvrir une fois, puis allez dans **Réglages Système → Confidentialité et sécurité** et cliquez sur **Ouvrir quand même**.

## Prérequis

- macOS 13 Ventura ou plus récent. Testée sur Apple Silicon avec macOS 14. La version Intel a été testée via Rosetta, pas sur un Mac Intel.
- [Claude Code](https://claude.com/claude-code), connecté avec un abonnement Claude.

## Réglages

Cliquez sur l'engrenage du panneau :

| Réglage | Effet |
|---|---|
| Afficher l'usage de la session / de la semaine | Choisit les anneaux affichés dans la barre de menus |
| Afficher l'usage dans Claude Code | Ajoute la ligne sous la zone de saisie, pour les nouvelles sessions. Désactivé par défaut |
| Lancer au démarrage | Lance l'app au démarrage du Mac. Désactivé par défaut |

## Bon à savoir

- L'app lit le texte affiché par `/usage`. Si une mise à jour de Claude Code change ce texte, le panneau affiche **Échec de l'actualisation** jusqu'à la mise à jour de l'app.
- L'app contacte `status.claude.com` pour l'état du service et l'API GitHub pour détecter les nouvelles versions de Claude Code. Vos données de consommation restent sur votre Mac, dans `~/.claude/claude-usage.json`.

## Désinstallation

Désactivez d'abord **Afficher l'usage dans Claude Code** dans les réglages, puis :

```sh
pkill -x ClaudeUsage; rm -rf /Applications/ClaudeUsage.app ~/.claude/claude-usage.json "$HOME/Library/Application Support/ClaudeUsage"
```

## Compiler depuis les sources

Nécessite les Xcode Command Line Tools.

```sh
./build.sh --install
```

## Soutenir

ClaudeUsage est gratuit. S'il vous est utile, vous pouvez le soutenir :

[![Soutenir sur Ko-fi](https://img.shields.io/badge/Ko--fi-Offrir%20un%20caf%C3%A9-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/throover)
[![Soutenir sur Liberapay](https://img.shields.io/badge/Liberapay-Faire%20un%20don-F6C915?logo=liberapay&logoColor=black)](https://liberapay.com/Throover)

- **Ko-fi** : don ponctuel ou mensuel
- **Liberapay** : don récurrent, géré par une association à but non lucratif

## Licence

MIT. Projet indépendant, sans lien avec Anthropic ni approuvé par Anthropic.
