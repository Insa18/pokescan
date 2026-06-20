import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/pokemon_card.dart';
import '../services/ocr_service.dart';
import '../services/pokemon_api.dart';
import '../widgets/pokeball_icon.dart';
import '../widgets/pokedex_icon.dart';
import 'pokedex_screen.dart';
import 'result_screen.dart';

/// Écran d'accueil de la version web.
///
/// Le scan caméra live + ML Kit n'existe pas en navigateur : on capture une
/// photo (appareil photo via Safari/Chrome) et on l'analyse avec Tesseract.js.
/// La recherche manuelle (nom + numéro) reste le repli fiable.
class WebHomeScreen extends StatefulWidget {
  const WebHomeScreen({super.key});

  @override
  State<WebHomeScreen> createState() => _WebHomeScreenState();
}

class _WebHomeScreenState extends State<WebHomeScreen> {
  final OcrService _ocr = createOcrService();
  final PokemonApiService _api = PokemonApiService();
  final ImagePicker _picker = ImagePicker();

  bool _busy = false;
  String? _status;
  Uint8List? _preview;
  int _searchGen = 0;

  bool _aborted(int gen) => !mounted || gen != _searchGen;

  void _cancel() {
    _searchGen++;
    setState(() {
      _busy = false;
      _status = null;
    });
  }

  /// Capture une photo (ou choix d'image) puis OCR + recherche.
  Future<void> _capture(ImageSource source) async {
    if (_busy) return;
    final XFile? photo =
        await _picker.pickImage(source: source, maxWidth: 1600);
    if (photo == null) return;

    final gen = ++_searchGen;
    final bytes = await photo.readAsBytes();
    if (_aborted(gen)) return;
    setState(() {
      _preview = bytes;
      _busy = true;
      _status = 'Lecture du texte (OCR)…';
    });

    try {
      final result = await _ocr.extract(photo);
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

  Future<void> _lookup(String name,
      {String? number, bool fromManual = false, int? gen}) async {
    final g = gen ?? _searchGen;
    final navigator = Navigator.of(context);
    try {
      final PokemonCard card = await _api.searchByName(name, number: number);
      if (_aborted(g)) return;
      setState(() => _status = null);
      await navigator.push(
        MaterialPageRoute(builder: (_) => ResultScreen(card: card)),
      );
    } on CardNotFoundException {
      if (_aborted(g)) return;
      if (fromManual) {
        _snack('Carte « $name » introuvable. Vérifie l\'orthographe.');
        setState(() => _status = 'Carte « $name » introuvable.');
      } else {
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

  Future<void> _onOcrFailed(String message) async {
    if (!mounted) return;
    setState(() => _status = message);
    await _showManualSearch();
  }

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
            icon: const PokedexIcon(size: 24),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_preview != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_preview!, height: 280,
                        fit: BoxFit.contain),
                  )
                else
                  const PokeballIcon(size: 96),
                const SizedBox(height: 20),
                if (_status != null) ...[
                  Text(_status!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                ],
                if (_busy)
                  FilledButton.icon(
                    onPressed: _cancel,
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700),
                    icon: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                    label: const Text('Annuler'),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: () => _capture(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Prendre une photo'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _capture(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choisir une image'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showManualSearch(),
                    icon: const Icon(Icons.search),
                    label: const Text('Recherche manuelle'),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Astuce : si la lecture automatique échoue, utilise la '
                  'recherche manuelle (nom + numéro) pour le prix exact.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
