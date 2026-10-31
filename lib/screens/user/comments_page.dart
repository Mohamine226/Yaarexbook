import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/paginated_list.dart';

class CommentsPage extends StatefulWidget {
  final Doc doc;
  const CommentsPage({super.key, required this.doc});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  late final Pager<Comment> _pager = Pager((c) => Api.comments(widget.doc.id, cursor: c));
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _pager.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final c = await Api.addComment(widget.doc.id, text);
      _ctrl.clear();
      _pager.insertFirst(c);
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _sending = false);
  }

  bool _canDelete(Comment c) {
    final me = Session.instance.me;
    return me.isAdmin || c.userId == me.id || widget.doc.auteurId == me.id;
  }

  Future<void> _delete(Comment c) async {
    final ok = await confirm(context, title: 'Supprimer le commentaire ?', message: c.contenu, action: 'Supprimer', danger: true);
    if (!ok) return;
    try {
      await Api.deleteComment(c.id);
      _pager.removeWhere((x) => x.id == c.id);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commentaires')),
      body: Column(
        children: [
          Expanded(
            child: PagedListView<Comment>(
              pager: _pager,
              emptyMessage: 'Aucun commentaire. Lancez la discussion !',
              emptyIcon: Icons.mode_comment_outlined,
              itemBuilder: (context, c) => Card(
                child: ListTile(
                  leading: Avatar(c.auteurNom, radius: 18),
                  title: Row(children: [
                    Expanded(child: Text(c.auteurNom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                    Text(timeAgo(c.createdAt), style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                  ]),
                  subtitle: Text(c.contenu),
                  trailing: _canDelete(c)
                      ? IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _delete(c))
                      : null,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    maxLength: 1000,
                    maxLines: null,
                    decoration: const InputDecoration(hintText: 'Votre commentaire…', counterText: ''),
                  ),
                ),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
