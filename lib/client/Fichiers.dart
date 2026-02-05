import 'dart:io';
import 'package:daaga/mougli/MougliIA.dart';
import 'package:daaga/local/document_repository.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:daaga/widget/Recent.dart';
import 'package:daaga/client/DocumentPage.dart';
import 'package:daaga/client/BibliothequePage.dart';
import 'package:daaga/client/LivreManager.dart';
import 'package:daaga/widget/RecentPdf.dart';
import 'package:daaga/widget/RecentManager.dart';
import 'package:daaga/client/PdfData.dart';
import 'package:daaga/widget/Utilisateur.dart'; // 🔹 pour récupérer l’ID utilisateur

class Fichiers extends StatefulWidget {
  final DocumentRepository repository; // ✅ ajout

  const Fichiers({
    super.key,
    required this.repository,
  });

  @override
  State<Fichiers> createState() => _FichiersState();
}

class _FichiersState extends State<Fichiers> {
  int nbLivresAchetes = 0;
  int nbDocuments = 0;
  List<RecentPdf> maListeDeRecents = [];

  List<PdfData> mesDocuments = [];
  List<PdfData> mesLivresPayes = [];

  @override
  void initState() {
    super.initState();
    _chargerComptes();
    _chargerRecents();
  }

  Future<void> _chargerRecents() async {
    final recents = await RecentManager.getRecents();
    setState(() {
      maListeDeRecents = recents;
    });
  }

  Future<void> _chargerComptes() async {
    try {
      // 🔹 Essayer d'abord avec l'API
      final livresPayes = await LivreManager.fetchBibliotheque(Utilisateur.id, widget.repository);
      final livresPayesCount = livresPayes.length;

      // 🔹 Vérifier les fichiers locaux
      var status = await Permission.manageExternalStorage.request();
      int docsCount = 0;
      List<PdfData> localDocs = [];

      if (status.isGranted) {
        final dir = Directory("/storage/emulated/0/Download");
        final files = dir.existsSync() ? dir.listSync() : [];

        localDocs = files
            .where((f) =>
        f is File &&
            (f.path.toLowerCase().endsWith(".pdf") ||
                f.path.toLowerCase().endsWith(".docx") ||
                f.path.toLowerCase().endsWith(".txt")))
            .map((f) => PdfData(
          title: f.uri.pathSegments.last,
          pdfPath: f.path,
          language: "Inconnu",
          domain: "Local",
          description: "",
          price: 0,
          achats: 0,
        ))
            .toList();

        docsCount = localDocs.length;
      }

      setState(() {
        nbLivresAchetes = livresPayesCount;
        nbDocuments = docsCount;
        mesLivresPayes = livresPayes;
        mesDocuments = localDocs;
      });
    } catch (e) {
      debugPrint("Pas de connexion, fallback SQLite: $e");

      // 🔹 Fallback sur SQLite (repository)
      final livresPayesLocal =
      await widget.repository.getBibliotheque(Utilisateur.id);
      final livresPayesCount = livresPayesLocal.length;

      // 🔹 Vérifier les fichiers locaux
      var status = await Permission.manageExternalStorage.request();
      int docsCount = 0;
      List<PdfData> localDocs = [];

      if (status.isGranted) {
        final dir = Directory("/storage/emulated/0/Download");
        final files = dir.existsSync() ? dir.listSync() : [];

        localDocs = files
            .where((f) =>
        f is File &&
            (f.path.toLowerCase().endsWith(".pdf") ||
                f.path.toLowerCase().endsWith(".docx") ||
                f.path.toLowerCase().endsWith(".txt")))
            .map((f) => PdfData(
          title: f.uri.pathSegments.last,
          pdfPath: f.path,
          language: "Inconnu",
          domain: "Local",
          description: "",
          price: 0,
          achats: 0,
        ))
            .toList();

        docsCount = localDocs.length;
      }

      setState(() {
        nbLivresAchetes = livresPayesCount;
        nbDocuments = docsCount;
        mesLivresPayes = livresPayesLocal;
        mesDocuments = localDocs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(top: 70, left: 16),
            child: const Text(
              "Fichiers",
              style: TextStyle(
                color: Colors.green,
                fontSize: 35,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCategory(
                    context,
                    "Bibliothèque",
                    iconData: Icons.library_books,
                    color: Colors.blue,
                    count: nbLivresAchetes.toString(),
                  ),
                  _buildCategory(
                    context,
                    "Documents",
                    iconData: Icons.description,
                    color: Colors.green,
                    count: nbDocuments.toString(),
                  ),
                  _buildCategory(
                    context,
                    "Mougli IA",
                    iconWidget: Image.asset(
                      "assets/images/mougli.png",
                      height: 30,
                      width: 100,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Recent(recents: maListeDeRecents),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(
      BuildContext context,
      String title, {
        IconData? iconData,
        Widget? iconWidget,
        Color color = Colors.green,
        String count = "",
      }) {
    return InkWell(
      onTap: () {
        if (title == "Documents") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DocumentPage()),
          );
        } else if (title == "Bibliothèque") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BibliothequePage(
                userId: Utilisateur.id,
                repository: widget.repository, // ✅ correction
              ),
            ),
          );
        } else if (title == "Mougli IA") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MougliIA()),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget ??
              Icon(
                iconData,
                color: color,
                size: 32,
              ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (count.isNotEmpty)
            Text(
              count,
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
        ],
      ),
    );
  }
}