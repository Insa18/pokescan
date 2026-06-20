import 'package:flutter/material.dart';

/// Petit boîtier de Pokédex dessiné (contour blanc + objectif bleu), pensé
/// pour rester lisible sur la barre d'application rouge.
class PokedexIcon extends StatelessWidget {
  final double size;
  final Color color;
  const PokedexIcon({super.key, this.size = 24, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PokedexPainter(color),
    );
  }
}

class _PokedexPainter extends CustomPainter {
  final Color color;
  _PokedexPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()..color = color;

    // Corps du Pokédex (boîtier arrondi).
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.16, s * 0.10, s * 0.68, s * 0.80),
      Radius.circular(s * 0.14),
    );
    canvas.drawRRect(body, stroke);

    // Gros objectif en haut à gauche (lentille bleue cerclée de blanc).
    final lensCenter = Offset(s * 0.37, s * 0.33);
    canvas.drawCircle(lensCenter, s * 0.115, Paint()..color = const Color(0xFF34C6F4));
    canvas.drawCircle(
        lensCenter,
        s * 0.115,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..color = color);

    // Deux petites diodes à droite de l'objectif.
    canvas.drawCircle(Offset(s * 0.58, s * 0.27), s * 0.035, fill);
    canvas.drawCircle(Offset(s * 0.69, s * 0.27), s * 0.035, fill);

    // Écran en bas.
    final screen = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.28, s * 0.52, s * 0.44, s * 0.26),
      Radius.circular(s * 0.05),
    );
    canvas.drawRRect(screen, stroke);
  }

  @override
  bool shouldRepaint(covariant _PokedexPainter oldDelegate) =>
      oldDelegate.color != color;
}
