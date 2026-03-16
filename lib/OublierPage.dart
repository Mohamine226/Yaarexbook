import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:daaga/PageVerification.dart';

class OublierPage extends StatefulWidget {
  const OublierPage({super.key});

  @override
  State<OublierPage> createState() => _OublierPageState();
}

class _OublierPageState extends State<OublierPage> {
  final _formKey = GlobalKey<FormState>();
  final mailController = TextEditingController();
  final newPasswordController = TextEditingController();
  bool _isChecking = false;

  @override
  void dispose() {
    mailController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkIdentifier() async {
    setState(() => _isChecking = true);

    final identifier = mailController.text.trim();

    try {
      // 🔹 Appel API pour demander un reset (forgot-password)
      final response = await http.post(
        Uri.parse("https://calm-imagination-production-5d97.up.railway.app/users/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"identifier": identifier}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        //  En dev, afficher le code dans la console
        final code = data["code"];
        print("✅ Code de réinitialisation pour $identifier : $code");

        // Aller à la page de vérification
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PageVerification(
              identifier: identifier,
              newPassword: newPasswordController.text.trim(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("L'identifiant incorrect")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de vérifier l'identifiant ❌")),
      );
    } finally {
      setState(() => _isChecking = false);
    }
  }

  void _goToVerification() {
    if (_formKey.currentState!.validate()) {
      _checkIdentifier();
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
                  "Mot de passe oublié",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Veuillez entrer votre email ou numéro et un nouveau mot de passe",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: mailController,
                        decoration: InputDecoration(
                          labelText: "Email ou numéro",
                          hintText: "+226********",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          prefixIcon: const Icon(Icons.email),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez entrer votre email ou numéro";
                          }
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                          final phoneRegex = RegExp(r'^(?:[0-9]{8}|[0-9]{10}|[0-9]{12})$');
                          if (!emailRegex.hasMatch(value.trim()) &&
                              !phoneRegex.hasMatch(value.trim())) {
                            return "Veuillez entrer un email ou un numéro valide";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 15),

                      TextFormField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Nouveau mot de passe",
                          hintText: "Entrez un nouveau mot de passe",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez entrer un nouveau mot de passe";
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
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isChecking ? null : _goToVerification,
                          child: Text(
                            _isChecking ? "Vérification..." : "Continuer",
                            style: const TextStyle(color: Colors.green),
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
      ),
    );
  }
}