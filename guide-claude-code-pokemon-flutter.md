# 🤖 Guide Claude Code — App Flutter Scanner Pokémon

> Guide complet pour construire une app Flutter de scan de cartes Pokémon avec Claude Code.  
> Mis à jour : juin 2026

---

## Sommaire

1. [Qu'est-ce que Claude Code ?](#1-quest-ce-que-claude-code)
2. [Prérequis](#2-prérequis)
3. [Installation](#3-installation)
4. [Authentification](#4-authentification)
5. [Structure du projet Flutter](#5-structure-du-projet-flutter)
6. [Le fichier CLAUDE.md — Le cerveau du projet](#6-le-fichier-claudemd--le-cerveau-du-projet)
7. [Les commandes essentielles](#7-les-commandes-essentielles)
8. [Workflow recommandé — Étape par étape](#8-workflow-recommandé--étape-par-étape)
9. [Prompts prêts à l'emploi](#9-prompts-prêts-à-lemploi)
10. [Stack technique du projet](#10-stack-technique-du-projet)
11. [Raccourcis clavier](#11-raccourcis-clavier)
12. [Conseils & Bonnes pratiques](#12-conseils--bonnes-pratiques)
13. [Tarifs](#13-tarifs)

---

## 1. Qu'est-ce que Claude Code ?

Claude Code est l'outil de développement en ligne de commande d'Anthropic. Ce n'est pas un simple assistant chat — c'est un **agent autonome** capable de :

- Lire et comprendre l'intégralité de ton projet
- Modifier plusieurs fichiers en une seule instruction
- Exécuter des commandes shell (`flutter pub get`, `dart analyze`, etc.)
- Planifier des implémentations complexes avant de coder
- Apprendre les conventions de ton projet via `CLAUDE.md`

> **En clair :** tu décris ce que tu veux, Claude le fait — dans ton terminal, sur tes vrais fichiers.

---

## 2. Prérequis

| Élément | Requis | Notes |
|---|---|---|
| Système | macOS 13+, Ubuntu 20.04+, Windows 10+ (WSL) | |
| RAM | 4 Go minimum | 8 Go recommandé |
| Node.js | v18 ou supérieur | Seulement pour l'install npm |
| Compte Anthropic | Pro ($20/mois), Max, Teams ou Enterprise | Le plan gratuit ne donne pas accès à Claude Code |
| Flutter SDK | 3.x | Installé séparément |
| Android Studio / Xcode | Pour compiler iOS/Android | |
| Connexion internet | Requise | Claude tourne sur les serveurs Anthropic |

---

## 3. Installation

### Méthode A — Installeur natif (recommandé, aucune dépendance)

**macOS / Linux :**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**Windows (PowerShell en administrateur) :**
```powershell
irm https://claude.ai/install.ps1 | iex
```

### Méthode B — Via npm

```bash
npm install -g @anthropic-ai/claude-code
```

> ⚠️ Ne pas utiliser `sudo` avec npm. Si tu as des erreurs de permissions, utilise `nvm`.

### Vérification

```bash
claude --version
claude doctor   # Diagnostic complet de l'installation
```

---

## 4. Authentification

Lance Claude Code et authentifie-toi via ton navigateur :

```bash
claude
```

Un lien s'ouvre automatiquement. Connecte-toi avec ton compte Claude.ai (Pro, Max ou Teams). L'authentification est persistante — tu n'as pas à te reconnecter à chaque session.

---

## 5. Structure du projet Flutter

Avant de démarrer, crée le projet Flutter :

```bash
flutter create pokemon_scanner
cd pokemon_scanner
```

Structure cible du projet :

```
pokemon_scanner/
├── CLAUDE.md                    # Instructions pour Claude Code
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── scan_screen.dart     # Écran caméra + OCR
│   │   └── result_screen.dart   # Résultats + prix
│   ├── services/
│   │   ├── ocr_service.dart     # Google ML Kit
│   │   └── pokemon_api.dart     # Pokémon TCG API
│   ├── models/
│   │   └── pokemon_card.dart    # Modèle de données
│   └── widgets/
│       └── price_card.dart      # Widget prix
├── pubspec.yaml
├── android/
└── ios/
```

---

## 6. Le fichier CLAUDE.md — Le cerveau du projet

Le fichier `CLAUDE.md` est **la pièce la plus importante**. Claude le lit automatiquement à chaque session et adapte son comportement en conséquence. Un bon `CLAUDE.md` de 30 lignes vaut mieux que 200 prompts répétés.

Crée ce fichier à la racine du projet :

```markdown
# CLAUDE.md — Pokemon Scanner App

## Contexte du projet
Application Flutter de scan de cartes Pokémon.
- Scan via caméra → OCR → identification → affichage du prix
- Cible : Android et iOS
- Tout doit être gratuit (pas de clé API payante)

## Stack technique
- Flutter 3.x / Dart
- google_mlkit_text_recognition pour l'OCR
- http pour les appels API
- hive_flutter pour le stockage local
- API : https://api.pokemontcg.io/v2 (gratuite, 1000 req/jour sans clé)

## Conventions de code
- Nommage : camelCase pour les variables, PascalCase pour les classes
- Un fichier = une responsabilité (pas de classes gigantesques)
- Commentaires en français
- Toujours gérer les erreurs réseau (try/catch + message utilisateur)
- Utiliser const partout où c'est possible

## Ce qu'il ne faut pas faire
- Ne jamais hardcoder de clé API
- Ne pas utiliser de packages payants
- Ne pas oublier les permissions caméra dans AndroidManifest et Info.plist

## Commandes utiles
- `flutter pub get` pour installer les dépendances
- `flutter analyze` pour vérifier le code
- `flutter run` pour lancer sur l'émulateur
```

> **Règle d'or :** chaque fois que Claude fait une erreur et que tu le corriges, ajoute la correction dans `CLAUDE.md` pour qu'elle ne se reproduise pas.

---

## 7. Les commandes essentielles

### Slash commands (dans une session active)

| Commande | Usage |
|---|---|
| `/init` | Génère automatiquement un `CLAUDE.md` en analysant ton projet |
| `/plan` | Active le Plan Mode — Claude réfléchit avant d'agir |
| `/clear` | Vide l'historique de conversation (libère le contexte) |
| `/compact` | Compresse la conversation sans la supprimer (~80k tokens → ~25k) |
| `/commit` | Génère un message de commit cohérent avec les conventions du projet |
| `/memory` | Ouvre `CLAUDE.md` dans ton éditeur pour le modifier |
| `/model` | Change de modèle (`/model opus`, `/model sonnet`, `/model haiku`) |
| `/effort` | Ajuste le niveau de raisonnement (`/effort xhigh` pour Opus) |
| `/doctor` | Vérifie l'installation (Node.js, connectivité API, permissions) |
| `/resume` | Reprend une session précédente |
| `/status` | Affiche l'état courant (modèle actif, tokens utilisés) |
| `/help` | Liste toutes les commandes disponibles |

### Flags CLI (au démarrage)

```bash
claude                          # Session interactive dans le dossier courant
claude "ajoute l'écran caméra"  # Tâche directe sans session interactive
claude -c                       # Continue la dernière session
claude -r <session-id>          # Reprend une session spécifique
claude --model opus             # Choisit le modèle dès le départ
claude --permission-mode plan   # Mode lecture seule (pas de modifications)
claude --print "résume le code" # Affiche le résultat et quitte
```

### Choisir le bon modèle

| Modèle | Usage idéal | Vitesse | Coût |
|---|---|---|---|
| **Haiku 4.5** | Exploration rapide, questions simples | ⚡⚡⚡ | $ |
| **Sonnet 4.6** | Développement quotidien, refactoring | ⚡⚡ | $$ |
| **Opus 4.8** | Architecture complexe, débogage difficile | ⚡ | $$$ |
| **Fable 5** | Tâches les plus exigeantes | ⚡ | $$$$ |

> Pour ce projet Flutter : **Sonnet 4.6** pour le développement courant, **Opus** si tu bloques sur un bug difficile.

---

## 8. Workflow recommandé — Étape par étape

### Étape 1 — Initialisation

```bash
cd pokemon_scanner
claude
```

Dans la session :
```
/init
```
Claude analyse ton projet et génère un `CLAUDE.md` de base. Complète-le avec le contenu de la section 6.

---

### Étape 2 — Planifier avant de coder (toujours !)

Pour toute tâche qui touche plus de 2 fichiers, commence par `/plan` ou `Shift+Tab` pour activer le Plan Mode. Claude analyse l'existant, propose une stratégie et attend ton accord avant de modifier quoi que ce soit.

```
/plan
Implémente l'écran de scan avec la caméra et l'OCR via google_mlkit_text_recognition
```

Claude va :
1. Lire la structure de ton projet
2. Te proposer un plan d'implémentation
3. Attendre ta validation avant d'écrire du code

---

### Étape 3 — Développement par fonctionnalité

Travaille **une fonctionnalité à la fois** et fais un `/clear` entre chaque chantier pour éviter que le contexte se pollue.

**Fonctionnalité 1 — Dépendances**
```
Ajoute les dépendances suivantes dans pubspec.yaml et explique à quoi elles servent :
- google_mlkit_text_recognition
- camera
- http
- hive_flutter
- path_provider
```

**Fonctionnalité 2 — Permissions**
```
Ajoute les permissions caméra nécessaires dans AndroidManifest.xml pour Android
et dans Info.plist pour iOS
```

**Fonctionnalité 3 — Service OCR**
```
Crée lib/services/ocr_service.dart qui :
1. Initialise google_mlkit_text_recognition
2. Prend une image en entrée (XFile)
3. Extrait le texte
4. Retourne le nom de la carte Pokémon détecté (la ligne en majuscules en haut de la carte)
```

**Fonctionnalité 4 — Service API**
```
Crée lib/services/pokemon_api.dart qui :
1. Appelle https://api.pokemontcg.io/v2/cards?q=name:{cardName}
2. Parse la réponse JSON
3. Retourne un objet PokemonCard avec : nom, set, image, prix (tcgplayer.prices)
4. Gère les erreurs réseau proprement
```

**Fonctionnalité 5 — Modèle de données**
```
Crée lib/models/pokemon_card.dart avec :
- name (String)
- setName (String)
- imageUrl (String)
- priceLow (double?)
- priceMid (double?)
- priceHigh (double?)
- Méthode fromJson() pour parser la réponse de l'API Pokémon TCG
```

**Fonctionnalité 6 — Écran de scan**
```
Crée lib/screens/scan_screen.dart qui :
1. Affiche un aperçu caméra en temps réel
2. A un bouton "Scanner" qui prend la photo
3. Appelle OcrService puis PokemonApiService
4. Affiche un indicateur de chargement pendant la recherche
5. Navigue vers ResultScreen avec la carte trouvée
6. Gère le cas "carte non trouvée" avec un message clair
```

**Fonctionnalité 7 — Écran de résultat**
```
Crée lib/screens/result_screen.dart qui affiche :
1. L'image de la carte (depuis imageUrl)
2. Le nom et le set
3. Un tableau des prix : Low / Mid / High en dollars
4. Un bouton "Scanner une autre carte"
5. Un bouton "Sauvegarder" pour l'historique local
```

**Fonctionnalité 8 — Historique local**
```
Ajoute un historique des cartes scannées avec Hive :
1. Sauvegarde chaque carte scannée localement
2. Crée un écran lib/screens/history_screen.dart qui liste les cartes
3. Ajoute un accès à l'historique depuis la ScanScreen (icône en haut à droite)
```

---

### Étape 4 — Vérification et tests

Après chaque fonctionnalité :

```bash
flutter analyze          # Vérifie le code Dart
flutter pub get          # S'assure que les dépendances sont à jour
flutter run              # Lance sur l'émulateur
```

Et dans Claude Code :
```
Analyse le fichier lib/services/ocr_service.dart et dis-moi s'il y a des problèmes
potentiels ou des cas limites non gérés
```

---

### Étape 5 — Commits propres

```
/commit
```

Claude génère un message de commit qui suit les conventions de ton repo.

---

## 9. Prompts prêts à l'emploi

Copie-colle ces prompts directement dans Claude Code selon tes besoins :

**Déboguer un problème :**
```
La reconnaissance OCR retourne toujours une chaîne vide sur des photos de cartes Pokémon.
Voici le code actuel : [colle ton code]
Analyse les causes possibles et propose une solution
```

**Améliorer la précision de l'OCR :**
```
L'OCR reconnaît parfois le mauvais texte sur la carte (numéro, PV, etc.).
Améliore la logique dans ocr_service.dart pour n'extraire que le nom de la carte
(situé en haut de la carte, généralement en gras et plus grand)
```

**Ajouter la recherche manuelle :**
```
Ajoute un champ de recherche textuelle dans scan_screen.dart en cas d'échec de l'OCR.
L'utilisateur peut taper le nom de la carte manuellement
```

**Internationalisation des prix :**
```
Les prix de l'API sont en dollars. Ajoute une conversion approximative en euros
(taux fixe configurable dans un fichier constants.dart) et affiche les deux devises
```

**Mode hors-ligne :**
```
Ajoute un cache dans pokemon_api.dart : si la même carte a déjà été cherchée,
retourne le résultat stocké dans Hive sans faire d'appel réseau
```

---

## 10. Stack technique du projet

### Dépendances Flutter (toutes gratuites)

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Caméra
  camera: ^0.11.0
  
  # OCR (Google ML Kit — gratuit, tourne en local sur le téléphone)
  google_mlkit_text_recognition: ^0.13.0
  
  # Appels réseau
  http: ^1.2.0
  
  # Stockage local
  hive_flutter: ^1.1.0
  path_provider: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  hive_generator: ^2.0.0
  build_runner: ^2.4.0
```

### API Pokémon TCG

```
Base URL : https://api.pokemontcg.io/v2
Endpoint : GET /cards?q=name:{nom}
Limite   : 1000 requêtes/jour sans clé API
           Illimité avec une clé gratuite (inscription sur pokemontcg.io)
```

**Exemple de réponse :**
```json
{
  "data": [{
    "name": "Pikachu",
    "set": { "name": "Base Set" },
    "images": { "large": "https://..." },
    "tcgplayer": {
      "prices": {
        "normal": {
          "low": 0.25,
          "mid": 1.50,
          "high": 5.00
        }
      }
    }
  }]
}
```

---

## 11. Raccourcis clavier

| Raccourci | Action |
|---|---|
| `Shift + Tab` | Bascule entre les modes : défaut → acceptEdits → plan |
| `Ctrl + C` | Interrompt Claude (utile si la réponse part dans la mauvaise direction) |
| `Ctrl + L` | Rafraîchit l'affichage du terminal (≠ `/clear` qui vide le contexte) |
| `↑ / ↓` | Navigue dans l'historique des prompts |
| `Tab` | Autocomplétion des commandes slash |

---

## 12. Conseils & Bonnes pratiques

**Sois précis dans tes demandes**  
Au lieu de "ajoute la caméra", dis "intègre le package `camera` v0.11 dans `scan_screen.dart` pour afficher un aperçu en direct et capturer une photo au clic sur le bouton flottant".

**Un `/clear` entre chaque fonctionnalité**  
Le contexte se pollue avec les anciens fichiers. Un écran vide = de meilleures réponses.

**Utilise `/plan` pour tout ce qui touche plusieurs fichiers**  
Avant un refactoring ou une fonctionnalité complexe, `/plan` te permet de corriger la trajectoire avant que Claude n'ait modifié 10 fichiers dans la mauvaise direction.

**Tiens CLAUDE.md à jour**  
Chaque erreur corrigée → une règle dans `CLAUDE.md`. C'est de la mémoire institutionnelle qui s'accumule.

**Travaille toujours sur une branche Git**  
Claude a accès à tes fichiers. Crée une branche avant chaque fonctionnalité :
```bash
git checkout -b feature/ocr-service
```

**Ne lance jamais avec `--no-confirm` sur un vrai projet**  
Ce flag désactive les demandes de confirmation. Utile en CI, dangereux en dev.

---

## 13. Tarifs

| Plan | Prix | Limites Claude Code |
|---|---|---|
| **Pro** | 20 $/mois | Limite quotidienne d'utilisation |
| **Max $100** | 100 $/mois | Limites très élevées |
| **Max $200** | 200 $/mois | L'équipe Anthropic dit ne jamais atteindre le plafond |
| **Teams** | 30 $/utilisateur/mois | Adapté pour équipes |
| **API (Console)** | Pay-as-you-go | Facturation à l'utilisation |

> Le plan **Pro à 20 $/mois** est suffisant pour construire ce projet. Passe à Max si tu fais des sessions intensives de plusieurs heures par jour.

---

## Ressources utiles

- Documentation officielle Claude Code : https://docs.claude.com/en/docs/claude-code/overview
- API Pokémon TCG : https://docs.pokemontcg.io
- Inscription API Pokémon TCG (clé gratuite illimitée) : https://pokemontcg.io
- Flutter documentation : https://docs.flutter.dev
- Google ML Kit pour Flutter : https://pub.dev/packages/google_mlkit_text_recognition

---

*Guide rédigé avec Claude Sonnet 4.6 — juin 2026*
