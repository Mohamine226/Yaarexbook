import 'package:daaga/admin/PageLivresVendeur.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PageVendeur extends StatefulWidget {
  const PageVendeur({super.key});

  @override
  State<PageVendeur> createState() => _PageVendeurState();
}

class _PageVendeurState extends State<PageVendeur> {
  List<Map<String, dynamic>> vendeurs = [];
  final ScrollController _scrollController = ScrollController();

  bool isLoading = false;
  bool hasMore = true;
  int skip = 0;
  final int limit = 20;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _chargerVendeurs();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!isLoading && hasMore) {
          _chargerVendeurs();
        }
      }
    });
  }

  Future<void> _chargerVendeurs() async {
    setState(() => isLoading = true);

    final uri = Uri.parse("https://daaga-production.up.railway.app/users/").replace(
      queryParameters: {
        'skip': '$skip',
        'limit': '$limit',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      final newVendeurs = data
          .cast<Map<String, dynamic>>()
          .where((user) => user["role"] == "vendeur")
          .toList();

      newVendeurs.sort((a, b) => b["id"].compareTo(a["id"]));

      setState(() {
        vendeurs.addAll(newVendeurs);
        skip += limit;
        isLoading = false;
        if (newVendeurs.length < limit) {
          hasMore = false;
        }
      });
    } else {
      setState(() => isLoading = false);
      throw Exception("Erreur lors du chargement des vendeurs");
    }
  }

  Future<void> supprimerVendeur(int id) async {
    final response = await http.delete(Uri.parse("http://daaga-production.up.railway.app/users/$id"));

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Vendeur supprimé")),
      );
      setState(() {
        vendeurs.removeWhere((v) => v["id"] == id);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Erreur lors de la suppression")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var users = vendeurs;
    if (searchQuery.isNotEmpty) {
      users = users
          .where((user) =>
      user["prenom"].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          user["nom"].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          user["email"].toString().toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Liste des Vendeurs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final result = await showSearch(
                context: context,
                delegate: VendeurSearchDelegate(vendeurs),
              );
              if (result != null) {
                setState(() {
                  searchQuery = result;
                });
              }
            },
          ),
        ],
      ),
      body: users.isEmpty && !isLoading
          ? const Center(child: Text("Aucun vendeur trouvé"))
          : ListView.builder(
        controller: _scrollController,
        itemCount: users.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == users.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = users[index];
          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              leading: const Icon(Icons.store, color: Colors.orange),
              title: Text("${user['prenom']} ${user['nom']}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ID : ${user['id']}"),
                  Text("Email : ${user['email']}"),
                  Text("Téléphone : ${user['telephone']}"),
                  Text("Pays : ${user['pays']}"),
                  Text("Travail : ${user['profession'] ?? user['travail']}"),
                  Text("Date de creation : ${user['date_publication']}"),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  supprimerVendeur(user["id"]);
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PageLivresVendeur(vendeurId: user["id"]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// 🔹 Delegate pour la recherche
class VendeurSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> vendeurs;

  VendeurSearchDelegate(this.vendeurs);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = "";
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, "");
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    close(context, query);
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final users = vendeurs.where((user) =>
    user["prenom"].toString().toLowerCase().contains(query.toLowerCase()) ||
        user["nom"].toString().toLowerCase().contains(query.toLowerCase()) ||
        user["email"].toString().toLowerCase().contains(query.toLowerCase())
    ).toList();

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          title: Text("${user['prenom']} ${user['nom']}"),
          subtitle: Text(user["email"]),
          onTap: () {
            close(context, query);
          },
        );
      },
    );
  }
}