import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:daaga/client/PdfData.dart';
import 'package:daaga/client/LivreManager.dart';
import 'package:daaga/widget/Utilisateur.dart'; // pour accéder à Utilisateur.id

class PublierPage extends StatefulWidget {
  const PublierPage({super.key});

  @override
  State<PublierPage> createState() => _PublierPageState();
}

class _PublierPageState extends State<PublierPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController titreController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController prixController = TextEditingController();

  String selectedCategorie = "Science";
  String selectedLangue = "Français";
  String selectedDomaine = "";

  String? pdfPath;
  String? couverturePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Publier un document")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Champ titre
                  TextFormField(
                    controller: titreController,
                    decoration: InputDecoration(
                      labelText: "Titre du document",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    validator: (value) =>
                    (value == null || value.isEmpty) ? "Veuillez saisir un titre" : null,
                  ),
                  const SizedBox(height: 16),

                  // Catégorie
                  DropdownButtonFormField<String>(
                    value: selectedCategorie,
                    items: [
                      "Science",
                      "Éducation",
                      "Roman",
                      "Concour",
                      "Business",
                      "Histoire",
                    ]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) => setState(() => selectedCategorie = val!),
                    decoration: const InputDecoration(labelText: "Catégorie"),
                  ),
                  const SizedBox(height: 16),

                  // Domaine
                  TextFormField(
                    initialValue: selectedDomaine,
                    decoration: InputDecoration(
                      labelText: "Domaine",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (val) => selectedDomaine = val,
                    validator: (value) =>
                    (value == null || value.isEmpty) ? "Veuillez saisir un domaine" : null,
                  ),
                  const SizedBox(height: 16),

                  // Langue
                  DropdownButtonFormField<String>(
                    value: selectedLangue,
                    items: ["Français", "Anglais", "Espagnol"]
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (val) => setState(() => selectedLangue = val!),
                    decoration: const InputDecoration(labelText: "Langue"),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: "Description",
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    validator: (value) =>
                    (value == null || value.isEmpty) ? "Veuillez saisir une description" : null,
                  ),
                  const SizedBox(height: 16),

                  // Import PDF
                  ElevatedButton.icon(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );
                      if (result != null) {
                        setState(() {
                          pdfPath = result.files.single.path;
                        });
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(pdfPath == null
                        ? "Importer le fichier PDF"
                        : "PDF sélectionné"),
                  ),
                  if (pdfPath == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text("⚠️ Veuillez importer un PDF",
                          style: TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 16),

                  // Import couverture
                  ElevatedButton.icon(
                    onPressed: () async {
                      FilePickerResult? result =
                      await FilePicker.platform.pickFiles(type: FileType.image);
                      if (result != null) {
                        setState(() {
                          couverturePath = result.files.single.path;
                        });
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: Text(couverturePath == null
                        ? "Importer la couverture du livre"
                        : "Image sélectionnée"),
                  ),
                  if (couverturePath == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text("⚠️ Veuillez importer une couverture",
                          style: TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 16),

                  // Prix
                  TextFormField(
                    controller: prixController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Prix",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Veuillez saisir un prix";
                      }
                      if (double.tryParse(value) == null) {
                        return "Veuillez entrer un nombre valide";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Bouton Publier
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState!.validate() &&
                            pdfPath != null &&
                            couverturePath != null) {
                          final nouveauLivre = PdfData(
                            title: titreController.text.trim(),
                            price: int.tryParse(prixController.text.trim()) ?? 0,
                            image: couverturePath!, // chemin local image
                            domain: selectedDomaine.trim(),
                            language: selectedLangue,
                            description: descriptionController.text.trim(),
                            pdfPath: pdfPath!, // chemin local PDF
                            categorie: selectedCategorie,
                          );

                          debugPrint("Publication par Utilisateur.id=${Utilisateur.id}");
                          final success = await LivreManager.publierDocument(
                            Utilisateur.id,
                            nouveauLivre
                          );


                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Livre publié avec succès ✅")),
                            );
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Erreur lors de la publication ❌")),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Veuillez remplir tous les champs et importer les fichiers")),
                          );
                        }
                      },
                      child: const Text(
                        "Publier",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}