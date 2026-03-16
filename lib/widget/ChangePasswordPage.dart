import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:daaga/widget/Input.dart';

class ChangePasswordPage extends StatefulWidget {
  final String userId; // 🔹 reçoit l’ID utilisateur

  const ChangePasswordPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  bool isPasswordValid(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');
    return regex.hasMatch(password);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les mots de passe ne correspondent pas")),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
          "https://calm-imagination-production-5d97.up.railway.app/users/change-password"
              "?user_id=${widget.userId}&old_password=$oldPassword&new_password=$newPassword",
        ),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mot de passe changé avec succès")),
        );

        // 🔹 Fermer la page et revenir en arrière
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur réseau: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Changer de mot de passe")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "Consigne",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Votre mot de passe doit contenir au moins 8 caractères,\n"
                    "avec une majuscule, une minuscule, un chiffre et un symbole (!\$@%).",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black87, fontSize: 14),
              ),
              const SizedBox(height: 30),

              Center(
                child: Column(
                  children: [
                    Input(
                      controller: _oldPasswordController,
                      label: "Mot de passe actuel",
                      hint: "Entrez votre ancien mot de passe",
                      obscureText: true,
                      validator: (value) =>
                      value == null || value.isEmpty ? "Champ obligatoire" : null,
                    ),
                    const SizedBox(height: 23),

                    Input(
                      controller: _newPasswordController,
                      label: "Nouveau mot de passe",
                      hint: "Entrez un nouveau mot de passe sécurisé",
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Champ obligatoire";
                        }
                        if (!isPasswordValid(value)) {
                          return "Mot de passe trop faible";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 23),

                    Input(
                      controller: _confirmPasswordController,
                      label: "Retapez le nouveau mot de passe",
                      hint: "Confirmez votre nouveau mot de passe",
                      obscureText: true,
                      validator: (value) =>
                      value == null || value.isEmpty ? "Champ obligatoire" : null,
                    ),
                    const SizedBox(height: 30),

                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submit,
                      child: const Text(
                        "Changer le mot de passe",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}