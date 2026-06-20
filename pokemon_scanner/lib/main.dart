import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_home.dart';
import 'constants.dart';
import 'services/name_translator.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On masque la barre de navigation système en bas (on garde la barre
  // d'état en haut). Elle réapparaît par un balayage depuis le bord.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );

  // Initialisation du stockage local (historique + cache hors-ligne).
  await Hive.initFlutter();
  await Hive.openBox(kHistoryBoxName);
  await Hive.openBox(kCardCacheBoxName);

  // Dictionnaire FR→EN pour traduire les noms de cartes avant la recherche.
  await NameTranslator.instance.load();

  // Initialisation spécifique à la plateforme (caméras sur mobile, rien sur web).
  await initPlatform();

  runApp(const PokemonScannerApp());
}

class PokemonScannerApp extends StatelessWidget {
  const PokemonScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: PokeColors.red,
      primary: PokeColors.red,
      onPrimary: Colors.white,
      secondary: PokeColors.yellow,
      onSecondary: PokeColors.ink,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'PokéScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: PokeColors.cream,
        appBarTheme: const AppBarTheme(
          backgroundColor: PokeColors.red,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 3,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: PokeColors.yellow,
          foregroundColor: PokeColors.ink,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: PokeColors.red,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: PokeColors.blue,
            side: const BorderSide(color: PokeColors.blue, width: 1.5),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: PokeColors.yellow.withValues(alpha: 0.6)),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: PokeColors.ink,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: buildHome(),
    );
  }
}
