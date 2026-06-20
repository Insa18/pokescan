# Pokémon Scanner 📷

App Flutter qui scanne une carte Pokémon avec la caméra, lit son nom par OCR
(Google ML Kit, en local), interroge l'[API Pokémon TCG](https://pokemontcg.io)
et affiche les prix du marché (Low / Mid / High en $ et €). Historique local
et cache hors-ligne inclus.

## Fonctionnalités
- 📸 Aperçu caméra + capture avec cadre de visée
- 🔤 OCR local (gratuit) pour détecter le nom de la carte
- 🔎 Recherche API + repli en **saisie manuelle** si l'OCR échoue
- 💲 Prix Low / Mid / High en dollars **et** euros
- 💾 Historique des cartes (Hive) + **cache hors-ligne** (pas de re-requête)

---

## ⚙️ Installation (à faire une fois Flutter installé)

> ⚠️ Flutter n'est pas installé sur cette machine. Installe-le d'abord :
> https://docs.flutter.dev/get-started/install — puis `flutter doctor`.

Ce dépôt contient déjà tout le code applicatif (`lib/`, `pubspec.yaml`,
permissions). Il manque uniquement les dossiers natifs (`android/`, `ios/`)
que seul Flutter peut générer. Depuis ce dossier :

```bash
cd pokemon_scanner

# 1. Génère les dossiers natifs SANS écraser le code existant
#    (lib/, pubspec.yaml et AndroidManifest.xml déjà présents sont conservés)
flutter create .

# 2. Installe les dépendances
flutter pub get

# 3. Applique les permissions iOS
#    Copie le contenu de ios/Runner/Info.plist.additions.xml
#    dans ios/Runner/Info.plist (dans le <dict> racine).
#    Les permissions Android sont déjà dans android/.../AndroidManifest.xml.

# 4. Lance sur un appareil réel (la caméra ne marche pas sur la plupart
#    des émulateurs)
flutter run
```

### Vérifications
```bash
flutter analyze   # qualité du code
flutter pub get   # dépendances à jour
```

---

## 🔑 API Pokémon TCG
- Base : `https://api.pokemontcg.io/v2`
- 1000 requêtes/jour sans clé. Pour passer en illimité, crée une clé gratuite
  sur https://pokemontcg.io et ajoute l'en-tête `X-Api-Key` dans
  `lib/services/pokemon_api.dart`.

## 🗂️ Structure
```
lib/
├── main.dart                 # init Hive + caméras
├── constants.dart            # URL API, taux EUR, boîtes Hive
├── models/pokemon_card.dart
├── services/
│   ├── ocr_service.dart      # Google ML Kit
│   ├── pokemon_api.dart      # API + cache hors-ligne
│   └── history_service.dart  # historique Hive
├── screens/
│   ├── scan_screen.dart      # caméra + OCR
│   ├── result_screen.dart    # prix
│   └── history_screen.dart
└── widgets/price_card.dart
```

## 📝 Notes
- Hive est utilisé **sans codegen** (sérialisation JSON) : aucune commande
  `build_runner` nécessaire.
- Voir `CLAUDE.md` pour les conventions et choix d'architecture.
