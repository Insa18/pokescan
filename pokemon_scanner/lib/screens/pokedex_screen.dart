import 'package:flutter/material.dart';

import '../models/pokemon_card.dart';
import '../services/history_service.dart';
import '../theme.dart';
import '../widgets/pokeball_icon.dart';
import '../widgets/pokedex_icon.dart';
import 'result_screen.dart';

/// Pokédex : collection des cartes scannées et enregistrées.
///
/// Vue en grille (images des cartes) avec un en-tête récapitulatif
/// (nombre de cartes + valeur totale estimée en euros). Les données viennent
/// du même stockage local que la sauvegarde de l'écran résultat.
class PokedexScreen extends StatefulWidget {
  const PokedexScreen({super.key});

  @override
  State<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends State<PokedexScreen> {
  final HistoryService _history = HistoryService();
  late List<PokemonCard> _cards;

  @override
  void initState() {
    super.initState();
    _cards = _history.getAll();
  }

  void _refresh() => setState(() => _cards = _history.getAll());

  /// Valeur totale estimée de la collection (somme des prix en euros).
  double get _totalEur => _cards.fold(0, (sum, c) => sum + (c.valueEur ?? 0));

  Future<void> _confirmDelete(PokemonCard card) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer ${card.name} ?'),
        content: const Text('Cette carte sera retirée de ton Pokédex.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _history.delete(card);
      _refresh();
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider le Pokédex ?'),
        content: const Text('Toutes les cartes enregistrées seront supprimées. '
            'Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _history.clear();
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokédex'),
        actions: [
          if (_cards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Vider le Pokédex',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _cards.isEmpty
          ? const _EmptyState()
          : Column(
              children: [
                _SummaryBar(count: _cards.length, totalEur: _totalEur),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) => _CardTile(
                        card: _cards[index], onDeleteRequested: _confirmDelete),
                  ),
                ),
              ],
            ),
    );
  }
}

/// En-tête : nombre de cartes + valeur totale estimée.
class _SummaryBar extends StatelessWidget {
  final int count;
  final double totalEur;
  const _SummaryBar({required this.count, required this.totalEur});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: PokeColors.red,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(value: '$count', label: count > 1 ? 'cartes' : 'carte'),
          Container(width: 1, height: 32, color: Colors.white24),
          _Stat(value: '${totalEur.toStringAsFixed(2)} €', label: 'valeur'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

/// Tuile d'une carte dans la grille.
class _CardTile extends StatelessWidget {
  final PokemonCard card;
  final Future<void> Function(PokemonCard) onDeleteRequested;

  const _CardTile({
    required this.card,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(card: card)),
      ),
      onLongPress: () => onDeleteRequested(card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: card.imageUrl.isNotEmpty
                  ? Image.network(
                      card.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ImageFallback(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const _ImageFallback(),
                    )
                  : const _ImageFallback(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            card.formatPrice(card.priceMid),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PokeColors.cream,
      child: const Center(child: PokeballIcon(size: 36)),
    );
  }
}

/// Affichage quand le Pokédex est vide.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PokedexIcon(size: 72, color: PokeColors.red),
          const SizedBox(height: 12),
          Text('Ton Pokédex est vide',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Scanne une carte puis touche « Sauvegarder »\npour l\'ajouter ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
