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

/// Service d'accès aux API de cartes Pokémon, avec cache local (hors-ligne).
///
/// Source primaire : **TCGdex** (`api.tcgdex.net`) — cartes en français natif,
/// numéro = `localId`, prix Cardmarket en euros, gratuite et sans clé.
/// Repli : **pokemontcg.io** (anglais, prix en dollars) via le dictionnaire
/// FR→EN, au cas où une carte manque côté TCGdex.
class PokemonApiService {
  final http.Client _client;

  PokemonApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Recherche une carte par son nom (français) et, idéalement, son numéro.
  ///
  /// [number] : numéro de collection optionnel (ex. « 014/131 ») pour cibler
  /// la carte exacte (donc le bon prix). Stratégie : cache → TCGdex → repli
  /// pokemontcg.io. Lève [CardNotFoundException] si introuvable,
  /// [ApiNetworkException] en cas d'échec réseau persistant.
  Future<PokemonCard> searchByName(String name, {String? number}) async {
    final query = name.trim();
    if (query.isEmpty) {
      throw CardNotFoundException(query);
    }

    final num = _parseNumerator(number);
    final denom = _parseDenominator(number);
    final cacheKey =
        num == null ? query.toLowerCase() : '${query.toLowerCase()}#$num';
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

    // 2. Recherche réseau : TCGdex puis repli pokemontcg.io.
    PokemonCard? card;
    ApiNetworkException? netError;
    try {
      card = await _searchTcgdex(query, num, denom);
    } on ApiNetworkException catch (e) {
      netError = e;
    }
    if (card == null) {
      try {
        card = await _searchPokemontcg(query, num);
      } on ApiNetworkException catch (e) {
        netError = e;
      }
    }

    if (card == null) {
      if (netError != null) throw netError;
      throw CardNotFoundException(query);
    }

    // 3. Mise en cache.
    await cacheBox.put(cacheKey, jsonEncode(card.toJson()));
    return card;
  }

  // --------------------------------------------------------------------------
  // TCGdex (source primaire, FR + prix EUR)
  // --------------------------------------------------------------------------

  /// Recherche sur TCGdex : liste large par nom, puis filtrage par numéro de
  /// carte (`localId`) et, si besoin, par taille du set (le dénominateur).
  Future<PokemonCard?> _searchTcgdex(
      String query, String? num, String? denom) async {
    // On recherche sur le 1er mot (gère « Pyroli ex » vs « Pyroli-ex »).
    final term = query.split(RegExp(r'[\s-]+')).first;
    final list = await _tcgdexList(term);
    if (list.isEmpty) return null;

    // Filtrage par numéro de carte si fourni (le filtre serveur est lâche).
    var candidates = list;
    if (num != null) {
      final byId = list
          .where((c) => _normId((c as Map)['localId']?.toString()) == num)
          .toList();
      if (byId.isNotEmpty) candidates = byId;
    }

    // Le numéro a isolé une seule carte : c'est la bonne, on la prend.
    if (num != null && candidates.length == 1) {
      final id = (candidates.first as Map)['id']?.toString();
      if (id == null) return null;
      final full = await _tcgdexCard(id);
      return full == null ? null : PokemonCard.fromTcgdex(full);
    }

    // Plusieurs candidats + dénominateur connu : on départage via le set.
    if (candidates.length > 1 && denom != null) {
      for (final c in candidates.take(8)) {
        final id = (c as Map)['id']?.toString();
        if (id == null) continue;
        final full = await _tcgdexCard(id);
        if (full != null && _matchesDenominator(full, denom)) {
          return PokemonCard.fromTcgdex(full);
        }
      }
    }

    // Sinon (numéro absent / ambigu) : on privilégie une carte qui a une cote
    // Cardmarket — ça évite les vieux promos sans prix et garde l'affichage en
    // euros. À défaut, on retombe sur le 1er candidat.
    Map<String, dynamic>? firstFull;
    for (final c in candidates.take(8)) {
      final id = (c as Map)['id']?.toString();
      if (id == null) continue;
      final full = await _tcgdexCard(id);
      if (full == null) continue;
      firstFull ??= full;
      if (_hasPricing(full)) return PokemonCard.fromTcgdex(full);
    }
    return firstFull == null ? null : PokemonCard.fromTcgdex(firstFull);
  }

  /// Liste « brève » des cartes dont le nom contient [term]. Le filtre TCGdex
  /// est un « contains » : un caractère en trop de l'OCR (« Drattake » au lieu
  /// de « Drattak ») renvoie une liste vide → on retente en rognant la fin.
  Future<List<dynamic>> _tcgdexList(String term) async {
    for (final t in _searchTerms(term)) {
      final uri = Uri.https('api.tcgdex.net', '/v2/fr/cards', {'name': t});
      final json = await _getJson(uri);
      if (json is List && json.isNotEmpty) return json;
    }
    return const [];
  }

  /// Termes à essayer : le mot, puis rogné de 1 à 2 caractères en fin (pour
  /// absorber le bruit d'OCR), sans descendre sous 4 caractères.
  Iterable<String> _searchTerms(String term) sync* {
    yield term;
    for (var cut = 1; cut <= 2; cut++) {
      if (term.length - cut >= 4) yield term.substring(0, term.length - cut);
    }
  }

  /// Vrai si la carte expose au moins un prix Cardmarket.
  bool _hasPricing(Map<String, dynamic> full) {
    final variants = full['variants_detailed'] as List<dynamic>?;
    if (variants == null) return false;
    for (final v in variants) {
      final cm = ((v as Map)['pricing'] as Map?)?['cardmarket'] as Map?;
      if (cm != null && (cm['low'] != null || cm['avg'] != null)) return true;
    }
    return false;
  }

  /// Détail complet d'une carte TCGdex (inclut le set et les prix).
  Future<Map<String, dynamic>?> _tcgdexCard(String id) async {
    final uri = Uri.https('api.tcgdex.net', '/v2/fr/cards/$id');
    final json = await _getJson(uri);
    return json is Map<String, dynamic> ? json : null;
  }

  /// Vrai si le set de la carte compte [denom] cartes (officielles ou totales).
  bool _matchesDenominator(Map<String, dynamic> full, String denom) {
    final target = int.tryParse(denom);
    if (target == null) return false;
    final count = (full['set'] as Map<String, dynamic>?)?['cardCount'] as Map?;
    return count?['official'] == target || count?['total'] == target;
  }

  // --------------------------------------------------------------------------
  // pokemontcg.io (repli, EN + prix USD)
  // --------------------------------------------------------------------------

  /// Repli historique : traduit FR→EN puis interroge pokemontcg.io.
  Future<PokemonCard?> _searchPokemontcg(String query, String? num) async {
    final english = NameTranslator.instance.toEnglish(query);
    final namesToTry = <String>[
      if (english != null) english,
      query,
    ];
    debugPrint('[Repli pokemontcg] "$query" (n°$num) → $namesToTry');

    for (final n in namesToTry) {
      final firstWord = n.split(RegExp(r'\s+')).first;
      PokemonCard? card;
      if (num != null) {
        card = await _pokemontcgQuery('name:"$n" number:"$num"') ??
            await _pokemontcgQuery('name:"$n*" number:"$num"');
      }
      card ??= await _pokemontcgQuery('name:"$n"') ??
          await _pokemontcgQuery('name:"$n*"') ??
          await _pokemontcgQuery('name:"*$firstWord*"');
      if (card != null) return card;
    }
    return null;
  }

  /// Exécute une requête pokemontcg.io avec le filtre `q`. Retourne la 1re
  /// carte ou `null` si aucun résultat.
  Future<PokemonCard?> _pokemontcgQuery(String q) async {
    final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
      'q': q,
      'pageSize': '1',
      'orderBy': '-set.releaseDate',
    });
    final json = await _getJson(uri);
    final data = json is Map ? json['data'] as List<dynamic>? : null;
    if (data == null || data.isEmpty) return null;
    return PokemonCard.fromJson(data.first as Map<String, dynamic>);
  }

  // --------------------------------------------------------------------------
  // Couche HTTP commune
  // --------------------------------------------------------------------------

  /// GET JSON générique : 2 tentatives, timeout 20s. Retourne le corps décodé
  /// (List ou Map), `null` sur 404, lève [ApiNetworkException] si le réseau
  /// échoue durablement.
  Future<dynamic> _getJson(Uri uri) async {
    debugPrint('[Api] GET $uri');
    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await _client.get(uri, headers: {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 20));

        if (response.statusCode == 404) return null;
        if (response.statusCode != 200) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }
        return jsonDecode(response.body);
      } catch (e) {
        debugPrint('[Api] tentative $attempt échouée: $e');
        lastError = e;
      }
    }
    throw ApiNetworkException(
      'Connexion à l\'API impossible (réseau lent ou indisponible). '
      'Réessaie. [$lastError]',
    );
  }

  // --------------------------------------------------------------------------
  // Utilitaires numéro de carte
  // --------------------------------------------------------------------------

  /// Numérateur exploitable : « 014/142 » → « 14 », « TG12/TG30 » → « TG12 ».
  String? _parseNumerator(String? input) {
    if (input == null) return null;
    var raw = input.trim();
    if (raw.isEmpty) return null;
    raw = raw.split('/').first.trim();
    return _normId(raw);
  }

  /// Dénominateur (taille du set) : « 014/131 » → « 131 », sinon `null`.
  String? _parseDenominator(String? input) {
    if (input == null || !input.contains('/')) return null;
    final parts = input.split('/');
    if (parts.length < 2) return null;
    final raw = parts[1].trim().replaceFirst(RegExp(r'^0+'), '');
    return raw.isEmpty ? null : raw;
  }

  /// Normalise un identifiant de carte pour comparaison :
  /// « 014 » → « 14 », « 4A » → « 4A », « TG12 » → « TG12 ».
  String? _normId(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(t)) {
      final stripped = t.replaceFirst(RegExp(r'^0+'), '');
      return stripped.isEmpty ? '0' : stripped;
    }
    return t.toUpperCase();
  }

  void dispose() {
    _client.close();
  }
}
