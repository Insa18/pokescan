import 'package:flutter/material.dart';

import '../constants.dart';

/// Widget affichant un tableau des prix Bas / Moyen / Haut.
///
/// Devise EUR (TCGdex/Cardmarket) : prix en euros directs.
/// Devise USD (pokemontcg.io) : prix en dollars + estimation en euros.
class PriceCard extends StatelessWidget {
  final double? low;
  final double? mid;
  final double? high;
  final String currency;

  const PriceCard({
    super.key,
    required this.low,
    required this.mid,
    required this.high,
    this.currency = 'USD',
  });

  @override
  Widget build(BuildContext context) {
    final hasAnyPrice = low != null || mid != null || high != null;
    final isEur = currency == 'EUR';
    final source = isEur ? 'Cardmarket (€)' : 'TCGplayer (\$)';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prix du marché',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  source,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasAnyPrice)
              const Text('Aucun prix disponible pour cette carte.')
            else ...[
              _PriceRow(
                  label: isEur ? 'Bas' : 'Bas (Low)',
                  value: low,
                  currency: currency),
              const Divider(height: 16),
              _PriceRow(
                  label: isEur ? 'Moyen' : 'Moyen (Mid)',
                  value: mid,
                  currency: currency,
                  highlight: true),
              const Divider(height: 16),
              _PriceRow(
                  label: isEur ? 'Tendance' : 'Haut (High)',
                  value: high,
                  currency: currency),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double? value;
  final String currency;
  final bool highlight;

  const _PriceRow({
    required this.label,
    required this.value,
    required this.currency,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = highlight
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : const TextStyle(fontSize: 15);

    final String text;
    if (value == null) {
      text = '—';
    } else if (currency == 'EUR') {
      text = '${value!.toStringAsFixed(2)} €';
    } else {
      final eur = value! * kUsdToEurRate;
      text = '\$${value!.toStringAsFixed(2)}  •  ${eur.toStringAsFixed(2)} €';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(text, style: style),
      ],
    );
  }
}
