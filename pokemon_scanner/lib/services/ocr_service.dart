/// Point d'entrée OCR multiplateforme.
///
/// Réexpose l'interface commune ([OcrService], [OcrResult]) et fournit une
/// fabrique [createOcrService] qui choisit, par compilation conditionnelle,
/// l'implémentation ML Kit (mobile) ou Tesseract.js (web).
library;

export 'ocr_heuristics.dart' show OcrService, OcrResult;

import 'ocr_heuristics.dart';
import 'ocr_service_mobile.dart'
    if (dart.library.html) 'ocr_service_web.dart' as impl;

OcrService createOcrService() => impl.createOcrService();
