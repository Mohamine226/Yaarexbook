import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PageAcheteur extends StatefulWidget {
  const PageAcheteur({super.key});

  @override
  State<PageAcheteur> createState() => _PageAcheteurState();
}

class _PageAcheteurState extends State<PageAcheteur> {
  List<Map<String, dynamic>> utilisateurs = [];
  final ScrollController _scrollController = ScrollController();

  bool isLoading = false;
  bool hasMore = true;
  int skip = 0;
  final int limit = 20;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _chargerUtilisateurs();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!isLoading && hasMore) {
          _chargerUtilisateurs();
        }
      }
    });
  }

  Future<void> _chargerUtilisateurs() async {
    setState(() => isLoading = true);

    final uri = Uri.parse("http://daaga-production.up.railway.app/users/").replace(
      queryParameters: {
        'skip': '$skip',
        'limit': '$limit',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      final newUsers = data
          .cast<Map<String, dynamic>>()
          .where((user) => user["role"] == "Lecteur" || user["role"] == "admin")
          .toList();

      newUsers.sort((a, b) => b["id"].compareTo(a["id"]));

      setState(() {
        utilisateurs.addAll(newUsers);
        skip += limit;
        isLoading = false;
        if (newUsers.length < limit) {
          hasMore = false;
        }
      });
    } else {
      setState(() => isLoading = false);
      throw Exception("Erreur lors du chargement des utilisateurs");
    }
  }

  Future<void> supprimerUtilisateur(int id) async {
    final response = await http.delete(Uri.parse("https://daaga-production.up.railway.app/users/$id"));

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Utilisateur supprimé")),
      );
      setState(() {
        utilisateurs.removeWhere((u) => u["id"] == id);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Erreur lors de la suppression")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var users = utilisateurs;
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
        title: const Text("Liste des Acheteurs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final result = await showSearch(
                context: context,
                delegate: AcheteurSearchDelegate(utilisateurs),
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
          ? const Center(child: Text("Aucun acheteur trouvé"))
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
              leading: const Icon(Icons.person, color: Colors.green),
              title: Text("${user['prenom']} ${user['nom']}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Email : ${user['email']}"),
                  Text("Téléphone : ${user['telephone']}"),
                  Text("Pays : ${user['pays']}"),
                  Text("Travail : ${user['profession'] ?? user['travail']}"),
                  Text("Role : ${user['role']}"),
                  Text("Date de creation : ${user['date_publication']}"),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  supprimerUtilisateur(user["id"]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 🔹 Delegate pour la recherche
class AcheteurSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> utilisateurs;

  AcheteurSearchDelegate(this.utilisateurs);

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
    final users = utilisateurs.where((user) =>
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