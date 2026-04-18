import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:daaga/PageConnexion.dart';

import '../services/api_services.dart';

class StatistiquePage extends StatefulWidget {
  const StatistiquePage({super.key});

  @override
  State<StatistiquePage> createState() => _StatistiquePageState();
}

class _StatistiquePageState extends State<StatistiquePage> {
  int totalUtilisateurs = 0;
  int totalVendeurs = 0;
  int totalAcheteurs = 0;
  int totalDocuments = 0;

  int achatsMois = 0;
  int achatsAnnee = 0;
  int achatsDepuisCreation = 0;

  @override
  void initState() {
    super.initState();
    fetchGlobalStats();
  }

  Future<void> fetchGlobalStats() async {
    try {
      final response = await http.get(
        Uri.parse("https://daaga-production.up.railway.app/api/statistiques/global"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          totalUtilisateurs = data['total_utilisateurs'];
          totalVendeurs = data['total_vendeurs'];
          totalAcheteurs = data['total_acheteurs'];
          totalDocuments = data['total_documents'];

          achatsMois = data['achats_mois'];
          achatsAnnee = data['achats_annee'];
          achatsDepuisCreation = data['achats_depuis_creation'];
        });
      } else {
        print("Erreur API: ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur API: $e");
    }
  }

  Widget buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Statistiques")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Résumé global",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 🔹 Première ligne
            Row(
              children: [
                buildStatCard("Utilisateurs", "$totalUtilisateurs", Icons.people, Colors.blue),
                buildStatCard("Vendeurs", "$totalVendeurs", Icons.store, Colors.orange),
              ],
            ),

            // 🔹 Deuxième ligne
            Row(
              children: [
                buildStatCard("Acheteurs", "$totalAcheteurs", Icons.shopping_cart, Colors.green),
                buildStatCard("Documents", "$totalDocuments", Icons.book, Colors.purple),
              ],
            ),

            const SizedBox(height: 30),
            const Text(
              "Achats",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 🔹 Ligne des achats
            Row(
              children: [
                buildStatCard("Par mois", "$achatsMois", Icons.calendar_month, Colors.teal),
                buildStatCard("Par an", "$achatsAnnee", Icons.date_range, Colors.indigo),
              ],
            ),

            Row(
              children: [
                buildStatCard("Depuis création", "$achatsDepuisCreation", Icons.history, Colors.red),
              ],
            ),

            const SizedBox(height: 40),

            // 🔹 Bouton Déconnexion
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              "Déconnexion",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            onPressed: () async {
              try {
                // 🔹 Appel API logout
                final response = await ApiService.logout();

                // 🔹 Afficher le message du serveur
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(response["message"] ?? "Déconnecté")),
                );

                // 🔹 Rediriger vers la page de connexion
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const PageConnexion()),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erreur lors de la déconnexion")),
                );
              }
            },
          ),
        )
          ],
        ),
      ),
    );
  }
}