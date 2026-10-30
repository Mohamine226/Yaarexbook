import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../app_config.dart';
import '../models/models.dart';
import '../widgets/document_card.dart';
import '../widgets/paginated_list.dart';
import '../widgets/person_tile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _people = false;
  String? _category;
  String _query = '';

  late Pager<Doc> _docs = _newDocs();
  Pager<Person>? _persons;

  Pager<Doc> _newDocs() => Pager((c) => Api.documents(search: _query, categorie: _category, cursor: c));

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _docs.dispose();
    _persons?.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = text.trim();
      if (q == _query) return;
      setState(() {
        _query = q;
        _rebuildPagers();
      });
    });
  }

  void _rebuildPagers() {
    _docs.dispose();
    _docs = _newDocs();
    _persons?.dispose();
    _persons = (_people && _query.length >= 2) ? Pager((c) => Api.searchPeople(_query, cursor: c)) : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _ctrl,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: _people ? 'Nom d\'une personne (2 lettres min.)' : 'Titre, auteur, domaine…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ctrl.clear();
                          _onChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Documents'), icon: Icon(Icons.description_outlined)),
                ButtonSegment(value: true, label: Text('Personnes'), icon: Icon(Icons.people_outline)),
              ],
              selected: {_people},
              onSelectionChanged: (s) => setState(() {
                _people = s.first;
                _rebuildPagers();
              }),
            ),
          ),
          if (!_people)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final c in AppConfig.categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (on) => setState(() {
                          _category = on ? c : null;
                          _rebuildPagers();
                        }),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _people ? _peopleResults() : _docResults()),
        ],
      ),
    );
  }

  Widget _docResults() {
    return PagedListView<Doc>(
      key: ValueKey(_docs),
      pager: _docs,
      emptyMessage: 'Aucun document trouvé.',
      emptyIcon: Icons.search_off,
      itemBuilder: (context, doc) => DocumentCard(
        key: ValueKey(doc.id),
        doc: doc,
        onChanged: (d) => _docs.replaceWhere((x) => x.id == d.id, d),
        onDeleted: () => _docs.removeWhere((x) => x.id == doc.id),
      ),
    );
  }

  Widget _peopleResults() {
    final pager = _persons;
    if (pager == null) {
      return Center(
        child: Text('Saisissez au moins 2 lettres.', style: TextStyle(color: Colors.grey.shade600)),
      );
    }
    return PagedListView<Person>(
      key: ValueKey(pager),
      pager: pager,
      emptyMessage: 'Aucune personne trouvée.',
      emptyIcon: Icons.person_search,
      itemBuilder: (context, p) => PersonTile(key: ValueKey(p.id), person: p),
    );
  }
}
