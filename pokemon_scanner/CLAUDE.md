# CLAUDE.md — Pokemon Scanner App

## Contexte du projet
Application Flutter de scan de cartes Pokémon.
- Scan via caméra → OCR → identification → affichage du prix
- Cible : Android (iOS abandonné : nécessite un Mac + compte Apple Developer)
- Tout doit rester gratuit (pas de clé API payante)

## Stack technique
- Flutter 3.x / Dart (SDK >= 3.3)
- `camera` pour l'aperçu live et la capture
- `google_mlkit_text_recognition` pour l'OCR (local, gratuit)
- `http` pour les appels API
- `hive` / `hive_flutter` pour le stockage local (historique + cache)
- API primaire : https://api.tcgdex.net/v2/fr (cartes FR natives + prix Cardmarket €, gratuite, sans clé)
- API repli : https://api.pokemontcg.io/v2 (anglais, prix $, 1000 req/jour sans clé)

## Architecture (lib/)
- `main.dart` — init Hive + caméras, lance ScanScreen
- `constants.dart` — URL API, taux EUR, noms des boîtes Hive
- `models/pokemon_card.dart` — modèle + fromJson/toJson
- `services/ocr_service.dart` — extraction du nom de carte
- `services/pokemon_api.dart` — recherche API + cache hors-ligne
- `services/history_service.dart` — historique local (Hive)
- `screens/` — scan_screen, result_screen, history_screen
- `widgets/price_card.dart` — affichage des prix Low/Mid/High ($ et €)

## Conventions de code
- camelCase pour les variables, PascalCase pour les classes
- Un fichier = une responsabilité
- Commentaires en français
- Toujours gérer les erreurs réseau (try/catch + message utilisateur)
- Utiliser `const` partout où c'est possible

## Choix d'implémentation notables
- Hive est utilisé SANS codegen (pas de hive_generator/build_runner) :
  les cartes sont sérialisées en JSON (`toJson`) et stockées en String.
  → l'app tourne après un simple `flutter pub get`, sans `build_runner`.
- L'OCR sélectionne la ligne la plus haute/grande du tiers supérieur de
  l'image (heuristique pour cibler le nom de la carte).
- Repli saisie manuelle si l'OCR échoue ou si la carte est introuvable.

## Ce qu'il ne faut pas faire
- Ne jamais hardcoder de clé API
- Ne pas utiliser de packages payants
- Ne pas oublier les permissions caméra (AndroidManifest)

## Commandes utiles
- `flutter pub get` — installe les dépendances
- `flutter analyze` — vérifie le code
- `flutter run` — lance sur l'appareil/émulateur (caméra réelle requise)
