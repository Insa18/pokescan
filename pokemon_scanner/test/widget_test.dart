import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_scanner/models/pokemon_card.dart';

void main() {
  group('PokemonCard.fromJson', () {
    test('parse une réponse complète de l\'API Pokémon TCG', () {
      final json = {
        'id': 'base1-58',
        'name': 'Pikachu',
        'set': {'name': 'Base Set'},
        'images': {
          'small': 'https://img/small.png',
          'large': 'https://img/large.png',
        },
        'tcgplayer': {
          'prices': {
            'normal': {'low': 0.25, 'mid': 1.5, 'high': 5.0},
          },
        },
      };

      final card = PokemonCard.fromJson(json);

      expect(card.id, 'base1-58');
      expect(card.name, 'Pikachu');
      expect(card.setName, 'Base Set');
      expect(card.imageUrl, 'https://img/large.png'); // large prioritaire
      expect(card.priceLow, 0.25);
      expect(card.priceMid, 1.5);
      expect(card.priceHigh, 5.0);
    });

    test('gère l\'absence de prix et de set sans planter', () {
      final card = PokemonCard.fromJson({'name': 'Salamèche'});

      expect(card.name, 'Salamèche');
      expect(card.setName, 'Set inconnu');
      expect(card.imageUrl, '');
      expect(card.priceLow, isNull);
      expect(card.priceMid, isNull);
    });

    test('round-trip toJson / fromStorage', () {
      const original = PokemonCard(
        id: 'x',
        name: 'Dracaufeu',
        setName: 'Set X',
        imageUrl: 'https://img',
        priceLow: 10,
        priceMid: 20,
        priceHigh: 30,
      );

      final restored = PokemonCard.fromStorage(original.toJson());

      expect(restored.name, 'Dracaufeu');
      expect(restored.priceHigh, 30);
    });
  });
}
