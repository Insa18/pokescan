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

  /// Clé de stockage d'une carte (id si dispo, sinon nom) → évite les doublons.
  String _keyOf(PokemonCard card) =>
      card.id.isNotEmpty ? card.id : card.name.toLowerCase();

  /// Sauvegarde (ou met à jour) une carte dans l'historique.
  Future<void> save(PokemonCard card) async {
    await _box.put(_keyOf(card), jsonEncode(card.toJson()));
  }

  /// Indique si la carte est déjà enregistrée.
  bool contains(PokemonCard card) => _box.containsKey(_keyOf(card));

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
    await _box.delete(_keyOf(card));
  }

  /// Vide tout l'historique.
  Future<void> clear() async {
    await _box.clear();
  }
}
