import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/pokemon_card.dart';
import 'name_translator.dart';

/// Exception levée lorsqu'aucune carte n'est trouvée pour un nom donné.
class CardNotFoundException implements Exception {
  final String query;
  CardNotFoundException(this.query);
  @override
  String toString() => 'Aucune carte trouvée pour « $query ».';
}

/// Exception levée en cas de problème réseau / serveur.
class ApiNetworkException implements Exception {
  final String message;
  ApiNetworkException(this.message);
  @override
  String toString() => message;
}

/// Service d'accès à l'API Pokémon TCG, avec cache local (mode hors-ligne).
class PokemonApiService {
  final http.Client _client;

  PokemonApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Recherche une carte par son nom.
  ///
  /// Stratégie : cache → recherche exacte → recherche partielle (wildcard).
  /// Réessaie automatiquement en cas d'erreur réseau (l'API publique est
  /// parfois lente). Lève [CardNotFoundException] si introuvable,
  /// [ApiNetworkException] en cas d'échec réseau persistant.
  /// [number] : numéro de collection optionnel (ex. « 14 » ou « 014/142 »)
  /// pour cibler la carte exacte (donc le bon prix).
  Future<PokemonCard> searchByName(String name, {String? number}) async {
    final query = name.trim();
    if (query.isEmpty) {
      throw CardNotFoundException(query);
    }

    final num = _parseNumber(number);
    final cacheKey = num == null
        ? query.toLowerCase()
        : '${query.toLowerCase()}#$num';
    final cacheBox = Hive.box(kCardCacheBoxName);

    // 1. Lecture du cache.
    final cached = cacheBox.get(cacheKey);
    if (cached is String) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        return PokemonCard.fromStorage(map);
      } catch (_) {
        // Cache corrompu : on l'ignore et on requête le réseau.
      }
    }

    // 2. Traduction FR→EN (l'API n'indexe que l'anglais), puis recherche.
    //    On tente d'abord le nom anglais, puis le nom brut en repli.
    final english = NameTranslator.instance.toEnglish(query);
    final namesToTry = <String>[
      if (english != null) english,
      query,
    ];
    debugPrint('[PokemonApi] "$query" (n°$num) → tentatives: $namesToTry');

    PokemonCard? card;
    for (final n in namesToTry) {
      final firstWord = n.split(RegExp(r'\s+')).first;
      // Avec un numéro : on le combine au nom pour viser la carte exacte.
      if (num != null) {
        card = await _query('name:"$n" number:"$num"') ??
            await _query('name:"$n*" number:"$num"');
      }
      // Sinon (ou si le numéro n'a rien donné) : recherche par nom seul.
      card ??= await _query('name:"$n"') ??
          await _query('name:"$n*"') ??
          await _query('name:"*$firstWord*"');
      if (card != null) break;
    }

    if (card == null) {
      throw CardNotFoundException(query);
    }

    // 3. Mise en cache.
    await cacheBox.put(cacheKey, jsonEncode(card.toJson()));
    return card;
  }

  /// Extrait le numéro de collection exploitable par l'API.
  /// « 014/142 » → « 14 », « 14 » → « 14 », « TG12/TG30 » → « TG12 ».
  String? _parseNumber(String? input) {
    if (input == null) return null;
    var raw = input.trim();
    if (raw.isEmpty) return null;
    // Garde la partie avant le « / » (numérateur).
    raw = raw.split('/').first.trim();
    if (raw.isEmpty) return null;
    // Retire les zéros de tête pour un numéro purement chiffré (014 → 14),
    // mais conserve les préfixes alphanumériques (TG12, SV001…).
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      final stripped = raw.replaceFirst(RegExp(r'^0+'), '');
      return stripped.isEmpty ? '0' : stripped;
    }
    return raw;
  }

  /// Exécute une requête API avec le filtre `q` donné. Retourne la 1re carte
  /// ou `null` si aucun résultat. Réessaie une fois en cas d'erreur réseau.
  Future<PokemonCard?> _query(String q) async {
    final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
      'q': q,
      'pageSize': '1',
      'orderBy': '-set.releaseDate',
    });
    debugPrint('[PokemonApi] GET $uri');

    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await _client
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          debugPrint('[PokemonApi] HTTP ${response.statusCode}');
          lastError = 'HTTP ${response.statusCode}';
          continue; // réessaie
        }

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>?;
        if (data == null || data.isEmpty) return null;
        return PokemonCard.fromJson(data.first as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[PokemonApi] tentative $attempt échouée: $e');
        lastError = e;
      }
    }

    throw ApiNetworkException(
      'Connexion à l\'API impossible (réseau lent ou indisponible). '
      'Réessaie. [$lastError]',
    );
  }

  void dispose() {
    _client.close();
  }
}
