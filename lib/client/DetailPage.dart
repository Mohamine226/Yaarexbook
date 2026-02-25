

import 'package:daaga/local/document_repository.dart';
import 'package:flutter/material.dart';
import 'package:daaga/client/PdfData.dart';
import 'package:daaga/client/PagePaiement.dart';

import 'dart:typed_data';
import '../local/file_service.dart'; // 🔹 importe la page de paiement

class DetailPage extends StatefulWidget {
  final PdfData data;
  final int userId; // 🔹 identifiant de l’utilisateur connecté
  final DocumentRepository repository; // ✅ ajout du repository

  const DetailPage({
    super.key,
    required this.data,
    required this.userId,
    required this.repository,
  });


  @override
  State<DetailPage> createState() => _DetailPageState(); // ✅ ligne manquante
}

class _DetailPageState extends State<DetailPage> {



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.data.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Image du document en haut
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 70.0, vertical: 8.0),
              child: SizedBox(
                height: 320,
                width: 200,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(2, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                leading: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                title: const Text("Couverture"),
                              ),
                              body: Center(
                                child: widget.data.image != null && widget.data.image!.trim().isNotEmpty
                                    ? (widget.data.image!.startsWith("http")
                                    ? Image.network(widget.data.image!, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.picture_as_pdf,
                                        size: 120, color: Colors.red))
                                    : widget.data.image!.startsWith("assets/")
                                    ? Image.asset(widget.data.image!, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.picture_as_pdf,
                                        size: 120, color: Colors.red))
                                    : FutureBuilder<Uint8List?>(
                                  future: FileService.decryptImage(widget.data.image!),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const CircularProgressIndicator();
                                    }
                                    if (snapshot.hasError || !snapshot.hasData) {
                                      // 🔹 Fallback PDF rouge
                                      return const Icon(Icons.picture_as_pdf,
                                          size: 120, color: Colors.red);
                                    }
                                    return Image.memory(snapshot.data!,
                                        fit: BoxFit.contain);
                                  },
                                ))
                                    : const Icon(Icons.picture_as_pdf,
                                    size: 120, color: Colors.red), // 🔹 Fallback PDF rouge
                              ),
                            ),
                          ),
                        );
                      },
                      child: (widget.data.image != null && widget.data.image!.trim().isNotEmpty)
                          ? (widget.data.image!.startsWith("http")
                          ? Image.network(widget.data.image!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red))
                          : widget.data.image!.startsWith("assets/")
                          ? Image.asset(widget.data.image!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                          const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red))
                          : FutureBuilder<Uint8List?>(
                        future: FileService.decryptImage(widget.data.image!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            // 🔹 Fallback PDF rouge
                            return const Icon(Icons.picture_as_pdf,
                                size: 80, color: Colors.red);
                          }
                          return Image.memory(snapshot.data!, fit: BoxFit.cover);
                        },
                      ))
                          : const Center(
                        // 🔹 Fallback PDF rouge si pas d'image
                        child: Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 Bloc infos avec bordure globale
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Titre: ${widget.data.title}",
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("Domaine : ${widget.data.domain}",
                          style: const TextStyle(fontSize: 16)),
                      Text("Langue : ${widget.data.language}",
                          style: const TextStyle(fontSize: 16)),
                      //Text("${widget.data.price} FCFA",
                      //    style: const TextStyle(
                       //       fontSize: 18,
                       //       fontWeight: FontWeight.bold,
                        //      color: Colors.green)),
                      const SizedBox(height: 16),
                      Text("Desciption: ${widget.data.description}",
                          style: const TextStyle(
                              fontSize: 15, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 🔹 Bouton Acheter
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                  onPressed: () async {


                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PagePaiement(
                          livre: widget.data,
                          userId: widget.userId,

                          repository: widget.repository,
                        ),
                      ),
                    );

                    if (result == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Livre ajouté à votre bibliothèque ")),
                      );
                    }

                  },
                child: const Text("Obtenir",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}