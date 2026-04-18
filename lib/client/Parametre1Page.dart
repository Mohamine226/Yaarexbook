import 'package:daaga/client/PageApropos.dart';
import 'package:daaga/widget/AidePage.dart';
import 'package:daaga/widget/ChangePasswordPage.dart';
import 'package:daaga/widget/MiseAJourPage.dart';
import 'package:flutter/material.dart';
import 'package:daaga/widget/Utilisateur.dart';

class Parametre1Page extends StatefulWidget {
  const Parametre1Page({Key? key}) : super(key: key);

  @override
  State<Parametre1Page> createState() => _Parametre1PageState();
}

class _Parametre1PageState extends State<Parametre1Page> {
  Map<String, String> infos = {
    "Nom": Utilisateur.nom,
    "Prénom": Utilisateur.prenom,
    "Pays": Utilisateur.pays,
    "Email": Utilisateur.email,
    "Téléphone": Utilisateur.telephone,
    "Travail": Utilisateur.travail,
  };

  final Map<String, IconData> icones = {
    "Nom": Icons.person,
    "Prénom": Icons.person_outline,
    "Pays": Icons.location_city,
    "Email": Icons.email,
    "Téléphone": Icons.phone,
    "Travail": Icons.work,
  };

  bool notificationsEnabled = true;

  final List<String> langues = ["Français", "Anglais"];
  String langueChoisie = "Français";

  void _editInfo(String key) async {
    final TextEditingController controller =
    TextEditingController(text: infos[key]);

    final nouvelleValeur = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Modifier $key"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: "Entrez votre $key",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );

    if (nouvelleValeur != null && nouvelleValeur.isNotEmpty) {
      setState(() {
        infos[key] = nouvelleValeur;

        // 🔹 Mettre à jour aussi l'objet Utilisateur
        switch (key) {
          case "Pays":
            Utilisateur.pays = nouvelleValeur;
            break;
          case "Téléphone":
            Utilisateur.telephone = nouvelleValeur;
            break;
          case "Email":
            Utilisateur.email = nouvelleValeur;
            break;
          case "Travail":
            Utilisateur.travail = nouvelleValeur;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paramètres"),
        backgroundColor: Colors.white54,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context); // ✅ retour simple vers la page précédente
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔹 Compte
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_circle, color: Colors.black54),
                    SizedBox(width: 8),
                    Text(
                      "Compte",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1, color: Colors.black12),
                ...infos.entries.map((entry) {
                  final key = entry.key;
                  final value = entry.value;
                  final bool isLocked = key == "Nom" || key == "Prénom";

                  return ListTile(
                    leading: Icon(icones[key], color: Colors.black54),
                    title: Text(key,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(value.isNotEmpty ? value : "Non renseigné"),
                    trailing: isLocked
                        ? const Icon(Icons.lock, color: Colors.grey)
                        : null,
                  );
                }).toList(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 🔹 Sécurité
          ListTile(
            leading: const Icon(Icons.lock, color: Colors.black54),
            title: const Text("Sécurité"),
            subtitle: const Text("Changer mot de passe, activer 2FA"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangePasswordPage(
                    userId: Utilisateur.id.toString(),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // 🔹 Langue
          ListTile(
            leading: const Icon(Icons.language, color: Colors.black54),
            title: const Text("Langue"),
            subtitle: DropdownButton<String>(
              value: langueChoisie,
              items: langues.map((langue) {
                return DropdownMenuItem(
                  value: langue,
                  child: Text(langue),
                );
              }).toList(),
              onChanged: (nouvelleLangue) {
                setState(() {
                  langueChoisie = nouvelleLangue!;
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // 🔹 Aide
          ListTile(
            leading: const Icon(Icons.help, color: Colors.black54),
            title: const Text("Aide"),
            subtitle: const Text("Envoyer un feedback ou consulter l'aide"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AidePage()),
              );
            },
          ),

          const SizedBox(height: 16),

          // 🔹 Mises à jour
          ListTile(
            leading: const Icon(Icons.system_update, color: Colors.black54),
            title: const Text("Mises à jour"),
            subtitle: const Text("Vérifier les mises à jour disponibles"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MisesAJourPage()),
              );
            },
          ),

          const SizedBox(height: 16),

          // 🔹 À propos
          ListTile(
            leading: const Icon(Icons.info, color: Colors.black54),
            title: const Text("À propos"),
            subtitle: const Text("Informations sur l'application MyEbook"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PageAPropos()),
              );
            },
          ),
        ],
      ),
    );
  }
}