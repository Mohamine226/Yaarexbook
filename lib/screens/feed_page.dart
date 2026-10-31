import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../state/events.dart';
import '../widgets/document_card.dart';
import '../widgets/paginated_list.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  late final Pager<Doc> _recent = Pager((c) => Api.documents(cursor: c));
  late final Pager<Doc> _following = Pager((c) => Api.feed(cursor: c));
  late final Pager<Doc> _popular = Pager((c) => Api.popular(cursor: c));

  @override
  void initState() {
    super.initState();
    publishedTick.addListener(_refreshAll);
  }

  @override
  void dispose() {
    publishedTick.removeListener(_refreshAll);
    _recent.dispose();
    _following.dispose();
    _popular.dispose();
    super.dispose();
  }

  void _refreshAll() {
    _recent.refresh();
    _following.refresh();
    _popular.refresh();
  }

  Widget _list(Pager<Doc> pager, String empty, IconData icon) {
    return PagedListView<Doc>(
      pager: pager,
      emptyMessage: empty,
      emptyIcon: icon,
      itemBuilder: (context, doc) => DocumentCard(
        key: ValueKey(doc.id),
        doc: doc,
        onChanged: (d) => pager.replaceWhere((x) => x.id == d.id, d),
        onDeleted: () => pager.removeWhere((x) => x.id == doc.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Yaarexbook'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Pour vous'),
            Tab(text: 'Abonnements'),
            //Tab(text: 'Populaires'),
          ]),
        ),
        body: TabBarView(
          children: [
            _list(_recent, 'Aucun document publié pour le moment.\nSoyez le premier !', Icons.menu_book_outlined),
            _list(_following, 'Suivez des personnes pour voir leurs publications ici.', Icons.group_outlined),
            //_list(_popular, 'Aucun document aimé pour le moment.', Icons.favorite_border),
          ],
        ),
      ),
    );
  }
}
