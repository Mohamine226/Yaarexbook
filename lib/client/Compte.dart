import 'package:flutter/material.dart';
import 'package:daaga/widget/Profil.dart';
import 'package:daaga/widget/Acheteur.dart';
import 'package:daaga/widget/Vendeur.dart';
import 'package:daaga/widget/Utilisateur.dart';
import 'package:daaga/client/LivreManager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../local/document_repository.dart';

class Compte extends StatefulWidget {
  final DocumentRepository repository;
  const Compte({Key? key, required this.repository}) : super(key: key);
  @override
  State<Compte> createState() => _CompteState();
}

class _CompteState extends State<Compte> {
  int nbLivresAchetes = 0;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    chargerStats(); // ✅ appel correct
  }

  Future<void> chargerStats() async {
    try {
      var box = await Hive.openBox('compte_${Utilisateur.id}');
      var cached = box.get('stats');

      if (cached != null) {
        setState(() {
          nbLivresAchetes = cached['nbLivresAchetes'] ?? 0;

          isLoading = false;
        });
      }
      final achetes = await LivreManager.fetchBibliotheque(Utilisateur.id, widget.repository);
      final nbAchetes = achetes.length;
      setState(() {
        nbLivresAchetes = nbAchetes;

        isLoading = false; // ✅ loader désactivé
      });

      await box.put('stats', {
        'nbLivresAchetes': nbAchetes,
      });
    } catch (e) {
      debugPrint("Erreur lors du chargement des stats: $e");
      try {
        final achetesLocal = await widget.repository.getBibliotheque(Utilisateur.id);

        final nbAchetes = achetesLocal.length;
        setState(() {
          nbLivresAchetes = nbAchetes;
          isLoading = false; // ✅ loader désactivé même en cas d’erreur
        });

        var box = await Hive.openBox('compte_${Utilisateur.id}');
        await box.put('stats', {
          'nbLivresAchetes': nbAchetes,
        });
      } catch (e2) {
        debugPrint("Erreur fallback: $e2");
        setState(() {
          isLoading = false; // ✅ ne reste pas bloqué
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Mon Profil",
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // 🔹 loader
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔹 Profil utilisateur
          Profil(
            nom: Utilisateur.nom,
            prenom: Utilisateur.prenom,
            email: Utilisateur.email,
            telephone: Utilisateur.telephone,
            pays: Utilisateur.pays,
            role: Utilisateur.role,
          ),

          const SizedBox(height: 20),

          // 🔹 Affichage selon le rôle
          if (Utilisateur.role.toLowerCase() == "acheteur")
            Acheteur(
              documentsAchetes: nbLivresAchetes,
              userId: Utilisateur.id,
              deviceType: Utilisateur.deviceType,
            )
          else
            Vendeur(
              vendeurId: Utilisateur.id,
              userId: Utilisateur.id,
              deviceType: Utilisateur.deviceType,
              repository: widget.repository,
            ),
        ],
      ),
    );
  }
}