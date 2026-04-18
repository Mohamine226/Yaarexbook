import 'dart:convert';
import 'package:daaga/local/document_repository.dart';
import 'package:flutter/material.dart';
import 'package:daaga/widget/Utilisateur.dart';
import 'package:daaga/main.dart'; // ton MyApp
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daaga/local/database_service.dart'; //  ajoute l'import


class PageMotPasse extends StatefulWidget {
  const PageMotPasse({super.key});

  @override
  State<PageMotPasse> createState() => _PageMotPasseState();
}

class _PageMotPasseState extends State<PageMotPasse> {
  final _formKey = GlobalKey<FormState>();
  final motDePasseController = TextEditingController();
  final confirmController = TextEditingController();


  @override
  void dispose() {
    motDePasseController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (_formKey.currentState!.validate()) {
      Utilisateur.password = motDePasseController.text;

      final body = jsonEncode({
        "email": Utilisateur.email,
        "password": Utilisateur.password,
      });

      final response = await http.put(
        Uri.parse("https://daaga-production.up.railway.app/auth/set-password"),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "success") {
          final token = data["access_token"];
          if (token != null && token.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString("jwt", token);
          }

          //  Initialise la base et le repository
          final db = await DatabaseService.initDB();
          final repository = DocumentRepository(db);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MyApp(
                token: token,
                userId: Utilisateur.id,
                repository: repository, //  passe un vrai repository
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"] ?? "Erreur mise à jour mot de passe ❌")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur de connexion. Veuillez vérifier votre connexion et réessayer")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer un mot de passe")),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Définissez votre mot de passe",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Champ mot de passe
                  TextFormField(
                    controller: motDePasseController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Mot de passe",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Veuillez entrer un mot de passe";
                      }
                      if (value.length < 8) {
                        return "Le mot de passe doit contenir au moins 8 caractères";
                      }
                      final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$');
                      if (!regex.hasMatch(value)) {
                        return "Le mot de passe doit contenir majuscule, minuscule, chiffre et symbole";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // Champ confirmation
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirmer le mot de passe",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != motDePasseController.text) {
                        return "Les mots de passe ne correspondent pas";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _savePassword,
                    child: const Text(
                      "Valider",
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}