import 'package:daaga/client/changement.dart';
import 'package:flutter/material.dart';
import 'package:daaga/widget/Utilisateur.dart';
// 🔹 importe ta nouvelle page

class PageAPropos extends StatelessWidget {
  const PageAPropos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("À propos de Daaga")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bienvenue sur Daaga",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Daaga est une plateforme qui connecte acheteurs et vendeurs "
                  "dans un espace sécurisé et simple d’utilisation. "
                  "Notre mission est de faciliter les échanges et de donner "
                  "à chacun la possibilité de développer son activité.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),

            Text(
              "Votre rôle actuel : ${Utilisateur.role}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),

            const Spacer(), // 🔹 pousse le bouton en bas

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>  Changement()),
                  );
                },
                child: const Text(
                  "Changer de rôle",
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}