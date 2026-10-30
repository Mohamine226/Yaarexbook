import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../state/events.dart';
import '../state/local_library.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import '../widgets/cover_image.dart';
import 'document_detail_page.dart';
import 'reader_page.dart';

/// Les documents ajoutés par l'utilisateur, en grille de couvertures.
/// Un appui ouvre le document ; le bouton ⋮ (ou un appui long) ouvre une fiche
/// rapide, d'où l'on peut aller à la page détaillée.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<LocalDoc> _items = [];
  bool _syncing = false;
  bool _loaded = false;
  int? _opening; // id du document en cours d'ouverture

  int get _userId => Session.instance.me.id;

  @override
  void initState() {
    super.initState();
    libraryTick.addListener(_reloadLocal);
    _start();
  }

  @override
  void dispose() {
    libraryTick.removeListener(_reloadLocal);
    super.dispose();
  }

  Future<void> _start() async {
    await _reloadLocal();
    await _sync();
  }

  Future<void> _reloadLocal() async {
    final items = await LocalLibrary.instance.list(_userId);
    if (mounted) {
      setState(() {
        _items = items;
        _loaded = true;
      });
    }
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final items = await LocalLibrary.instance.sync(_userId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _syncing = false);
  }

  /// Ouvre le PDF : copie locale chiffrée si elle existe, sinon téléchargement.
  Future<void> _read(LocalDoc item) async {
    if (_opening != null) return;
    setState(() => _opening = item.doc.id);
    try {
      var bytes = await LocalLibrary.instance.readPdf(_userId, item.doc.id);
      bytes ??= Uint8List.fromList(await Api.downloadPdf(item.doc.id));
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReaderPage(title: item.doc.titre, bytes: bytes!)),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _opening = null);
  }

  Future<void> _openDetail(LocalDoc item) async {
    final result = await Navigator.push<DocumentResult>(
      context,
      MaterialPageRoute(builder: (_) => DocumentDetailPage(doc: item.doc)),
    );
    if (result != null) await _reloadLocal();
    if (mounted) _sync();
  }

  Future<void> _remove(LocalDoc item) async {
    final ok = await confirm(
      context,
      title: 'Retirer de la bibliothèque ?',
      message: item.doc.titre,
      action: 'Retirer',
      danger: true,
    );
    if (!ok) return;
    try {
      await LocalLibrary.instance.remove(_userId, item.doc.id);
      await _reloadLocal();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Fiche rapide (modale) : infos du document et accès à la page détaillée.
  void _showSheet(LocalDoc item) {
    final d = item.doc;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoverImage(url: d.couvertureUrl, localPath: item.coverPath, width: 80, height: 110),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.titre, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(d.auteurNom, style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          [d.categorie, d.langue].where((s) => s.isNotEmpty).join(' · '),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(item.hasPdf ? Icons.download_done : Icons.cloud_outlined, size: 16, color: item.hasPdf ? Colors.green : Colors.grey),
                          const SizedBox(width: 4),
                          Text(item.hasPdf ? 'Disponible hors ligne' : 'En ligne uniquement', style: const TextStyle(fontSize: 12)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              if (d.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(d.description, maxLines: 4, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _read(item);
                },
                icon: const Icon(Icons.menu_book),
                label: const Text('Lire'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openDetail(item);
                },
                icon: const Icon(Icons.info_outline),
                label: const Text('Voir la page détaillée'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _remove(item);
                },
                icon: const Icon(Icons.bookmark_remove_outlined, color: Colors.red),
                label: const Text('Retirer de la bibliothèque', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(LocalDoc item) {
    final d = item.doc;
    final opening = _opening == d.id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _read(item),
      onLongPress: () => _showSheet(item),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(url: d.couvertureUrl, localPath: item.coverPath, width: double.infinity),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              d.titre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, height: 1.2),
                            ),
                          ),
                          if (item.hasPdf) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.download_done, size: 16, color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Material(
                      color: Colors.black38,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _showSheet(item),
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(Icons.more_vert, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  if (opening)
                    Container(
                      color: Colors.black45,
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma bibliothèque'),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(tooltip: 'Synchroniser', icon: const Icon(Icons.sync), onPressed: _sync),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _sync,
        child: _items.isEmpty
            ? ListView(children: const [
          SizedBox(
            height: 420,
            child: EmptyState(
              icon: Icons.bookmarks_outlined,
              message: 'Votre bibliothèque est vide.\nAjoutez des documents depuis leur fiche pour les lire hors ligne.',
            ),
          ),
        ])
            : GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) => _tile(_items[i]),
        ),
      ),
    );
  }
}