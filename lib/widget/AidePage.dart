import 'package:flutter/material.dart';

class AidePage extends StatelessWidget {
  const AidePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Aide")),
      body: const SingleChildScrollView( // ✅ rend la page scrollable
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24), // ✅ padding ajusté
          child: Text(
            "Bienvenue dans la section Aide.\n\n"
                "Comment utiliser MyEbook :\n"
                "- Connectez-vous avec votre email ou numéro de téléphone.\n"
                "- Recherchez vos documents grâce à la barre de recherche.\n"
                "- Ou faites défiler sur la plateforme pour voir les documents que vous désirez lire.\n"
                "- Vous pouvez ajouter le document que vous voulez à votre bibliothèque.\n"
                "- Vos fichiers locaux sont dans la partie Fichiers de la section Documents.\n"
                "- Ouvrez un livre en un clic et profitez d'une lecture fluide.\n\n"
                "❓ Questions fréquentes :\n"
                "1. Comment importer mes documents ?\n"
                "   → Dès l'installation de l'application, vous devrez autoriser l'application à avoir accès à vos documents.\n\n"
                "2. Où sont stockés mes livres ?\n"
                "   → Vos documents restent sur votre téléphone, l’application ne les supprime pas.\n\n"
                "3. Puis-je lire mes fichiers hors connexion ?\n"
                "   → Oui, tous les documents dans votre bibliothèque sont accessibles même sans Internet.\n\n"
                "  Sécurité :\n"
                "Vos données personnelles sont protégées et ne sont jamais partagées.\n\n"
                "  Besoin d’aide supplémentaire ?\n"
                "Contactez notre support via la section 'Feedback' ou consultez les mises à jour dans Paramètres.",
            style: TextStyle(fontSize: 16, height: 1.5), // ✅ lisibilité améliorée
          ),
        ),
      ),
    );
  }
}