import 'package:flutter/material.dart';

import '../models/pokemon_card.dart';
import '../services/history_service.dart';
import 'result_screen.dart';

/// Écran listant les cartes scannées et sauvegardées (historique local).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _history = HistoryService();
  late List<PokemonCard> _cards;

  @override
  void initState() {
    super.initState();
    _cards = _history.getAll();
  }

  void _refresh() => setState(() => _cards = _history.getAll());

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider l\'historique ?'),
        content: const Text('Cette action est irréversible.'),
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
        title: const Text('Historique'),
        actions: [
          if (_cards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Vider l\'historique',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _cards.isEmpty
          ? const Center(
              child: Text('Aucune carte scannée pour le moment.'),
            )
          : ListView.separated(
              itemCount: _cards.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final card = _cards[index];
                return Dismissible(
                  key: ValueKey(card.id.isNotEmpty ? card.id : card.name),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await _history.delete(card);
                    _refresh();
                  },
                  child: ListTile(
                    leading: card.imageUrl.isNotEmpty
                        ? Image.network(
                            card.imageUrl,
                            width: 44,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image_not_supported),
                          )
                        : const Icon(Icons.catching_pokemon),
                    title: Text(card.name),
                    subtitle: Text(card.setName),
                    trailing: Text(
                      card.formatPrice(card.priceMid),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(card: card),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
