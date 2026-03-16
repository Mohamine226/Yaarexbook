import 'dart:convert';
import 'package:daaga/PageConnexion.dart';
import 'package:flutter/material.dart';
import 'package:daaga/CodeConfirme.dart';
import 'package:daaga/widget/Input.dart';
import 'package:daaga/services/api_services.dart';

class InscritConfirme extends StatefulWidget {
  final String nom;
  final String prenom;
  final String email;
  final String telephone;

  const InscritConfirme({
    super.key,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
  });

  @override
  State<InscritConfirme> createState() => _InscritConfirmeState();
}

class _InscritConfirmeState extends State<InscritConfirme> {
  final _formKey = GlobalKey<FormState>();
  final paysController = TextEditingController();
  final professionController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    paysController.dispose();
    professionController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Pré-validation et envoie de code de confirmation
  Future<void> _goToVerification() async {
    if (_formKey.currentState!.validate()) {
      final body = {
        "nom": widget.nom,
        "prenom": widget.prenom,
        "email": widget.email,
        "telephone": widget.telephone,
        "pays": paysController.text,
        "profession": professionController.text,
        "password": passwordController.text,
        "role": "Lecteur",
      };

      try {
        // 🔹 Appel API /pre_register
        final result = await ApiService.register(body);

        //  Afficher le code dans la console Flutter (debug)
        print(" Code généré: ${result["code"]}");



        // 🔹 Naviguer vers CodeConfirme
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PageConnexion(),   //CodeConfirme(
             // identifier: widget.email,
             // nom: widget.nom,
             // prenom: widget.prenom,
             // telephone: widget.telephone,
             // pays: paysController.text,
             // profession: professionController.text,
             // password: passwordController.text,
             // role: "Lecteur",
            //),
          ),
        );

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de l'inscription")),
        );
      }
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
                  "Confirmation",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Input(
                        label: "Pays",
                        hint: "Entrez votre pays",
                        controller: paysController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez saisir votre pays";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      Input(
                        label: "Profession",
                        hint: "Entrez votre statut social",
                        controller: professionController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez saisir votre profession";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 15),

                      Input(
                        label: "Mot de passe",
                        hint: "Veuillez saisir un mot de passe",
                        controller: passwordController,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez saisir un mot de passe";
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

                      const SizedBox(height: 20),

                      SizedBox(
                        child: ElevatedButton(
                          onPressed: _goToVerification,
                          child: const Text(
                            "S'inscrire",
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
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