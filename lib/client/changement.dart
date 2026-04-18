import 'dart:convert';
import 'dart:io';


import 'package:daaga/PageConnexion.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:daaga/widget/Utilisateur.dart';

import 'package:daaga/widget/Input.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_services.dart';


class Changement extends StatefulWidget {

  const Changement({super.key});

  @override
  State<Changement> createState() => _ChangementState();
}



class _ChangementState extends State<Changement> {
  bool isLoading = false;
  bool isChecked = false;
  final passwordController = TextEditingController();

  Future<void> _changerRoleEnVendeur() async {
    if (!isChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez cocher la case pour devenir vendeur")),
      );
      return;
    }

    if (passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez entrer votre mot de passe")),
      );
      return;
    }

    setState(() => isLoading = true);

    final response = await http.put(
      Uri.parse("https://daaga-production.up.railway.app/users/${Utilisateur.id}/change-role"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "new_role": "vendeur",
        "password": passwordController.text.trim(),
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data["status"] == "success") {

        // 🔹 Vérifier le token avant l'appel
        final tokenAvant = await ApiService.getToken();
        print("📦 Token récupéré avant logout: $tokenAvant");

        // Le type de device (mobile ou pc ou tablete)
        String deviceType;
        if (Platform.isAndroid || Platform.isIOS) {
          deviceType = "mobile";
        } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          deviceType = "pc";
        } else {
          deviceType = "unknown"; // fallback
        }

        // 🔹 Appel API logout (globale ou ciblée selon deviceType)
        final response = await ApiService.logout(
          userId: Utilisateur.id,
          deviceType: deviceType, // "mobile" ou "pc"
        );
        print("✅ Réponse serveur logout: $response");
        // 🔹 Suppression des tokens et du type de device en local
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

        Utilisateur.role = "vendeur";

        // 🔹 Redirection vers la page de connexion
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PageConnexion()),
              (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vous êtes maintenant vendeur, reconnectez-vous")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Mot de passe incorrect")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Erreur serveur")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Changer de rôle")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔹 Remplace TextField par ton widget Input
            Input(
              label: "Mot de passe",
              hint: "Entrez votre mot de passe",
              controller: passwordController,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Veuillez entrer votre mot de passe";
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (value) {
                    setState(() => isChecked = value ?? false);
                  },
                ),
                const Text("Je veux devenir vendeur"),
              ],
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: isLoading ? null : _changerRoleEnVendeur,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Changer de rôle"),
            ),
          ],
        ),
      ),
    );
  }
}