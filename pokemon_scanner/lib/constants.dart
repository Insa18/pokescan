/// Constantes globales de l'application.
library;

/// URL de base de l'API Pokémon TCG (gratuite, 1000 req/jour sans clé).
const String kPokemonApiBaseUrl = 'https://api.pokemontcg.io/v2';

/// Taux de conversion approximatif Dollar → Euro.
/// Les prix de l'API sont en USD ; on affiche aussi une estimation en EUR.
const double kUsdToEurRate = 0.92;

/// Noms des boîtes Hive utilisées pour le stockage local.
const String kHistoryBoxName = 'history';
const String kCardCacheBoxName = 'card_cache';
