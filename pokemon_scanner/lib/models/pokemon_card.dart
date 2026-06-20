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
    this.cardmarketUrl,
  });

  /// Lien vers Cardmarket : l'URL fournie par l'API si elle existe, sinon une
  /// recherche Cardmarket construite à partir du nom (anglais) de la carte.
  String get cardmarketLink {
    if (cardmarketUrl != null && cardmarketUrl!.isNotEmpty) {
      return cardmarketUrl!;
    }
    final q = Uri.encodeQueryComponent(name);
    return 'https://www.cardmarket.com/en/Pokemon/Products/Search?searchString=$q';
  }

  /// Construit une carte à partir d'un objet JSON de l'API Pokémon TCG.
  ///
  /// La structure des prix est :
  /// `tcgplayer.prices.{normal|holofoil|...}.{low|mid|high}`.
  /// On prend la première variante de prix disponible.
  factory PokemonCard.fromJson(Map<String, dynamic> json) {
    // Récupère l'image (large en priorité, sinon small).
    final images = json['images'] as Map<String, dynamic>?;
    final imageUrl =
        (images?['large'] ?? images?['small'] ?? '') as String;

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
        cardmarketUrl: json['cardmarketUrl'] as String?,
      );

  /// Convertit en double une valeur qui peut être int, double, String ou null.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
