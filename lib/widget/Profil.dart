import 'package:flutter/material.dart';

class Profil extends StatelessWidget {
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final String pays;
  final String role;

  const Profil({
    Key? key,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.pays,
    required this.role,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔹 Construire le nom complet
    final fullName = "$nom $prenom".trim();

    return ListView(
      shrinkWrap: true, // ✅ permet de s'adapter au contenu
      padding: const EdgeInsets.all(8),
      children: [
        const SizedBox(height: 20),
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.green.shade200,
          child: Text(
            fullName.isNotEmpty ? fullName[0].toUpperCase() : "D",
            style: const TextStyle(fontSize: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          fullName, // ✅ affiche nom + prénom
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        _infoRow(Icons.email, email),
        _infoRow(Icons.phone, telephone),
        _infoRow(Icons.location_on, pays),
        _infoRow(Icons.work, role),
        const Divider(),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}