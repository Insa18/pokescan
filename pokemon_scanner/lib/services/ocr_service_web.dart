import 'dart:convert';
import 'dart:js_interop';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

import 'ocr_heuristics.dart';

/// Fonction JS définie dans web/index.html : lance Tesseract.js sur une image
/// (data-URL) et renvoie un JSON `[{text,x0,y0,x1,y1}, ...]` (lignes détectées).
@JS('pokescanOcr')
external JSPromise<JSString> _pokescanOcr(JSString dataUrl);

/// OCR web basé sur Tesseract.js (WASM, gratuit, sans clé, compatible iOS).
class WebOcrService implements OcrService {
  @override
  Future<OcrResult> extract(XFile image) async {
    final bytes = await image.readAsBytes();
    final mime = image.mimeType ?? 'image/jpeg';
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

    final jsonStr = (await _pokescanOcr(dataUrl.toJS).toDart).toDart;
    final lines = (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>();
    debugPrint('[OCR web] ${lines.length} lignes');

    final boxes = lines
        .map((l) => TextBox(
              text: (l['text'] as String? ?? '').trim(),
              left: (l['x0'] as num).toDouble(),
              top: (l['y0'] as num).toDouble(),
              right: (l['x1'] as num).toDouble(),
              bottom: (l['y1'] as num).toDouble(),
            ))
        .toList();

    final result = extractFromBoxes(boxes);
    debugPrint('[OCR web] nom="${result.name}" numéro="${result.number}"');
    return result;
  }

  @override
  void dispose() {}
}

/// Fabrique l'implémentation web (sélectionnée par compilation conditionnelle).
OcrService createOcrService() => WebOcrService();
