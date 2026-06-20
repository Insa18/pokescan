import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'screens/scan_screen.dart';

/// Caméras détectées au démarrage (mobile).
List<CameraDescription> _cameras = [];

/// Initialisation spécifique mobile : détection des caméras.
Future<void> initPlatform() async {
  try {
    _cameras = await availableCameras();
  } catch (_) {
    _cameras = [];
  }
}

/// Écran d'accueil mobile : scan caméra + OCR ML Kit.
Widget buildHome() => ScanScreen(cameras: _cameras);
