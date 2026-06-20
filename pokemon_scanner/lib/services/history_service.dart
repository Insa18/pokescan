import 'dart:convert';

import 'package:hive/hive.dart';

import '../constants.dart';
import '../models/pokemon_card.dart';

/// Gère l'historique local des cartes scannées (stockage Hive).
///
/// Chaque carte est sérialisée en JSON et stockée par son id, ce qui évite
/// les doublons : re-scanner la même carte met simplement à jour l'entrée.
class HistoryService {
  Box get _box => Hive.box(kHistoryBoxName);

  /// Sauvegarde (ou met à jour) une carte dans l'historique.
  Future<void> save(PokemonCard card) async {
    final key = card.id.isNotEmpty ? card.id : card.name.toLowerCase();
    await _box.put(key, jsonEncode(card.toJson()));
  }

  /// Retourne toutes les cartes de l'historique (plus récentes en premier).
  List<PokemonCard> getAll() {
    final cards = <PokemonCard>[];
    for (final value in _box.values) {
      if (value is String) {
        try {
          final map = jsonDecode(value) as Map<String, dynamic>;
          cards.add(PokemonCard.fromStorage(map));
        } catch (_) {
          // Entrée illisible : on l'ignore.
        }
      }
    }
    return cards.reversed.toList();
  }

  /// Supprime une carte de l'historique.
  Future<void> delete(PokemonCard card) async {
    final key = card.id.isNotEmpty ? card.id : card.name.toLowerCase();
    await _box.delete(key);
  }

  /// Vide tout l'historique.
  Future<void> clear() async {
    await _box.clear();
  }
}
