import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Traduit les noms de Pokémon français ⇄ anglais.
///
/// L'API Pokémon TCG n'indexe que les noms anglais. Les cartes françaises
/// scannées (ex. « Pyroli ex ») doivent donc être traduites (« Flareon ex »)
/// avant la recherche. La comparaison se fait **sans accents** car l'OCR les
/// mange souvent (« Héricendre » lu « Hericendre »).
class NameTranslator {
  NameTranslator._();
  static final NameTranslator instance = NameTranslator._();

  /// nom français original (minuscules, accents conservés) → nom anglais.
  Map<String, String> _frToEn = {};

  /// nom français NORMALISÉ (sans accents) → nom anglais.
  Map<String, String> _normFrToEn = {};

  /// nom anglais NORMALISÉ → nom français original (pour l'affichage).
  Map<String, String> _normEnToFr = {};

  bool get isLoaded => _frToEn.isNotEmpty;

  /// Suffixes de cartes spéciales, identiques en FR/EN (forme normalisée).
  static const Map<String, String> _suffixes = {
    'ex': 'ex',
    'gx': 'GX',
    'v': 'V',
    'vmax': 'VMAX',
    'vstar': 'VSTAR',
  };

  /// Charge le dictionnaire (à appeler une fois au démarrage).
  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/fr_en_pokemon.json');
      _frToEn = (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
      _normFrToEn = {
        for (final e in _frToEn.entries) _normalize(e.key): e.value,
      };
      _normEnToFr = {
        for (final e in _frToEn.entries) _normalize(e.value): e.key,
      };
      debugPrint('[Translator] ${_frToEn.length} noms FR↔EN chargés');
    } catch (e) {
      debugPrint('[Translator] échec de chargement: $e');
      _frToEn = {};
    }
  }

  /// Retourne le nom anglais à utiliser pour la requête API, suffixe inclus
  /// (ex. « Flareon ex »), ou `null` si le nom français est inconnu.
  String? toEnglish(String detected) {
    final (base, suffix) = _splitNameAndSuffix(detected);
    if (base.isEmpty) return null;

    // 1. Correspondance exacte (sans accents), du nom complet au plus court.
    for (var n = base.length; n >= 1; n--) {
      final candidate = base.sublist(0, n).join(' ');
      final english = _normFrToEn[candidate];
      if (english != null) return _withSuffix(english, suffix);
    }

    // 2. Tolérance OCR : le 1er mot contient/finit par une clé connue
    //    (ex. « ahericendre » → « hericendre »). On prend la plus longue.
    final token = base.first;
    String? bestEn;
    var bestLen = 0;
    for (final entry in _normFrToEn.entries) {
      final key = entry.key;
      if (key.length >= 4 &&
          key.length > bestLen &&
          (token.endsWith(key) || token.contains(key))) {
        bestEn = entry.value;
        bestLen = key.length;
      }
    }
    if (bestEn != null) return _withSuffix(bestEn, suffix);

    return null;
  }

  /// Retourne le nom français d'une carte anglaise (ex. « Flareon ex » →
  /// « Pyroli ex »), suffixe conservé, ou `null` si inconnu.
  String? toFrench(String englishCardName) {
    final (base, suffix) = _splitNameAndSuffix(englishCardName);
    if (base.isEmpty) return null;

    for (var n = base.length; n >= 1; n--) {
      final candidate = base.sublist(0, n).join(' ');
      final french = _normEnToFr[candidate];
      if (french != null) return _withSuffix(_capitalize(french), suffix);
    }
    return null;
  }

  // --- Helpers ---

  /// Découpe un nom en (mots normalisés sans suffixe, suffixe normalisé).
  (List<String>, String) _splitNameAndSuffix(String name) {
    final norm = _normalize(name);
    if (norm.isEmpty) return (const [], '');
    final words = norm.split(' ');
    var suffix = '';
    final base = List<String>.from(words);
    if (base.length > 1 && _suffixes.containsKey(base.last)) {
      suffix = _suffixes[base.last]!;
      base.removeLast();
    }
    return (base, suffix);
  }

  String _withSuffix(String name, String suffix) =>
      suffix.isEmpty ? name : '$name $suffix';

  /// Minuscule + suppression des accents + espaces compactés.
  String _normalize(String s) {
    final lower = s.toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      buf.write(_accents[ch] ?? ch);
    }
    return buf
        .toString()
        .replaceAll(RegExp(r"[^a-z0-9 '\-]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _capitalize(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static const Map<String, String> _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
    'ç': 'c', 'ñ': 'n', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
  };
}
