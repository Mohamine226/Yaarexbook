import 'dart:io';
import 'package:daaga/PageConnexion.dart';
import 'package:daaga/client/HistoriquePage2.dart';
import 'package:daaga/client/PageRetrait.dart';
import 'package:daaga/client/Parametre2Page.dart';
import 'package:daaga/client/PubliciterPage.dart';
import 'package:daaga/widget/PageHistoriqueLivres.dart';
import 'package:flutter/material.dart';
import 'package:daaga/widget/PublierPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../client/LivreManager.dart';
import '../local/document_repository.dart';
import '../services/api_services.dart';
import 'Utilisateur.dart';

class Vendeur extends StatefulWidget {
  final DocumentRepository repository;
  final int vendeurId;
  final int userId;
  final String deviceType;

  const Vendeur({
    Key? key,
    required this.repository,
    required this.vendeurId,
    required this.userId,
    required this.deviceType,
  }) : super(key: key);

  @override
  State<Vendeur> createState() => _VendeurState();
}

class _VendeurState extends State<Vendeur> {
  int nbLivresPublies = 0;
  int nbDocumentsVendus = 0;
  int documentsAchetes = 0;
  int totalGagne = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    chargerStats();
  }

  Future<void> chargerStats() async {
    try {
      var box = await Hive.openBox('compte_${Utilisateur.id}');
      var cached = box.get('stats');

      if (cached != null) {
        setState(() {
          nbLivresPublies = cached['nbLivresPublies'] ?? 0;
          nbDocumentsVendus = cached['nbDocumentsVendus'] ?? 0;
          documentsAchetes = cached['nbLivresAchetes'] ?? 0;
          totalGagne = (cached['totalGagne'] is num)
              ? (cached['totalGagne'] as num).toInt()
              : 0;
          isLoading = false;
        });
      }

      final publies = await LivreManager.fetchDocumentsParVendeur(Utilisateur.id);
      final gains = await LivreManager.getSolde(Utilisateur.id);
      final ventes = await LivreManager.getNombreVentesParUser(Utilisateur.id);
      final achetes = await LivreManager.fetchBibliotheque(Utilisateur.id, widget.repository);

      final nbPublies = publies.length;
      final nbVendus = ventes["nombre_ventes"] ?? 0;
      final nbAchetes = achetes.length;
      final solde = (gains["solde_disponible"] is num)
          ? (gains["solde_disponible"] as num).toInt()
          : 0;

      setState(() {
        nbLivresPublies = nbPublies;
        nbDocumentsVendus = nbVendus;
        documentsAchetes = nbAchetes;
        totalGagne = solde;
        isLoading = false;
      });

      await box.put('stats', {
        'nbLivresPublies': nbPublies,
        'nbDocumentsVendus': nbVendus,
        'nbLivresAchetes': nbAchetes,
        'totalGagne': solde,
      });
    } catch (e) {
      debugPrint("Erreur lors du chargement des stats: $e");

      try {
        final publiesLocal = await widget.repository.getDocumentsParVendeur(Utilisateur.id);
        final gainsList = await widget.repository.getSolde(Utilisateur.id);
        final ventesList = await widget.repository.getNombreVentesParUser(Utilisateur.id);
        final achetesLocal = await widget.repository.getBibliotheque(Utilisateur.id);

        final nbPublies = publiesLocal.length;
        final nbVendus = ventesList.length;
        final nbAchetes = achetesLocal.length;

        // Ici on force le solde en entier
        final solde = gainsList.fold<int>(
          0,
              (sum, doc) => sum + ((doc.price ?? 0).toInt()),
        );

        setState(() {
          nbLivresPublies = nbPublies;
          nbDocumentsVendus = nbVendus;
          documentsAchetes = nbAchetes;
          totalGagne = solde;
          isLoading = false;
        });

        var box = await Hive.openBox('compte_${Utilisateur.id}');
        await box.put('stats', {
          'nbLivresPublies': nbPublies,
          'nbDocumentsVendus': nbVendus,
          'nbLivresAchetes': nbAchetes,
          'totalGagne': solde,
        });
      } catch (e2) {
        debugPrint("Erreur fallback: $e2");
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // 🔹 Solde disponible
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
              title: const Text("Solde disponible"),
              subtitle: Text("$totalGagne FCFA",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ), // ✅correction
            ),
          ),

          // 🔹 Bloc statistiques
          // 🔹 Bloc statistiques
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statBox("Documents achetés", documentsAchetes.toString()), // ✅ réaffiché
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statBox("Livres publiés", nbLivresPublies.toString()),
                    _statBox("Documents vendus", nbDocumentsVendus.toString()),
                  ],
                ),
              ],
            ),
          ),

          // 🔹 Bloc actions
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _actionButton(Icons.access_time, "Historique", onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoriquePage2(
                        userId: widget.userId,
                        walletId: widget.vendeurId,
                      ),
                    ),
                  );
                }),
                ExpansionTile(
                  leading: const Icon(Icons.upload, color: Colors.black),
                  title: const Text("Mes publications"),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.upload),
                      title: const Text("Publier un document"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PublierPage()),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.campaign),
                      title: const Text("Mes publicités"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PubliciterPage(vendeurId: widget.vendeurId),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text("Historique des livres"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PageLivresVendeur(vendeurId: widget.vendeurId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                _actionButton(Icons.remove_circle, "Retirer", onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PageRetrait(solde: totalGagne),
                    ),
                  );
                }),
                _actionButton(Icons.settings, "Paramètre", onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Parametre2Page()),
                  );
                }),
                _actionButton(
                  Icons.logout,
                  "Déconnexion",
                  onTap: () async {
                    try {
                      final tokenAvant = await ApiService.getToken();
                      print(" Token récupéré avant logout: $tokenAvant");

                      String deviceType;
                      if (Platform.isAndroid || Platform.isIOS) {
                        deviceType = "mobile";
                      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                        deviceType = "pc";
                      } else {
                        deviceType = "unknown";
                      }

                      final response = await ApiService.logout(
                        userId: Utilisateur.id,
                        deviceType: deviceType,
                      );
                      print(" Réponse serveur logout: $response");

                      if (response['status'] == "success") {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();

                        final tokenApres = await ApiService.getToken();
                        print("❌ Token après suppression: $tokenApres");

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(response['message'] ?? "Déconnecté")),
                        );

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const PageConnexion()),
                              (route) => false,
                        );
                      } else {
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
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      width: 130,
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: label == "Déconnexion" ? Colors.red : Colors.black),
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