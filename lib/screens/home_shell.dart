import 'package:flutter/material.dart';

import '../state/events.dart';
import '../state/session.dart';
import 'feed_page.dart';
import 'library_page.dart';
import 'publish_page.dart';
import 'search_page.dart';
import 'user_profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<void> _publish() async {
    final doc = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => const PublishPage()),
    );
    if (doc != null) publishedTick.value++;
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.me;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const FeedPage(),
          const SearchPage(),
          const LibraryPage(),
          UserProfilePage(userId: me.id, name: me.fullName, own: true),
        ],
      ),
      floatingActionButton: _index == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: _publish,
              icon: const Icon(Icons.upload_file),
              label: const Text('Publier'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Rechercher'),
          NavigationDestination(icon: Icon(Icons.bookmarks_outlined), selectedIcon: Icon(Icons.bookmarks), label: 'Bibliothèque'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
