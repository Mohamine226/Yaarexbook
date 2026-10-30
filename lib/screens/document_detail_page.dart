import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../state/events.dart';
import '../state/local_library.dart';
import '../state/session.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/cover_image.dart';
import 'comments_page.dart';
import 'reader_page.dart';
import 'user_profile_page.dart';

/// Résultat renvoyé à l'écran précédent : document mis à jour, ou supprimé.
class DocumentResult {
  final Doc? doc;
  final bool deleted;
  const DocumentResult({this.doc, this.deleted = false});
}

class DocumentDetailPage extends StatefulWidget {
  final Doc doc;
  const DocumentDetailPage({super.key, required this.doc});

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  late Doc _doc = widget.doc;
  bool _deleted = false;
  bool _reading = false;
  bool _busy = false;
  String? _localCover;

  int get _userId => Session.instance.me.id;
  bool get _canDelete => _doc.auteurId == _userId || Session.instance.isAdmin;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final local = await LocalLibrary.instance.find(_userId, _doc.id);
    if (mounted && local != null) setState(() => _localCover = local.coverPath);
    try {
      final fresh = await Api.document(_doc.id);
      if (mounted) setState(() => _doc = fresh);
    } catch (_) {
      // Hors ligne : on garde les infos déjà affichées.
    }
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    _busy = true;
    final before = _doc;
    setState(() => _doc = _doc.copyWith(liked: !_doc.liked, nbLikes: _doc.nbLikes + (_doc.liked ? -1 : 1)));
    try {
      final r = before.liked ? await Api.unlike(_doc.id) : await Api.like(_doc.id);
      if (mounted) setState(() => _doc = _doc.copyWith(liked: r.liked, nbLikes: r.nbLikes));
    } catch (e) {
      if (mounted) {
        setState(() => _doc = before);
        showError(context, e);
      }
    }
    _busy = false;
  }

  Future<void> _toggleLibrary() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_doc.dansBibliotheque) {
        await LocalLibrary.instance.remove(_userId, _doc.id);
        _doc = _doc.copyWith(dansBibliotheque: false);
        _localCover = null;
        if (mounted) showMsg(context, 'Retiré de votre bibliothèque');
      } else {
        await LocalLibrary.instance.add(_userId, _doc);
        _doc = _doc.copyWith(dansBibliotheque: true);
        if (mounted) showMsg(context, 'Ajouté : lisible hors ligne');
      }
      libraryTick.value++;
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _read() async {
    setState(() => _reading = true);
    try {
      var bytes = await LocalLibrary.instance.readPdf(_userId, _doc.id);
      bytes ??= await Api.downloadPdf(_doc.id).then((b) => Uint8List.fromList(b));
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReaderPage(title: _doc.titre, bytes: bytes!)),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _reading = false);
  }

  Future<void> _comments() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsPage(doc: _doc)));
    _refresh();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Supprimer ce document ?',
      message: 'Il disparaîtra pour tout le monde (likes, commentaires et bibliothèques compris).',
      action: 'Supprimer',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.deleteDocument(_doc.id);
      await LocalLibrary.instance.removeLocal(_userId, _doc.id);
      libraryTick.value++;
      _deleted = true;
      if (mounted) Navigator.pop(context, const DocumentResult(deleted: true));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _doc;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, DocumentResult(doc: _doc, deleted: _deleted));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Document'),
          actions: [
            if (_canDelete)
              IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: CoverImage(url: d.couvertureUrl, localPath: _localCover, width: 170, height: 240)),
            const SizedBox(height: 16),
            Text(d.titre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserProfilePage(userId: d.auteurId, name: d.auteurNom)),
              ),
              child: Row(children: [
                Avatar(d.auteurNom, radius: 14),
                const SizedBox(width: 8),
                Text(d.auteurNom, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text(timeAgo(d.createdAt), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 4, children: [
              Chip(label: Text(d.categorie)),
              Chip(label: Text(d.langue)),
              if (d.domaine.isNotEmpty) Chip(label: Text(d.domaine)),
              if (d.isDisabled) const Chip(label: Text('Désactivé par un administrateur')),
            ]),
            if (d.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(d.description, style: const TextStyle(fontSize: 15, height: 1.4)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _reading ? null : _read,
              icon: _reading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.menu_book),
              label: Text(_reading ? 'Ouverture…' : 'Lire'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _busy ? null : _toggleLibrary,
              icon: Icon(d.dansBibliotheque ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
              label: Text(d.dansBibliotheque ? 'Retirer de ma bibliothèque' : 'Ajouter à ma bibliothèque'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _toggleLike,
                  icon: Icon(d.liked ? Icons.favorite : Icons.favorite_border, color: d.liked ? Colors.red : null),
                  label: Text('${d.nbLikes} J\'aime'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: _comments,
                  icon: const Icon(Icons.mode_comment_outlined),
                  label: Text('${d.nbCommentaires} commentaires'),
                ),
              ),
            ]),
            Center(
              child: Text('${d.nbAjouts} bibliothèque(s)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
