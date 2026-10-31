import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../widgets/common.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/paginated_list.dart';
import '../user/document_detail_page.dart';

/// Espace d'administration : statistiques, membres, modération des documents.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const titles = ['Statistiques', 'Membres', 'Documents'];
    return Scaffold(
      appBar: AppBar(title: Text('Admin · ${titles[_tab]}')),
      body: IndexedStack(index: _tab, children: const [_StatsTab(), _UsersTab(), _DocsTab()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Membres'),
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Documents'),
        ],
      ),
    );
  }
}

class _StatsTab extends StatefulWidget {
  const _StatsTab();

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  Stats? _stats;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Api.stats();
      if (mounted) setState(() {
        _stats = s;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    if (s == null) {
      return _error != null ? ErrorState(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator());
    }
    final rows = <(String, String, IconData)>[
      ('Membres', 'total_utilisateurs', Icons.people),
      ('Documents', 'total_documents', Icons.description),
      ('Documents désactivés', 'documents_desactives', Icons.block),
      ('Likes', 'total_likes', Icons.favorite),
      ('Commentaires', 'total_commentaires', Icons.mode_comment),
      ('Abonnements', 'total_abonnements', Icons.person_add),
      ('Ajouts en bibliothèque', 'ajouts_bibliotheque', Icons.bookmarks),
      ('Appareils connectés', 'connexions_actives', Icons.devices),
      ('Nouveaux documents (mois)', 'nouveaux_documents_mois', Icons.calendar_month),
      ('Nouveaux documents (année)', 'nouveaux_documents_annee', Icons.calendar_today),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final r in rows)
            Card(
              child: ListTile(
                leading: Icon(r.$3, color: Theme.of(context).colorScheme.primary),
                title: Text(r.$1),
                trailing: Text('${s[r.$2]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _search = '';
  late Pager<User> _pager = _make();

  Pager<User> _make() => Pager((c) => Api.adminUsers(search: _search, cursor: c));

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _toggleRole(User u) async {
    final newRole = u.isAdmin ? 'membre' : 'admin';
    final ok = await confirm(
      context,
      title: u.isAdmin ? 'Retirer les droits admin ?' : 'Nommer administrateur ?',
      message: u.fullName,
    );
    if (!ok) return;
    try {
      await Api.setRole(u.id, newRole);
      _pager.refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(User u) async {
    final ok = await confirm(
      context,
      title: 'Supprimer ce membre ?',
      message: '${u.fullName} et toutes ses publications seront supprimés définitivement.',
      action: 'Supprimer',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.adminDeleteUser(u.id);
      _pager.removeWhere((x) => x.id == u.id);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Session.instance.me.id;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Nom ou email', prefixIcon: Icon(Icons.search)),
            onSubmitted: (v) => setState(() {
              _search = v.trim();
              _pager.dispose();
              _pager = _make();
            }),
          ),
        ),
        Expanded(
          child: PagedListView<User>(
            key: ValueKey(_pager),
            pager: _pager,
            emptyMessage: 'Aucun membre.',
            emptyIcon: Icons.people_outline,
            itemBuilder: (context, u) => Card(
              child: ListTile(
                leading: Avatar(u.fullName),
                title: Text(u.fullName),
                subtitle: Text('${u.email}${u.isAdmin ? ' · admin' : ''}'),
                trailing: u.id == myId
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (v) => v == 'role' ? _toggleRole(u) : _delete(u),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'role', child: Text(u.isAdmin ? 'Retirer admin' : 'Nommer admin')),
                          const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DocsTab extends StatefulWidget {
  const _DocsTab();

  @override
  State<_DocsTab> createState() => _DocsTabState();
}

class _DocsTabState extends State<_DocsTab> {
  String _etat = 'tous';
  String _search = '';
  late Pager<Doc> _pager = _make();

  Pager<Doc> _make() => Pager((c) => Api.adminDocuments(etat: _etat, search: _search, cursor: c));

  void _reset() => setState(() {
        _pager.dispose();
        _pager = _make();
      });

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _toggle(Doc d) async {
    try {
      if (d.isDisabled) {
        await Api.enableDocument(d.id);
      } else {
        await Api.disableDocument(d.id);
      }
      _pager.refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(Doc d) async {
    final ok = await confirm(context, title: 'Supprimer ce document ?', message: d.titre, action: 'Supprimer', danger: true);
    if (!ok) return;
    try {
      await Api.adminDeleteDocument(d.id);
      _pager.removeWhere((x) => x.id == d.id);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Titre du document', prefixIcon: Icon(Icons.search)),
            onSubmitted: (v) {
              _search = v.trim();
              _reset();
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            for (final e in const [('tous', 'Tous'), ('actifs', 'Actifs'), ('desactives', 'Désactivés')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.$2),
                  selected: _etat == e.$1,
                  onSelected: (_) {
                    _etat = e.$1;
                    _reset();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: PagedListView<Doc>(
            key: ValueKey(_pager),
            pager: _pager,
            emptyMessage: 'Aucun document.',
            emptyIcon: Icons.description_outlined,
            itemBuilder: (context, d) => Card(
              child: ListTile(
                leading: CoverImage(url: d.couvertureUrl, width: 44, height: 60),
                title: Text(d.titre, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${d.auteurNom}${d.isDisabled ? ' · désactivé' : ''}'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentDetailPage(doc: d))),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => v == 'toggle' ? _toggle(d) : _delete(d),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'toggle', child: Text(d.isDisabled ? 'Réactiver' : 'Désactiver')),
                    const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
