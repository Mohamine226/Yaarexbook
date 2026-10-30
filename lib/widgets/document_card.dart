import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../screens/comments_page.dart';
import '../screens/document_detail_page.dart';
import '../screens/user_profile_page.dart';
import '../utils/format.dart';
import 'common.dart';
import 'cover_image.dart';

/// Carte d'un document dans un fil ou une liste : couverture, auteur, like,
/// nombre de commentaires. Un appui ouvre la fiche du document.
class DocumentCard extends StatefulWidget {
  final Doc doc;
  final String? localCover;
  final void Function(Doc updated)? onChanged;
  final VoidCallback? onDeleted;
  final bool showAuthor;

  const DocumentCard({
    super.key,
    required this.doc,
    this.localCover,
    this.onChanged,
    this.onDeleted,
    this.showAuthor = true,
  });

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  late Doc doc = widget.doc;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant DocumentCard old) {
    super.didUpdateWidget(old);
    if (old.doc != widget.doc) doc = widget.doc;
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    _busy = true;
    final before = doc;
    setState(() => doc = doc.copyWith(liked: !doc.liked, nbLikes: doc.nbLikes + (doc.liked ? -1 : 1)));
    try {
      final r = before.liked ? await Api.unlike(doc.id) : await Api.like(doc.id);
      if (mounted) setState(() => doc = doc.copyWith(liked: r.liked, nbLikes: r.nbLikes));
      widget.onChanged?.call(doc);
    } catch (e) {
      if (mounted) {
        setState(() => doc = before);
        showError(context, e);
      }
    }
    _busy = false;
  }

  Future<void> _open() async {
    final result = await Navigator.push<DocumentResult>(
      context,
      MaterialPageRoute(builder: (_) => DocumentDetailPage(doc: doc)),
    );
    if (!mounted || result == null) return;
    if (result.deleted) {
      widget.onDeleted?.call();
    } else if (result.doc != null) {
      setState(() => doc = result.doc!);
      widget.onChanged?.call(doc);
    }
  }

  Future<void> _comments() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsPage(doc: doc)));
    try {
      final fresh = await Api.document(doc.id);
      if (mounted) {
        setState(() => doc = doc.copyWith(nbCommentaires: fresh.nbCommentaires));
        widget.onChanged?.call(doc);
      }
    } catch (_) {}
  }

  void _openAuthor() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => UserProfilePage(userId: doc.auteurId, name: doc.auteurNom)),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Qui a publié
          if (widget.showAuthor)
            InkWell(
              onTap: _openAuthor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(children: [
                  Avatar(doc.auteurNom, radius: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.auteurNom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(
                          [timeAgo(doc.createdAt), doc.categorie].where((s) => s.isNotEmpty).join(' · '),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (doc.isDisabled) const Chip(label: Text('Désactivé'), visualDensity: VisualDensity.compact),
                ]),
              ),
            )
          else
            const SizedBox(height: 8),

          // 2. Titre et description, au-dessus de l'image
          InkWell(
            onTap: _open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (doc.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(doc.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.35)),
                  ],
                ],
              ),
            ),
          ),

          // 3. L'image
          InkWell(
            onTap: _open,
            child: CoverImage(url: doc.couvertureUrl, localPath: widget.localCover, width: double.infinity, height: 320),
          ),

          // 4. Sous l'image : J'aime et Commentaires
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(children: [
              TextButton.icon(
                onPressed: _toggleLike,
                icon: Icon(doc.liked ? Icons.favorite : Icons.favorite_border, color: doc.liked ? Colors.red : Colors.grey.shade700),
                label: Text('${doc.nbLikes}', style: TextStyle(color: Colors.grey.shade800)),
              ),
              TextButton.icon(
                onPressed: _comments,
                icon: Icon(Icons.mode_comment_outlined, color: Colors.grey.shade700),
                label: Text('${doc.nbCommentaires}', style: TextStyle(color: Colors.grey.shade800)),
              ),
              const Spacer(),
              TextButton(
                onPressed: _open,
                child: Text('Voir le document', style: TextStyle(color: scheme.primary)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}