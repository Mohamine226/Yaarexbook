import 'package:flutter/material.dart';
import 'package:daaga/widget/Utilisateur.dart';

class PageAPropos2 extends StatelessWidget {
  const PageAPropos2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("À propos de Daaga")),
      body: SingleChildScrollView( //  rend la page scrollable
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Bienvenue sur MyEbook",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "MyEbook est une plateforme innovante qui connecte les lecteurs dans un espace sécurisé, simple et accessible à tous. "
                    "Notre mission est de faciliter l’accès aux documents numériques, qu’il s’agisse de livres, de cours ou de ressources éducatives, "
                    "afin de permettre à chacun de se cultiver, d’élargir ses connaissances et de développer ses compétences. "
                    "Nous croyons que le savoir doit être partagé et que l’éducation est un levier essentiel pour l’épanouissement personnel et collectif. "
                    "Avec MyEbook, vous disposez d’un outil moderne pour découvrir, lire et gérer vos documents en toute liberté, "
                    "tout en bénéficiant d’une expérience fluide et adaptée à vos besoins.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),

              Text(
                "Votre rôle actuel : ${Utilisateur.role}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 50), //  remplace Spacer pour compatibilité avec scroll
            ],
          ),
        ),
      ),
    );
  }
}