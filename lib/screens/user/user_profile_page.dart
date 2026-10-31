import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/models.dart';
import '../../state/events.dart';
import '../../widgets/common.dart';
import '../../widgets/document_card.dart';
import '../../widgets/paginated_list.dart';
import 'people_list_page.dart';
import 'settings_page.dart';

/// Profil d'une personne : infos, abonnés, abonnements et ses documents.
/// Avec [own] = true, c'est l'onglet « Profil » de l'utilisateur connecté.
class UserProfilePage extends StatefulWidget {
  final int userId;
  final String name;
  final bool own;
  const UserProfilePage({super.key, required this.userId, required this.name, this.own = false});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Person? _person;
  String? _error;
  bool _busy = false;
  late final Pager<Doc> _docs = Pager((c) => Api.documents(auteurId: widget.userId, cursor: c));

  @override
  void initState() {
    super.initState();
    _loadProfile();
    if (widget.own) publishedTick.addListener(_onPublished);
  }

  @override
  void dispose() {
    publishedTick.removeListener(_onPublished);
    _docs.dispose();
    super.dispose();
  }

  void _onPublished() {
    _docs.refresh();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await Api.profile(widget.userId);
      if (mounted) setState(() {
        _person = p;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _toggleFollow() async {
    final p = _person;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (p.isFollowing) {
        await Api.unfollow(p.id);
      } else {
        await Api.follow(p.id);
      }
      await _loadProfile();
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _header(Person p) {
    final subtitle = [p.profession, p.pays].where((s) => s != null && s.isNotEmpty).join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Avatar(p.fullName, radius: 36),
            const SizedBox(height: 10),
            Text(p.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatTile('Documents', p.nbDocuments),
                StatTile(
                  'Abonnés',
                  p.nbAbonnes,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PeopleListPage(userId: p.id, followers: true))),
                ),
                StatTile(
                  'Abonnements',
                  p.nbAbonnements,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PeopleListPage(userId: p.id, followers: false))),
                ),
              ],
            ),
            if (!widget.own && !p.isMe) ...[
              const SizedBox(height: 12),
              p.isFollowing
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      onPressed: _busy ? null : _toggleFollow,
                      child: const Text('Suivi'),
                    )
                  : FilledButton(onPressed: _busy ? null : _toggleFollow, child: const Text('Suivre')),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _person;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.own,
        title: Text(widget.own ? 'Mon profil' : widget.name),
        actions: [
          if (widget.own)
            IconButton(
              tooltip: 'Paramètres',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
            ),
        ],
      ),
      body: p == null
          ? (_error != null
              ? ErrorState(message: _error!, onRetry: _loadProfile)
              : const Center(child: CircularProgressIndicator()))
          : PagedListView<Doc>(
              pager: _docs,
              header: _header(p),
              emptyMessage: widget.own ? 'Vous n\'avez encore rien publié.' : 'Aucune publication.',
              emptyIcon: Icons.description_outlined,
              itemBuilder: (context, doc) => DocumentCard(
                key: ValueKey(doc.id),
                doc: doc,
                showAuthor: false,
                onChanged: (d) => _docs.replaceWhere((x) => x.id == d.id, d),
                onDeleted: () {
                  _docs.removeWhere((x) => x.id == doc.id);
                  _loadProfile();
                },
              ),
            ),
    );
  }
}
