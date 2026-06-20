import '../constants.dart';
import '../services/name_translator.dart';

/// Modèle de données représentant une carte Pokémon et ses prix.
class PokemonCard {
  final String id;
  final String name;
  final String number;
  final String setName;
  final String imageUrl;
  final double? priceLow;
  final double? priceMid;
  final double? priceHigh;

  /// Devise des prix : « EUR » (TCGdex/Cardmarket) ou « USD » (pokemontcg.io).
  final String currency;

  /// Lien Cardmarket (peut être nul ; voir [cardmarketLink] pour un repli).
  final String? cardmarketUrl;

  const PokemonCard({
    required this.id,
    required this.name,
    required this.setName,
    required this.imageUrl,
    this.number = '',
    this.priceLow,
    this.priceMid,
    this.priceHigh,
    this.currency = 'USD',
    this.cardmarketUrl,
  });

  /// Lien vers Cardmarket : l'URL fournie si elle existe, sinon une
  /// recherche Cardmarket construite à partir du nom de la carte.
  String get cardmarketLink {
    if (cardmarketUrl != null && cardmarketUrl!.isNotEmpty) {
      return cardmarketUrl!;
    }
    final q = Uri.encodeQueryComponent(name);
    return 'https://www.cardmarket.com/en/Pokemon/Products/Search?searchString=$q';
  }

  /// Valeur indicative de la carte en euros (prix moyen, sinon haut/bas),
  /// pour calculer la valeur totale d'une collection. `null` si aucun prix.
  double? get valueEur {
    final v = priceMid ?? priceHigh ?? priceLow;
    if (v == null) return null;
    return currency == 'EUR' ? v : v * kUsdToEurRate;
  }

  /// Formate un prix selon la devise de la carte.
  /// EUR (Cardmarket) : « 5.13 € ». USD (pokemontcg) : « $6.85 • 6.30 € ».
  String formatPrice(double? value) {
    if (value == null) return '—';
    if (currency == 'EUR') return '${value.toStringAsFixed(2)} €';
    final eur = value * kUsdToEurRate;
    return '\$${value.toStringAsFixed(2)} • ${eur.toStringAsFixed(2)} €';
  }

  /// Construit une carte à partir d'un objet JSON **TCGdex** (langue FR).
  ///
  /// Avantages : nom déjà en français, numéro = `localId`, prix Cardmarket
  /// en **euros** directement (`variants_detailed[].pricing.cardmarket`).
  factory PokemonCard.fromTcgdex(Map<String, dynamic> json) {
    // Image : l'API donne une base d'URL, on ajoute qualité + extension.
    final base = (json['image'] ?? '') as String;
    final imageUrl = base.isEmpty ? '' : '$base/high.png';

    // Nom du set (en français).
    final set = json['set'] as Map<String, dynamic>?;
    final setName = (set?['name'] ?? 'Set inconnu') as String;

    final name = (json['name'] ?? 'Inconnu') as String;

    // Prix Cardmarket (EUR) : on prend la 1re variante qui en expose.
    // bas = low, moyen = avg, haut = trend (tendance du marché).
    double? low, mid, high;
    final variants = json['variants_detailed'] as List<dynamic>?;
    if (variants != null) {
      for (final v in variants) {
        final pricing = (v as Map)['pricing'] as Map<String, dynamic>?;
        final cm = pricing?['cardmarket'] as Map<String, dynamic>?;
        if (cm != null) {
          low = _toDouble(cm['low']);
          mid = _toDouble(cm['avg']);
          high = _toDouble(cm['trend']);
          if (low != null || mid != null || high != null) break;
        }
      }
    }

    // Lien Cardmarket : on traduit le nom FR en EN (le catalogue Cardmarket
    // est en anglais) pour une recherche pertinente, sinon repli sur le nom FR.
    final english = NameTranslator.instance.toEnglish(name);
    final cmUrl = english == null
        ? null
        : 'https://www.cardmarket.com/en/Pokemon/Products/Search?'
            'searchString=${Uri.encodeQueryComponent(english)}';

    return PokemonCard(
      id: (json['id'] ?? '') as String,
      name: name,
      number: (json['localId'] ?? '') as String,
      setName: setName,
      imageUrl: imageUrl,
      priceLow: low,
      priceMid: mid,
      priceHigh: high,
      currency: 'EUR',
      cardmarketUrl: cmUrl,
    );
  }

  /// Construit une carte à partir d'un objet JSON de l'API Pokémon TCG
  /// (pokemontcg.io, utilisée en repli). Prix en **dollars**.
  ///
  /// La structure des prix est :
  /// `tcgplayer.prices.{normal|holofoil|...}.{low|mid|high}`.
  factory PokemonCard.fromJson(Map<String, dynamic> json) {
    // Récupère l'image (large en priorité, sinon small).
    final images = json['images'] as Map<String, dynamic>?;
    final imageUrl = (images?['large'] ?? images?['small'] ?? '') as String;

    // Nom du set.
    final set = json['set'] as Map<String, dynamic>?;
    final setName = (set?['name'] ?? 'Set inconnu') as String;

    // Extraction des prix (première variante trouvée).
    double? low, mid, high;
    final tcgplayer = json['tcgplayer'] as Map<String, dynamic>?;
    final prices = tcgplayer?['prices'] as Map<String, dynamic>?;
    if (prices != null && prices.isNotEmpty) {
      final firstVariant = prices.values.first as Map<String, dynamic>?;
      if (firstVariant != null) {
        low = _toDouble(firstVariant['low']);
        mid = _toDouble(firstVariant['mid']);
        high = _toDouble(firstVariant['high']);
      }
    }

    // Lien Cardmarket (souvent absent sur les cartes récentes).
    final cardmarket = json['cardmarket'] as Map<String, dynamic>?;
    final cmUrl = cardmarket?['url'] as String?;

    return PokemonCard(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? 'Inconnu') as String,
      number: (json['number'] ?? '') as String,
      setName: setName,
      imageUrl: imageUrl,
      priceLow: low,
      priceMid: mid,
      priceHigh: high,
      currency: 'USD',
      cardmarketUrl: cmUrl,
    );
  }

  /// Sérialisation pour le stockage local (Hive / cache).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'number': number,
        'setName': setName,
        'imageUrl': imageUrl,
        'priceLow': priceLow,
        'priceMid': priceMid,
        'priceHigh': priceHigh,
        'currency': currency,
        'cardmarketUrl': cardmarketUrl,
      };

  /// Désérialisation depuis le stockage local.
  factory PokemonCard.fromStorage(Map<String, dynamic> json) => PokemonCard(
        id: (json['id'] ?? '') as String,
        name: (json['name'] ?? 'Inconnu') as String,
        number: (json['number'] ?? '') as String,
        setName: (json['setName'] ?? '') as String,
        imageUrl: (json['imageUrl'] ?? '') as String,
        priceLow: _toDouble(json['priceLow']),
        priceMid: _toDouble(json['priceMid']),
        priceHigh: _toDouble(json['priceHigh']),
        currency: (json['currency'] ?? 'USD') as String,
        cardmarketUrl: json['cardmarketUrl'] as String?,
      );

  /// Convertit en double une valeur qui peut être int, double, String ou null.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
