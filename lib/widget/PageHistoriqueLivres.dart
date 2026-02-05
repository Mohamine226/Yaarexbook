import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class PageLivresVendeur extends StatefulWidget {
  final int vendeurId;

  const PageLivresVendeur({super.key, required this.vendeurId});

  @override
  State<PageLivresVendeur> createState() => _PageLivresVendeurState();
}

class _PageLivresVendeurState extends State<PageLivresVendeur> {
  List<Map<String, dynamic>> livres = [];
  final ScrollController _scrollController = ScrollController();

  bool isLoading = false;
  bool hasMore = true;
  int skip = 0;
  final int limit = 20;

  @override
  void initState() {
    super.initState();
    _chargerLivres();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!isLoading && hasMore) {
          _chargerLivres();
        }
      }
    });
  }

  Future<void> _chargerLivres() async {
    setState(() => isLoading = true);

    final uri = Uri.parse("http://10.17.104.142:8000/documents/vendeur").replace(
      queryParameters: {
        'vendeur_id': '${widget.vendeurId}',
        'skip': '$skip',
        'limit': '$limit',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final newLivres = data.cast<Map<String, dynamic>>();

      setState(() {
        livres.addAll(newLivres);
        skip += limit;
        isLoading = false;
        if (newLivres.length < limit) {
          hasMore = false;
        }
      });
    } else {
      setState(() => isLoading = false);
      throw Exception("Erreur lors du chargement des livres");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Historique des livres"),
      ),
      body: livres.isEmpty && !isLoading
          ? const Center(child: Text("Aucun livre publié"))
          : ListView.builder(
        controller: _scrollController,
        itemCount: livres.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == livres.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = livres[index];
          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              leading: const Icon(Icons.book, color: Colors.blue),
              title: Text(doc["titre"]),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Langue : ${doc["langue"]}"),
                  Text("Achats : ${doc["achats"]}"),
                  doc["date_publication"] != null
                      ? Text("Publié le : ${doc["date_publication"]}")
                      : const SizedBox(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}