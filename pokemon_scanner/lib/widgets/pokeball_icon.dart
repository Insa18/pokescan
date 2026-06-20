import 'package:flutter/material.dart';

import '../theme.dart';

/// Petite Pokéball dessinée : moitié haute rouge, moitié basse blanche,
/// bande noire et bouton central. Un liseré blanc la détache du fond rouge.
class PokeballIcon extends StatelessWidget {
  final double size;
  const PokeballIcon({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _PokeballPainter());
  }
}

class _PokeballPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final r = s / 2 - s * 0.05;
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r));

    // Moitiés : haut rouge, bas blanc.
    canvas.save();
    canvas.clipPath(circle);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, s, s), Paint()..color = Colors.white);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, s, s / 2), Paint()..color = PokeColors.red);
    // Bande centrale noire.
    final bandH = s * 0.16;
    canvas.drawRect(Rect.fromLTWH(0, s / 2 - bandH / 2, s, bandH),
        Paint()..color = Colors.black);
    canvas.restore();

    // Liseré blanc extérieur (détache la balle du fond rouge).
    canvas.drawCircle(
        c,
        r + s * 0.025,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.06
          ..color = Colors.white);
    // Contour noir.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..color = Colors.black);

    // Bouton central.
    canvas.drawCircle(c, s * 0.17, Paint()..color = Colors.black);
    canvas.drawCircle(c, s * 0.11, Paint()..color = Colors.white);
    canvas.drawCircle(
        c,
        s * 0.11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.035
          ..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
