import 'package:flutter/material.dart';

import '../constants.dart';

/// Widget affichant un tableau des prix Low / Mid / High,
/// en dollars (source API) et en euros (conversion approximative).
class PriceCard extends StatelessWidget {
  final double? low;
  final double? mid;
  final double? high;

  const PriceCard({
    super.key,
    required this.low,
    required this.mid,
    required this.high,
  });

  @override
  Widget build(BuildContext context) {
    final hasAnyPrice = low != null || mid != null || high != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prix du marché',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!hasAnyPrice)
              const Text('Aucun prix disponible pour cette carte.')
            else ...[
              _PriceRow(label: 'Bas (Low)', value: low),
              const Divider(height: 16),
              _PriceRow(label: 'Moyen (Mid)', value: mid, highlight: true),
              const Divider(height: 16),
              _PriceRow(label: 'Haut (High)', value: high),
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
  final bool highlight;

  const _PriceRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final usd = value;
    final eur = usd != null ? usd * kUsdToEurRate : null;
    final style = highlight
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : const TextStyle(fontSize: 15);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          usd == null
              ? '—'
              : '\$${usd.toStringAsFixed(2)}  •  ${eur!.toStringAsFixed(2)} €',
          style: style,
        ),
      ],
    );
  }
}
