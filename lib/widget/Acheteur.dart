import 'dart:io';

import 'package:daaga/PageConnexion.dart';
import 'package:daaga/client/HistoriquePage1.dart';
import 'package:daaga/client/Parametre1Page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';
import 'Utilisateur.dart';

class Acheteur extends StatelessWidget {
  final int documentsAchetes; // 🔹 nombre de documents achetés
  final int userId;           // 🔹 id utilisateur
  final String deviceType;    // 🔹 type d'appareil ("mobile" ou "pc")

  const Acheteur({
    Key? key,
    required this.documentsAchetes,
    required this.userId,
    required this.deviceType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔹 Bloc statistiques
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statBox("Documents achetés", documentsAchetes.toString()),
            ],
          ),
        ),

        // 🔹 Bloc actions
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _actionButton(
                Icons.access_time,
                "Historique",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HistoriquePage1(userId: userId)),
                  );
                },
              ),
              _actionButton(
                Icons.settings,
                "Paramètre",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Parametre1Page()),
                  );
                },
              ),
              _actionButton(
                Icons.logout,
                "Déconnexion",
                onTap: () async {
                  try {
                    // 🔹 Vérifier le token avant l'appel
                    final tokenAvant = await ApiService.getToken();
                    print("📦 Token récupéré avant logout: $tokenAvant");

                    // Déterminer le type de device
                    String deviceType;
                    if (Platform.isAndroid || Platform.isIOS) {
                      deviceType = "mobile";
                    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                      deviceType = "pc";
                    } else {
                      deviceType = "unknown"; // fallback
                    }

                    // 🔹 Appel API logout
                    final response = await ApiService.logout(
                      userId: Utilisateur.id,
                      deviceType: deviceType, // "mobile" ou "pc"
                    );
                    print("✅ Réponse serveur logout: $response");
                    // 🔹 Vérifier si la déconnexion est acceptée par le serveur
                    if (response['status'] == "success") {
                      // Supprimer le token local
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove("jwt");
                      await prefs.remove("token");
                      await prefs.remove("userId");
                      await prefs.remove("nom");
                      await prefs.remove("prenom");
                      await prefs.remove("email");
                      await prefs.remove("telephone");
                      await prefs.remove("pays");
                      await prefs.remove("travail");
                      await prefs.remove("role");

                      // Vérifier après suppression
                      final tokenApres = await ApiService.getToken();
                      print("❌ Token après suppression: $tokenApres");
                      // Message utilisateur
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(response['message'] ?? "Déconnecté")),
                      );

                      // Redirection vers la page de connexion
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const PageConnexion()),
                            (route) => false,
                      );
                    } else {
                      // 🔹 Si la base refuse la déconnexion
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(response['message'] ?? "Déconnexion refusée")),
                      );
                    }
                  } catch (e) {
                    print("Erreur logout: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Erreur lors de la déconnexion")),
                    );
                  }
                },
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      width: 140, // ✅ largeur fixe pour éviter les erreurs
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(
        icon,
        color: label == "Déconnexion" ? Colors.red : Colors.black,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: label == "Déconnexion" ? Colors.red : Colors.black,
        ),
      ),
      onTap: onTap,
    );
  }
}