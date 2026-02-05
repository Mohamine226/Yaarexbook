import 'dart:io';
import 'package:flutter/material.dart';
import 'package:daaga/client/LivreManager.dart';
import 'package:daaga/client/PdfData.dart';
import 'package:daaga/admin/Detail.dart';

class VoirDesactiver extends StatefulWidget {
  const VoirDesactiver({super.key});

  @override
  State<VoirDesactiver> createState() => _VoirDesactiverState();
}

class _VoirDesactiverState extends State<VoirDesactiver> {
  List<PdfData> publications = [];
  List<PdfData> filteredPublications = [];

  final ScrollController _scrollController = ScrollController();

  bool isLoading = false;
  bool hasMore = true;
  int skip = 0;
  final int limit = 20;

  @override
  void initState() {
    super.initState();
    _chargerDocuments();

    // 🔹 Détecter quand on arrive en bas
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!isLoading && hasMore) {
          _chargerDocuments();
        }
      }
    });
  }

  Future<void> _chargerDocuments() async {
    setState(() => isLoading = true);

    final docs = await LivreManager.fetchDocumentsDesactives(skip: skip, limit: limit);

    setState(() {
      publications.addAll(docs.reversed); // 🔹 nouveaux en haut
      filteredPublications = publications;
      skip += limit;
      isLoading = false;
      if (docs.length < limit) {
        hasMore = false; // ✅ plus de données
      }
    });
  }

  void _searchBooks(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredPublications = publications;
      } else {
        filteredPublications = publications
            .where((pub) =>
        pub.title.toLowerCase().contains(query.toLowerCase()) ||
            pub.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _deleteBook(PdfData book) async {
    final success = await LivreManager.supprimerDocumentAPI(book.id!);

    if (success) {
      setState(() {
        publications.remove(book);
        filteredPublications.remove(book);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("« ${book.title} » supprimé ✅")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la suppression ❌")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Documents désactivés"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final result = await showSearch<String>(
                context: context,
                delegate: LivreSearchDelegate(
                  publications: publications,
                  onDelete: _deleteBook,
                ),
              );
              if (result != null) {
                _searchBooks(result);
              }
            },
          ),
        ],
      ),
      body: filteredPublications.isEmpty && !isLoading
          ? const Center(
        child: Text(
          "Aucun document désactivé",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      )
          : GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: filteredPublications.length + (hasMore ? 1 : 0), // 🔹 +1 pour loader
        itemBuilder: (context, index) {
          if (index == filteredPublications.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final pub = filteredPublications[index];
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Detail(data: pub),
                        ),
                      );
                    },
                    child: pub.image != null && pub.image!.isNotEmpty
                        ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: pub.image!.startsWith("http")
                          ? Image.network(pub.image!, fit: BoxFit.cover)
                          : pub.image!.startsWith("assets/")
                          ? Image.asset(pub.image!, fit: BoxFit.cover)
                          : Image.file(File(pub.image!), fit: BoxFit.cover),
                    )
                        : Container(
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: const Icon(Icons.picture_as_pdf, size: 50, color: Colors.white),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pub.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text("${pub.price.toStringAsFixed(2)} USD",
                          style: const TextStyle(
                              fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          onPressed: () => _deleteBook(pub),
                          child: const Text("Supprimer", style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class LivreSearchDelegate extends SearchDelegate<String> {
  final List<PdfData> publications;
  final void Function(PdfData) onDelete;

  LivreSearchDelegate({
    required this.publications,
    required this.onDelete,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = "",
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ""),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = publications.where((pub) {
      final q = query.toLowerCase();
      return pub.title.toLowerCase().contains(q) ||
          pub.description.toLowerCase().contains(q);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final pub = results[index];
        return ListTile(
          title: Text(pub.title),
          subtitle: Text("${pub.price.toStringAsFixed(2)} USD"),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              onDelete(pub);
              close(context, pub.title);
            },
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = publications.where((pub) {
      final q = query.toLowerCase();
      return pub.title.toLowerCase().contains(q) ||
          pub.description.toLowerCase().contains(q);
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final pub = suggestions[index];
        return ListTile(
          title: Text(pub.title),
          subtitle: Text("${pub.price.toStringAsFixed(2)} USD"),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              onDelete(pub);
              close(context, pub.title);
            },
          ),
        );
      },
    );
  }
}