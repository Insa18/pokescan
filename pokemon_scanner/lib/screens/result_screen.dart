import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pokemon_card.dart';
import '../services/history_service.dart';
import '../services/name_translator.dart';
import '../widgets/price_card.dart';

/// Écran affichant le résultat d'un scan : image, nom, set, prix.
class ResultScreen extends StatefulWidget {
  final PokemonCard card;

  const ResultScreen({super.key, required this.card});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final HistoryService _history = HistoryService();
  bool _saved = false;

  Future<void> _save() async {
    try {
      await _history.save(widget.card);
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carte ajoutée à ton Pokédex.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de la sauvegarde.')),
      );
    }
  }

  /// Ouvre la fiche Cardmarket de la carte dans le navigateur.
  Future<void> _openCardmarket() async {
    final uri = Uri.parse(widget.card.cardmarketLink);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Cardmarket.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    // Nom français (ex. « Pyroli ex ») déduit du nom anglais de l'API.
    final frenchName = NameTranslator.instance.toFrench(card.name);

    return Scaffold(
      appBar: AppBar(title: const Text('Résultat')),
      // SafeArea : évite que la barre de navigation système ne recouvre les
      // boutons du bas (« Scanner une autre carte »).
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image de la carte.
              if (card.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    card.imageUrl,
                    height: 320,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 320,
                      child: Center(child: Icon(Icons.broken_image, size: 64)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Nom anglais (tel que l'API) + nom français déduit.
              Text(card.name, style: Theme.of(context).textTheme.headlineSmall),
              if (frenchName != null &&
                  frenchName.toLowerCase() != card.name.toLowerCase()) ...[
                const SizedBox(height: 2),
                Text(
                  '🇫🇷 $frenchName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                card.number.isNotEmpty
                    ? '${card.setName} · n°${card.number}'
                    : card.setName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),

              // Tableau des prix.
              PriceCard(
                low: card.priceLow,
                mid: card.priceMid,
                high: card.priceHigh,
                currency: card.currency,
              ),
              const SizedBox(height: 16),

              // Lien Cardmarket.
              OutlinedButton.icon(
                onPressed: _openCardmarket,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Voir sur Cardmarket'),
              ),
              const SizedBox(height: 24),

              // Bouton sauvegarder.
              FilledButton.icon(
                onPressed: _saved ? null : _save,
                icon: Icon(_saved ? Icons.check : Icons.bookmark_add_outlined),
                label:
                    Text(_saved ? 'Ajoutée au Pokédex' : 'Ajouter au Pokédex'),
              ),
              const SizedBox(height: 12),

              // Bouton scanner une autre carte (retour à l'écran de scan).
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Scanner une autre carte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
