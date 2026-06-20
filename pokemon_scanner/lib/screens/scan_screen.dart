import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/pokemon_card.dart';
import '../services/ocr_service.dart';
import '../services/pokemon_api.dart';
import '../theme.dart';
import '../widgets/pokeball_icon.dart';
import 'pokedex_screen.dart';
import 'result_screen.dart';

/// Écran principal : aperçu caméra, capture, OCR puis recherche API.
class ScanScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ScanScreen({super.key, required this.cameras});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;

  final OcrService _ocr = OcrService();
  final PokemonApiService _api = PokemonApiService();

  bool _busy = false;
  String? _status;

  /// Chemin de la photo capturée et « figée » à l'écran (null = aperçu live).
  String? _capturedPath;

  /// Jeton de génération : chaque scan/recherche l'incrémente. Un résultat
  /// dont le jeton ne correspond plus a été annulé → on l'ignore.
  int _searchGen = 0;

  /// Vrai si la recherche [gen] a été annulée ou si l'écran est démonté.
  bool _aborted(int gen) => !mounted || gen != _searchGen;

  /// Annule la recherche en cours.
  void _cancel() {
    _searchGen++;
    setState(() {
      _busy = false;
      _status = null;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  void _initCamera() {
    if (widget.cameras.isEmpty) {
      setState(() => _status = 'Aucune caméra disponible sur cet appareil.');
      return;
    }
    // Évite de recréer un contrôleur si un autre est déjà actif.
    if (_controller != null) return;

    final controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;
    _initFuture = controller.initialize().then((_) {
      if (mounted) setState(() => _status = null);
    }).catchError((_) {
      if (mounted) {
        setState(() => _status = 'Impossible d\'initialiser la caméra.');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // En arrière-plan : on libère la caméra (et on remet _controller à null,
    // sinon le retour au premier plan ne la ré-initialise pas → écran noir).
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null) {
        setState(() => _status = null);
        _initCamera();
      }
    }
  }

  /// Libère la caméra de façon sûre. `dispose()` peut lever une exception si
  /// la surface de prévisualisation n'est pas encore initialisée (transition
  /// d'état rapide) — on l'ignore pour ne pas faire planter l'app.
  void _disposeCamera() {
    final cam = _controller;
    _controller = null;
    _initFuture = null;
    cam?.dispose().catchError((_) {});
  }

  /// Capture une photo, lance l'OCR puis la recherche API.
  Future<void> _scan() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;

    final gen = ++_searchGen;
    setState(() {
      _busy = true;
      _status = 'Mise au point…';
    });

    try {
      // Autofocus avant la capture pour une photo nette.
      try {
        await controller.setFocusMode(FocusMode.auto);
        await Future.delayed(const Duration(milliseconds: 600));
      } catch (_) {}
      if (_aborted(gen)) return;

      setState(() => _status = 'Capture…');
      final XFile photo = await controller.takePicture();
      if (_aborted(gen)) return;

      // Fige la photo à l'écran : plus besoin de garder le tel immobile.
      setState(() {
        _capturedPath = photo.path;
        _status = 'Lecture du texte (OCR)…';
      });

      final result = await _ocr.extractCard(photo.path);
      if (_aborted(gen)) return;
      final name = result.name;
      if (name == null || name.isEmpty) {
        await _onOcrFailed('Aucun texte lisible détecté sur la photo.');
        return;
      }

      final numTxt = result.number != null ? ' n°${result.number}' : '';
      setState(() => _status = 'Recherche de « $name »$numTxt…');
      await _lookup(name, number: result.number, gen: gen);
    } catch (e) {
      if (!_aborted(gen)) await _onOcrFailed('Erreur pendant le scan : $e');
    } finally {
      if (mounted && gen == _searchGen) setState(() => _busy = false);
    }
  }

  /// Efface la photo figée et revient à l'aperçu caméra en direct.
  void _retake() {
    setState(() {
      _capturedPath = null;
      _status = null;
    });
  }

  /// Interroge l'API et navigue vers l'écran de résultat.
  ///
  /// [fromManual] : si vrai, un échec « introuvable » affiche juste un message
  /// (on évite de rouvrir en boucle la fenêtre de saisie manuelle).
  Future<void> _lookup(String name,
      {String? number, bool fromManual = false, int? gen}) async {
    final g = gen ?? _searchGen;
    final navigator = Navigator.of(context); // capturé avant tout await
    try {
      final PokemonCard card = await _api.searchByName(name, number: number);
      if (_aborted(g)) return; // recherche annulée entre-temps
      setState(() => _status = null);
      await navigator.push(
        MaterialPageRoute(builder: (_) => ResultScreen(card: card)),
      );
      // De retour du résultat : on repart sur l'aperçu live.
      if (mounted) _retake();
    } on CardNotFoundException {
      if (_aborted(g)) return;
      if (fromManual) {
        _snack('Carte « $name » introuvable. Vérifie l\'orthographe.');
        setState(() => _status = 'Carte « $name » introuvable.');
      } else {
        // Échec de l'OCR : on propose la saisie manuelle (une seule fois).
        await _onOcrFailed('Carte « $name » introuvable.');
      }
    } on ApiNetworkException catch (e) {
      if (_aborted(g)) return;
      _snack(e.message);
      setState(() => _status = 'Échec réseau — réessaie.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// En cas d'échec OCR : propose la saisie manuelle.
  Future<void> _onOcrFailed(String message) async {
    if (!mounted) return;
    setState(() => _status = message);
    await _showManualSearch();
  }

  /// Boîte de dialogue de recherche manuelle : nom en français + numéro de
  /// collection optionnel (pour cibler la carte exacte). Repli si l'OCR échoue.
  Future<void> _showManualSearch({String? prefillName}) async {
    final nameCtrl = TextEditingController(text: prefillName ?? '');
    final numberCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recherche manuelle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nom en français',
                hintText: 'ex. Pyroli ex, Dracaufeu…',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numberCtrl,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Numéro (optionnel)',
                hintText: 'ex. 014/142 — pour le prix exact',
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechercher'),
          ),
        ],
      ),
    );

    final name = nameCtrl.text.trim();
    final number = numberCtrl.text.trim();
    if (confirmed == true && name.isNotEmpty) {
      final gen = ++_searchGen;
      setState(() {
        _busy = true;
        _status = 'Recherche de « $name »'
            '${number.isNotEmpty ? ' n°$number' : ''}…';
      });
      await _lookup(name,
          number: number.isEmpty ? null : number, fromManual: true, gen: gen);
      if (mounted && gen == _searchGen) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _ocr.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PokeballIcon(size: 26),
            SizedBox(width: 8),
            Text('PokéScan'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.catching_pokemon),
            tooltip: 'Pokédex',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PokedexScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Recherche manuelle',
            onPressed: _busy ? null : () => _showManualSearch(),
          ),
        ],
      ),
      body: _buildPreview(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildFab() {
    // Pendant un traitement : bouton Annuler.
    if (_busy) {
      return FloatingActionButton.extended(
        onPressed: _cancel,
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        label: const Text('Annuler'),
      );
    }
    // Photo figée (après un échec) : proposer de reprendre une photo.
    if (_capturedPath != null) {
      return FloatingActionButton.extended(
        onPressed: _retake,
        icon: const Icon(Icons.refresh),
        label: const Text('Reprendre une photo'),
      );
    }
    // Aperçu live : prendre une photo.
    return FloatingActionButton.extended(
      onPressed: _scan,
      icon: const Icon(Icons.camera_alt),
      label: const Text('Prendre la photo'),
    );
  }

  Widget _buildPreview() {
    // Photo figée : on l'affiche au lieu de l'aperçu live.
    if (_capturedPath != null) {
      return _withOverlay(
        Container(
          color: Colors.black,
          child: Center(
            child: Image.file(File(_capturedPath!), fit: BoxFit.contain),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return Center(child: Text(_status ?? 'Initialisation…'));
    }

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        return _withOverlay(CameraPreview(controller));
      },
    );
  }

  /// Superpose le cadre de visée et le bandeau de statut à [child]
  /// (aperçu live ou photo figée).
  Widget _withOverlay(Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        // Cadre de visée pour aider à cadrer la carte.
        Center(
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.6,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: PokeColors.yellow, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        // Bandeau de statut, placé EN HAUT pour ne pas chevaucher le bouton.
        if (_status != null)
          Positioned(
            left: 0,
            right: 0,
            top: 16,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _status!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
