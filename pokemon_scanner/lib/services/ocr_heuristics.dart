import 'package:cross_file/cross_file.dart';

/// Résultat d'une analyse OCR : nom de la carte + numéro de collection.
class OcrResult {
  final String? name;
  final String? number;
  const OcrResult({this.name, this.number});
}

/// Boîte de texte générique (indépendante du moteur OCR) : un texte et sa
/// position dans l'image. Permet de partager les heuristiques entre ML Kit
/// (mobile) et Tesseract.js (web).
class TextBox {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const TextBox({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get height => bottom - top;
}

/// Interface d'un service d'OCR : extrait nom + numéro d'une image de carte.
abstract class OcrService {
  Future<OcrResult> extract(XFile image);
  void dispose();
}

/// Heuristiques communes : à partir d'une liste de lignes détectées (avec
/// leur position), déduit le nom (en haut à gauche) et le numéro de
/// collection (« 146/131 », en bas).
OcrResult extractFromBoxes(List<TextBox> boxes) {
  if (boxes.isEmpty) return const OcrResult();
  return OcrResult(name: _extractName(boxes), number: _extractNumber(boxes));
}

/// Nom de carte : ligne la plus grande, en haut à gauche, peu de chiffres.
String? _extractName(List<TextBox> boxes) {
  final maxBottom =
      boxes.map((b) => b.bottom).fold<double>(0, (a, b) => b > a ? b : a);
  final maxRight =
      boxes.map((b) => b.right).fold<double>(0, (a, b) => b > a ? b : a);
  final topZone = maxBottom * 0.45; // 45 % supérieurs

  bool isCandidate(TextBox b) {
    final t = b.text.trim();
    if (t.length < 3) return false;
    final letters = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(t).length;
    final digits = RegExp(r'[0-9]').allMatches(t).length;
    if (letters < 2) return false;
    if (digits >= letters) return false; // rejette les lignes numériques
    return true;
  }

  final candidates = boxes.where(isCandidate).toList();
  if (candidates.isEmpty) return null;

  // Le nom est en haut À GAUCHE (les PV/type sont à droite).
  double score(TextBox b) {
    final inTop = b.top <= topZone ? 1.6 : 1.0;
    final onLeft = (maxRight > 0 && b.left <= maxRight * 0.55) ? 1.4 : 1.0;
    return b.height * inTop * onLeft;
  }

  candidates.sort((a, b) => score(b).compareTo(score(a)));
  final best = _clean(candidates.first.text);
  return best.isEmpty ? null : best;
}

/// Numéro de collection : motif « xxx/yyy » (ou « TG12/TG30 »), de préférence
/// dans le bas de la carte. Retourne « 146/131 » (numérateur + dénominateur).
String? _extractNumber(List<TextBox> boxes) {
  final maxBottom =
      boxes.map((b) => b.bottom).fold<double>(0, (a, b) => b > a ? b : a);
  final bottomZone = maxBottom * 0.6; // privilégie le bas de la carte

  final re = RegExp(
    r'([A-Z]{0,3}[0-9OolI]{1,4})\s*/\s*([A-Z]{0,3}[0-9OolI]{1,4})',
    caseSensitive: false,
  );

  String? best;
  double bestTop = -1;
  for (final b in boxes) {
    final m = re.firstMatch(b.text);
    if (m == null) continue;
    final numerator = _normalizeNumber(m.group(1)!);
    if (numerator.isEmpty) continue;
    final denominator = _normalizeNumber(m.group(2)!);
    final value = denominator.isEmpty ? numerator : '$numerator/$denominator';
    final inBottom = b.top >= bottomZone;
    if (best == null || (inBottom && b.top > bestTop)) {
      best = value;
      bestTop = b.top;
    }
  }
  return best;
}

/// Normalise un numéro OCR : corrige O→0, l/I→1 et garde lettres+chiffres.
String _normalizeNumber(String raw) {
  final fixed =
      raw.replaceAll(RegExp(r'[Oo]'), '0').replaceAll(RegExp(r'[lI]'), '1');
  final m = RegExp(r'^([A-Za-z]{0,3})(\d{1,4})$').firstMatch(fixed);
  if (m == null) return RegExp(r'\d{1,4}').stringMatch(fixed) ?? '';
  return '${m.group(1)!.toUpperCase()}${m.group(2)}';
}

/// Nettoie le texte détecté : garde lettres (accents inclus), chiffres,
/// espaces et tirets ; retire la ponctuation parasite.
String _clean(String raw) {
  return raw
      .replaceAll(RegExp(r"[^A-Za-zÀ-ÿ0-9 '\-]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
