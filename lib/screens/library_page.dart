import 'package:flutter/material.dart';

import '../state/events.dart';
import '../state/local_library.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import '../widgets/document_card.dart';

/// Les documents ajoutés par l'utilisateur : liste synchronisée avec le serveur,
/// PDF conservés (chiffrés) sur l'appareil pour une lecture hors ligne.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<LocalDoc> _items = [];
  bool _syncing = false;
  bool _loaded = false;

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
    if (mounted) setState(() {
      _items = items;
      _loaded = true;
    });
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
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return DocumentCard(
                          key: ValueKey(item.doc.id),
                          doc: item.doc,
                          localCover: item.coverPath,
                          onChanged: (_) => _reloadLocal(),
                          onDeleted: _reloadLocal,
                        );
                      },
                    ),
            ),
    );
  }
}
