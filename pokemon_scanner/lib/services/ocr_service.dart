import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Résultat d'une analyse OCR : nom de la carte + numéro de collection.
class OcrResult {
  final String? name;
  final String? number;
  const OcrResult({this.name, this.number});
}

/// Service d'OCR basé sur Google ML Kit.
///
/// Prend une image de carte Pokémon et en extrait le nom (en haut à gauche)
/// et le numéro de collection (« 146/131 », en bas de la carte).
class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Analyse une image : retourne le nom détecté et le numéro de collection.
  Future<OcrResult> extractCard(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);
    final lines = recognizedText.blocks.expand((b) => b.lines).toList();
    debugPrint('[OCR] ${lines.length} lignes : '
        '${lines.map((l) => l.text).join(" | ")}');
    if (lines.isEmpty) return const OcrResult();

    final name = _extractName(lines);
    final number = _extractNumber(lines);
    debugPrint('[OCR] nom="$name" numéro="$number"');
    return OcrResult(name: name, number: number);
  }

  /// Nom de carte : ligne la plus grande, en haut à gauche, peu de chiffres.
  String? _extractName(List<TextLine> lines) {
    final maxBottom = lines
        .map((l) => l.boundingBox.bottom)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final maxRight = lines
        .map((l) => l.boundingBox.right)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final topZone = maxBottom * 0.45; // 45 % supérieurs

    bool isCandidate(TextLine l) {
      final t = l.text.trim();
      if (t.length < 3) return false;
      final letters = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(t).length;
      final digits = RegExp(r'[0-9]').allMatches(t).length;
      if (letters < 2) return false;
      if (digits >= letters) return false; // rejette les lignes numériques
      return true;
    }

    final candidates = lines.where(isCandidate).toList();
    if (candidates.isEmpty) return null;

    // Le nom est en haut À GAUCHE (les PV/type sont à droite).
    double score(TextLine l) {
      final box = l.boundingBox;
      final inTop = box.top <= topZone ? 1.6 : 1.0;
      final onLeft = (maxRight > 0 && box.left <= maxRight * 0.55) ? 1.4 : 1.0;
      return box.height * inTop * onLeft;
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    final best = _clean(candidates.first.text);
    return best.isEmpty ? null : best;
  }

  /// Numéro de collection : motif « xxx/yyy » (ou « TG12/TG30 »), de
  /// préférence dans le bas de la carte. Retourne « 146/131 » (numérateur +
  /// dénominateur) pour permettre de cibler le bon set.
  String? _extractNumber(List<TextLine> lines) {
    final maxBottom = lines
        .map((l) => l.boundingBox.bottom)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final bottomZone = maxBottom * 0.6; // privilégie le bas de la carte

    // Autorise les confusions OCR usuelles (O→0, l/I→1) dans les chiffres.
    final re = RegExp(
      r'([A-Z]{0,3}[0-9OolI]{1,4})\s*/\s*([A-Z]{0,3}[0-9OolI]{1,4})',
      caseSensitive: false,
    );

    String? best;
    double bestTop = -1;
    for (final l in lines) {
      final m = re.firstMatch(l.text);
      if (m == null) continue;
      final numerator = _normalizeNumber(m.group(1)!);
      if (numerator.isEmpty) continue;
      // Le dénominateur (taille du set) aide à départager les rééditions.
      final denominator = _normalizeNumber(m.group(2)!);
      final value = denominator.isEmpty ? numerator : '$numerator/$denominator';
      // On garde le match le plus bas (le numéro est en bas de carte).
      final top = l.boundingBox.top;
      final inBottom = top >= bottomZone;
      if (best == null || (inBottom && top > bestTop)) {
        best = value;
        bestTop = top;
      }
    }
    return best;
  }

  /// Normalise un numéro OCR : corrige O→0, l/I→1 et garde lettres+chiffres.
  String _normalizeNumber(String raw) {
    final fixed =
        raw.replaceAll(RegExp(r'[Oo]'), '0').replaceAll(RegExp(r'[lI]'), '1');
    // Garde le préfixe alphabétique éventuel (TG, SV…) + les chiffres.
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

  /// Libère les ressources natives du recognizer.
  void dispose() {
    _recognizer.close();
  }
}
