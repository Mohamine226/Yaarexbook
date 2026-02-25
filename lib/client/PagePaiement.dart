import 'package:flutter/material.dart';
import 'package:daaga/client/PdfData.dart';
import 'package:daaga/client/LivreManager.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;   // pour http.post
import 'dart:convert';                     // pour jsonEncode
import '../local/document_repository.dart'; // ✅ repository SQLite
import '../local/file_service.dart';        // ✅ service fichiers

class PagePaiement extends StatelessWidget {
  final PdfData livre;
  final int userId; // 🔹 identifiant de l’utilisateur connecté
  final DocumentRepository repository; // ✅ repository SQLite

  const PagePaiement({
    super.key,
    required this.livre,
    required this.userId,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Obtention")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              livre.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            //Text(
             // "Prix : ${livre.price} FCFA",
             // style: const TextStyle(
             //   fontSize: 18,
              //  color: Colors.green,
             // ),
           // ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                onPressed: () async {
                  final success = await LivreManager.ajouterDansBibliotheque(userId, livre.id!);

                  if (success) {
                    try {
                      // 🔹 Télécharger et chiffrer les fichiers via FileService
                      final localPdf = (livre.pdfUrl != null)
                          ? await FileService.downloadEncryptAndSaveFile(
                        livre.pdfUrl!,
                        "livre_${livre.id}.pdf",
                      )
                          : livre.pdfPath;

                      final localImage = (livre.imageUrl != null)
                          ? await FileService.downloadEncryptAndSaveFile(
                        livre.imageUrl!,
                        "image_${livre.id}.jpg",
                      )
                          : livre.image;

                      // 🔹 Créer une version offline
                      final purchasedDoc = livre.copyWith(
                        pdfPath: localPdf,
                        image: localImage,
                        achats: (livre.achats ?? 0) + 1, // ✅ incrémentation
                        userId: userId,
                      );

                      // 🔹 Sauvegarder dans SQLite via DocumentRepository
                      await repository.saveDocument(purchasedDoc);

                      // 🔹 Sauvegarder aussi dans Hive
                      final box = await Hive.openBox('bibliotheque_$userId');
                      final cached = (box.get('livres') as List?) ?? [];
                      final updated = [...cached, purchasedDoc.toJson()];
                      await box.put('livres', updated);


                      //  Ensuite seulement, envoyer la transaction vers ton API FastAPI
                      //final transactionJson = {
                      //  "montant": livre.price,
                      //  "document_id": livre.id,
                      //  "document_nom": livre.title,
                      //  "reference": "PAY-${DateTime.now().millisecondsSinceEpoch}",
                      //  "acheteur_id": userId,
                      //};

                      //final response = await http.post(
                       // Uri.parse("http://10.17.104.142:8000/wallets/achats/"),
                       // headers: {"Content-Type": "application/json"},
                      //  body: jsonEncode(transactionJson),
                      //);

                      //if (response.statusCode >= 200 && response.statusCode < 300) {
                      //  debugPrint("Transaction enregistrée: ${response.body}");
                       // ScaffoldMessenger.of(context).showSnackBar(
                       //   const SnackBar(content: Text("Paiement validé ")),
                       // );
                      //} else {
                       //   debugPrint("Erreur API: ${response.body}");
                        //  ScaffoldMessenger.of(context).showSnackBar(
                         // const SnackBar(content: Text("Erreur lors du paiement ")),
                       // );
                      //}

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Livre ajouté dans votre bibliothèque ")),
                      );

                      Navigator.pop(context, true);
                    } catch (e) {
                      debugPrint("Erreur lors de l'ajout offline: $e");
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Erreur lors du paiement ")),
                    );
                  }
                },
                child: const Text("Ajouter dans la bibliothèque"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}