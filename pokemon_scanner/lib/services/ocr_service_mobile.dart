import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_heuristics.dart';

/// OCR mobile basé sur Google ML Kit (local, gratuit, précis).
class MobileOcrService implements OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<OcrResult> extract(XFile image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    final recognizedText = await _recognizer.processImage(inputImage);
    final lines = recognizedText.blocks.expand((b) => b.lines).toList();
    debugPrint('[OCR] ${lines.length} lignes : '
        '${lines.map((l) => l.text).join(" | ")}');

    final boxes = lines
        .map((l) => TextBox(
              text: l.text,
              left: l.boundingBox.left,
              top: l.boundingBox.top,
              right: l.boundingBox.right,
              bottom: l.boundingBox.bottom,
            ))
        .toList();

    final result = extractFromBoxes(boxes);
    debugPrint('[OCR] nom="${result.name}" numéro="${result.number}"');
    return result;
  }

  @override
  void dispose() => _recognizer.close();
}

/// Fabrique l'implémentation mobile (sélectionnée par compilation conditionnelle).
OcrService createOcrService() => MobileOcrService();
