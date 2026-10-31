import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../models/models.dart';
import '../../widgets/paginated_list.dart';
import '../../widgets/person_tile.dart';

/// Abonnés ou abonnements d'une personne.
class PeopleListPage extends StatelessWidget {
  final int userId;
  final bool followers;
  const PeopleListPage({super.key, required this.userId, required this.followers});

  @override
  Widget build(BuildContext context) {
    final pager = Pager<Person>(
      (c) => followers ? Api.followers(userId, cursor: c) : Api.following(userId, cursor: c),
    );
    return Scaffold(
      appBar: AppBar(title: Text(followers ? 'Abonnés' : 'Abonnements')),
      body: PagedListView<Person>(
        pager: pager,
        emptyMessage: followers ? 'Aucun abonné pour le moment.' : 'Aucun abonnement pour le moment.',
        emptyIcon: Icons.people_outline,
        itemBuilder: (context, p) => PersonTile(key: ValueKey(p.id), person: p),
      ),
    );
  }
}
