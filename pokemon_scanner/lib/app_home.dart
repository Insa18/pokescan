/// Sélection de l'écran d'accueil et de l'initialisation selon la plateforme :
/// mobile (caméra + ML Kit) ou web (image_picker + Tesseract.js).
library;

export 'app_home_io.dart' if (dart.library.html) 'app_home_web.dart';
