import 'package:flutter/material.dart';

class MisesAJourPage extends StatelessWidget {
  const MisesAJourPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mises à jour")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Vérification des mises à jour",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Cette section vous permet de vérifier si une nouvelle version de l'application Daaga est disponible.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),

            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.system_update),
                label: const Text("Vérifier maintenant"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // 🔹 Ici tu peux mettre un appel API ou une logique de vérification
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Aucune mise à jour disponible pour le moment")),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}