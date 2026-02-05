import 'dart:io';
import 'package:flutter/material.dart';
import 'package:daaga/client/PdfData.dart';

class PubliciterDetail extends StatefulWidget {
  final PdfData data;

  const PubliciterDetail({
    super.key,
    required this.data,
  });

  @override
  State<PubliciterDetail> createState() => _PubliciterDetailState();
}

class _PubliciterDetailState extends State<PubliciterDetail> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Détail du document")),
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
                                child: widget.data.image != null && widget.data.image!.isNotEmpty
                                    ? (widget.data.image!.startsWith("http")
                                    ? Image.network(widget.data.image!, fit: BoxFit.contain)
                                    : widget.data.image!.startsWith("assets/")
                                    ? Image.asset(widget.data.image!, fit: BoxFit.contain)
                                    : Image.file(File(widget.data.image!), fit: BoxFit.contain))
                                    : const Icon(Icons.picture_as_pdf,
                                    size: 120, color: Colors.green),
                              ),
                            ),
                          ),
                        );
                      },
                      child: widget.data.image != null && widget.data.image!.isNotEmpty
                          ? (widget.data.image!.startsWith("http")
                          ? Image.network(widget.data.image!, fit: BoxFit.cover)
                          : widget.data.image!.startsWith("assets/")
                          ? Image.asset(widget.data.image!, fit: BoxFit.cover)
                          : Image.file(File(widget.data.image!), fit: BoxFit.cover))
                          : const Center(
                        child: Icon(Icons.picture_as_pdf,
                            size: 80, color: Colors.green),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 Contenu avec bordure
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black26, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 Titre
                  Text(
                    widget.data.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 🔹 Domaine
                  Text(
                    "Domaine : ${widget.data.domain}",
                    style:
                    const TextStyle(fontSize: 16, color: Colors.black87),
                  ),

                  const SizedBox(height: 8),

                  // 🔹 Langue
                  Text(
                    "Langue : ${widget.data.language}",
                    style:
                    const TextStyle(fontSize: 16, color: Colors.black87),
                  ),

                  const SizedBox(height: 8),

                  // 🔹 Prix
                  Text(
                    "Prix : ${widget.data.price.toStringAsFixed(2)} F",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Description
                  Text(
                    widget.data.description,
                    style:
                    const TextStyle(fontSize: 15, color: Colors.black87),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Lien PDF
                  if (widget.data.pdfPath != null &&
                      widget.data.pdfPath!.isNotEmpty)
                    Text(
                      "Lien PDF : ${widget.data.pdfPath}",
                      style: const TextStyle(
                          fontSize: 14,
                          color: Colors.blueGrey,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}