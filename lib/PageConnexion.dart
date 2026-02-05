import 'package:daaga/admin/Admin.dart';
import 'package:daaga/OublierPage.dart';
import 'package:daaga/PageInscription.dart';
import 'package:daaga/main.dart'; // Mon MyApp
import 'package:daaga/local/document_repository.dart';
import 'package:daaga/widget/Utilisateur.dart';
import 'package:flutter/material.dart';
import 'package:daaga/widget/Input.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'local/database_service.dart';
import 'dart:io';

class PageConnexion extends StatefulWidget {
  const PageConnexion({super.key});

  @override
  State<PageConnexion> createState() => _PageConnexionState();
}

class _PageConnexionState extends State<PageConnexion> {
  final _formKey = GlobalKey<FormState>();
  final mailController = TextEditingController();
  final motDePasseController = TextEditingController();

  // La gestion de login de connection
  Future<void> _login() async {
    // 🔹 Génère un device_id unique (ou récupère depuis SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString("device_id");
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString("device_id", deviceId);
    }

    // 🔹 Définir le type d’appareil
    String deviceType;
    if (Platform.isAndroid || Platform.isIOS) {
      deviceType = "mobile";
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      deviceType = "pc";
    } else {
      deviceType = "unknown"; // fallback
    }

    // 🔹 Vérifie auprès du backend FastAPI
    final response = await http.post(
      Uri.parse("http://10.17.104.142:8000/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "identifier": mailController.text.trim(),
        "password": motDePasseController.text.trim(),
        "device_id": deviceId,
        "device_type": deviceType,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data["status"] == "success") {
        final user = data["user"];
        final token = data["access_token"];

        if (token != null && token.isNotEmpty) {
          await prefs.setString("jwt", token);
          await prefs.setInt("userId", user["id"]);
          await prefs.setString("nom", user["nom"] ?? "");
          await prefs.setString("prenom", user["prenom"] ?? "");
          await prefs.setString("email", user["email"] ?? "");
          await prefs.setString("telephone", user["telephone"] ?? "");
          await prefs.setString("pays", user["pays"] ?? "");
          await prefs.setString("travail", user["profession"] ?? "");
          await prefs.setString("role", user["role"] ?? "");

        }

        // 🔹 Stocke les infos utilisateur
        Utilisateur.id = user["id"];
        Utilisateur.nom = user["nom"] ?? "";
        Utilisateur.prenom = user["prenom"] ?? "";
        Utilisateur.email = user["email"] ?? "";
        Utilisateur.telephone = user["telephone"] ?? "";
        Utilisateur.pays = user["pays"] ?? "";
        Utilisateur.travail = user["profession"] ?? "";
        Utilisateur.role = user["role"] ?? "";

        final db = await DatabaseService.initDB();
        final repository = DocumentRepository(db);

        // 🔹 Redirection selon le rôle
        if (Utilisateur.role == "admin") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminApp()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MyApp(
                token: token,
                userId: Utilisateur.id,
                repository: repository,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Email ou mot de passe incorrect")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur de connexion. Veuillez vérifier votre connexion et réessayer"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.only(top: 30),
            margin: const EdgeInsets.all(30),
            child: Column(
              children: [
                const Text(
                  "Connexion",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text("Bienvenue sur Daaga"),
                const SizedBox(height: 25),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Input(
                        label: "Email ou numéro",
                        hint: "Votre adresse email ou numéro",
                        controller: mailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez remplir le champ email ou numéro";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      Input(
                        label: "Mot de passe",
                        hint: "Votre mot de passe",
                        controller: motDePasseController,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez remplir le champ Mot de passe";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 300,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _login();
                            }
                          },
                          child: const Text(
                            "Se connecter",
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Pas de compte?"),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PageInscription()),
                              );
                            },
                            child: const Text(
                              "Inscrivez-vous",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const OublierPage()),
                              );
                            },
                            child: const Text(
                              "Mot de passe oublié",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}