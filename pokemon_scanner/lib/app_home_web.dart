import 'package:flutter/widgets.dart';

import 'screens/web_home_screen.dart';

/// Pas de détection caméra côté web (la capture se fait via image_picker).
Future<void> initPlatform() async {}

/// Écran d'accueil web : capture photo (iOS Safari) + OCR Tesseract.js.
Widget buildHome() => const WebHomeScreen();
