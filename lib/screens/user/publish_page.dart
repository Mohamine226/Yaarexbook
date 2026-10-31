import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../app_config.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Publication d'un document : tout membre connecté peut publier.
class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final _form = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _description = TextEditingController();
  final _domaine = TextEditingController();
  String _categorie = AppConfig.categories.first;
  String _langue = AppConfig.languages.first;
  PlatformFile? _pdf;
  PlatformFile? _cover;
  bool _busy = false;

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    _domaine.dispose();
    super.dispose();
  }

  String? _problem; // message affiché dans la page

  /// Choisit un fichier et renvoie son contenu (fonctionne sur mobile et sur le web).
  Future<PlatformFile?> _pick(FileType type, {List<String>? extensions, required int maxBytes, required String label}) async {
    final r = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: extensions,
      withData: true,
    );
    if (r == null || r.files.isEmpty) return null;
    final f = r.files.single;
    if (f.bytes == null) {
      _fail('Impossible de lire ce fichier. Essayez de le copier dans « Téléchargements » puis de le choisir à nouveau.');
      return null;
    }
    if (f.size > maxBytes) {
      _fail('$label trop volumineux (${(maxBytes / (1024 * 1024)).round()} Mo maximum).');
      return null;
    }
    return f;
  }

  Future<void> _pickPdf() async {
    try {
      final f = await _pick(FileType.custom, extensions: ['pdf'], maxBytes: 50 * 1024 * 1024, label: 'Le PDF');
      if (f != null) {
        setState(() {
          _pdf = f;
          _problem = null;
        });
      }
    } catch (e) {
      _fail('Impossible de lire ce fichier : $e');
    }
  }

  Future<void> _pickCover() async {
    try {
      final f = await _pick(FileType.image, maxBytes: 5 * 1024 * 1024, label: "L'image");
      if (f != null) {
        setState(() {
          _cover = f;
          _problem = null;
        });
      }
    } catch (e) {
      _fail('Impossible de lire cette image : $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _problem = message;
      _busy = false;
    });
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publication impossible'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _submit() async {
    debugPrint('PUBLISH: clic. pdf=${_pdf?.name} cover=${_cover?.name}');
    if (!_form.currentState!.validate()) {
      _fail('Le titre est obligatoire.');
      return;
    }
    if (_pdf == null) {
      _fail('Choisissez le fichier PDF (bouton « Choisir le PDF »).');
      return;
    }
    if (_cover == null) {
      _fail('Choisissez une image de couverture (bouton « Choisir la couverture »).');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      debugPrint('PUBLISH: envoi vers ${AppConfig.baseUrl}/documents');
      final doc = await Api.publish(
        titre: _titre.text.trim(),
        description: _description.text.trim(),
        categorie: _categorie,
        langue: _langue,
        domaine: _domaine.text.trim(),
        pdfBytes: _pdf!.bytes!,
        pdfName: _pdf!.name,
        coverBytes: _cover!.bytes!,
        coverName: _cover!.name,
      );
      if (mounted) {
        showMsg(context, 'Document publié !');
        Navigator.pop(context, doc);
      }
    } catch (e) {
      debugPrint('PUBLISH: erreur $e');
      _fail(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publier un document')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titre,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: (v) => requiredField(v, 'Le titre'),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _description,
                maxLines: 4,
                maxLength: 5000,
                decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _categorie,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [for (final c in AppConfig.categories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _categorie = v ?? _categorie),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _langue,
                decoration: const InputDecoration(labelText: 'Langue'),
                items: [for (final l in AppConfig.languages) DropdownMenuItem(value: l, child: Text(l))],
                onChanged: (v) => setState(() => _langue = v ?? _langue),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _domaine,
                decoration: const InputDecoration(labelText: 'Domaine (facultatif)', hintText: 'Ex. Mathématiques'),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _busy ? null : _pickPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(_pdf == null ? 'Choisir le PDF (50 Mo max)' : '✓ ${_pdf!.name}', overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _busy ? null : _pickCover,
                icon: const Icon(Icons.image_outlined),
                label: Text(_cover == null ? 'Choisir la couverture (5 Mo max)' : '✓ Couverture choisie'),
              ),
              if (_cover != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_cover!.bytes!, height: 160),
                  ),
                ),
              ],
              if (_problem != null) ...[
                const SizedBox(height: 12),
                Text(_problem!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Publier'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}