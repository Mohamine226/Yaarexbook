import 'package:flutter/material.dart';
import 'package:daaga/client/PdfData.dart';
import 'package:daaga/client/LivreManager.dart'; // 🔹 pour récupérer la bibliothèque
import 'package:daaga/widget/LecteurPage.dart';
import 'package:daaga/widget/RecentManager.dart';
import 'package:daaga/widget/RecentPdf.dart';
import 'package:hive_flutter/hive_flutter.dart';


import '../local/document_repository.dart';


class AffichageList extends StatefulWidget {
  final int userId;
  final DocumentRepository repository; // ✅ ajouté

  const AffichageList({
    super.key,
    required this.userId,
    required this.repository,
  });

  @override
  State<AffichageList> createState() => _AffichageListState();
}

class _AffichageListState extends State<AffichageList> {
  List<PdfData> files = [];

  @override
  void initState() {
    super.initState();
    _chargerLivres();
  }

  Future<void> _chargerLivres() async {
    final box = await Hive.openBox('bibliotheque_${widget.userId}');
    final cached = box.get('livres');

    List<PdfData> result = [];

    // 🔹 1️⃣ Charger rapidement depuis Hive
    if (cached != null) {
      result = (cached as List)
          .map((json) => PdfData.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } else {
      // 🔹 2️⃣ Sinon SQLite
      final local = await widget.repository.getBibliotheque(widget.userId);
      if (local.isNotEmpty) {
        result = local;
      }
    }

    if (result.isNotEmpty) {
      setState(() {
        files = result;
      });
    }

    // 🔹 3️⃣ API = source de vérité
    try {
      final apiDocs = await LivreManager.fetchBibliotheque(
        widget.userId,
        widget.repository,
      );

      if (apiDocs.isNotEmpty) {
        setState(() {
          files = apiDocs.reversed.toList();
        });

        // ✅ Hive seulement (SQLite déjà géré)
        await box.put(
          'livres',
          apiDocs.map((l) => l.toJson()).toList(),
        );
      }
    } catch (_) {
      // 🔹 4️⃣ Fallback silencieux : on garde ce qui est déjà affiché
    }
  }


  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(
        child: Text(
          "Aucun livre acheté pour l'instant",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      );
    }

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final livre = files[index];

        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.red,
            child: Text(
              "PDF",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            livre.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text("Langue : ${livre.language} • "),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'details') {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Détails du document"),
                    content: Text(
                      "Titre : ${livre.title}\n"
                          "Prix : ${livre.price} F\n"
                          "Langue : ${livre.language}\n"
                          "Domaine : ${livre.domain}\n"
                          "Description : ${livre.description}\n"
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Fermer"),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'details', child: Text('Détails')),
            ],
          ),
          onTap: () {
            if (livre.pdfPath != null && livre.pdfPath!.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LecteurPage(
                    path: livre.pdfPath!,
                    isLocalDocument: false,
                    pdfData: livre,
                  ),
                ),
              );

              final recent = RecentPdf(
                fileName: livre.title,
                openedAt: DateTime.now().toString(),
                path: livre.pdfPath!,
              );
              RecentManager.addRecent(recent);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Chemin PDF invalide")),
              );
            }
          },
        );
      },
    );
  }
}