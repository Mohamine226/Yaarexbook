import 'dart:io';
import 'package:flutter/material.dart';
import 'package:daaga/client/LivreManager.dart';
import 'package:daaga/client/PdfData.dart';
import 'package:daaga/widget/PubliciterDetail.dart';

class PubliciterPage extends StatefulWidget {
  final int vendeurId; // 🔹 id du vendeur connecté

  const PubliciterPage({super.key, required this.vendeurId});

  @override
  State<PubliciterPage> createState() => _PubliciterPageState();
}

class _PubliciterPageState extends State<PubliciterPage> {
  List<PdfData> livres = [];
  final ScrollController _scrollController = ScrollController();

  bool isLoading = false;
  int skip = 0;
  final int limit = 20;
  bool hasMore = true;

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

    final docs = await LivreManager.fetchDocumentsParVendeur(
      widget.vendeurId,
      skip: skip,
      limit: limit,
    );

    setState(() {
      livres.insertAll(0, docs.reversed.toList());
      skip += limit;
      isLoading = false;
      if (docs.length < limit) {
        hasMore = false;
      }
    });
  }

  Widget _coverImage(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith("http://") || imagePath.startsWith("https://")) {
        return Image.network(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 60, color: Colors.red);
          },
        );
      } else if (imagePath.startsWith("assets/")) {
        return Image.asset(imagePath, fit: BoxFit.cover, width: double.infinity);
      } else {
        return Image.file(File(imagePath), fit: BoxFit.cover, width: double.infinity);
      }
    }
    return const Icon(Icons.book, size: 60, color: Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mes Publicités")),
      body: livres.isEmpty && !isLoading
          ? const Center(child: Text("Aucun produit publié"))
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          controller: _scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: livres.length + (hasMore ? 1 : 0), // 🔹 +1 pour loader
          itemBuilder: (context, index) {
            if (index == livres.length) {
              return const Center(child: CircularProgressIndicator());
            }
            final livre = livres[index];
            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PubliciterDetail(data: livre),
                  ),
                );
              },
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _coverImage(livre.image),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        livre.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Text(
                        "${livre.price} F",
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}