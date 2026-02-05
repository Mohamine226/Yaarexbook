import 'dart:async';
import 'package:flutter/material.dart';
import 'package:daaga/services/api_services.dart';
import 'package:daaga/PageConnexion.dart';

class CodeConfirme extends StatefulWidget {
  final String identifier;

  // Les infos collectées lors de l'inscription
  final String nom;
  final String prenom;
  final String telephone;
  final String pays;
  final String profession;
  final String password;
  final String role;

  const CodeConfirme({
    super.key,
    required this.identifier,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.pays,
    required this.profession,
    required this.password,
    required this.role,
  });

  @override
  State<CodeConfirme> createState() => _CodeConfirmeState();
}

class _CodeConfirmeState extends State<CodeConfirme> {
  final _formKey = GlobalKey<FormState>();
  final codeController = TextEditingController();

  int _seconds = 60;
  Timer? _timer;
  bool _isResending = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        timer.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  //  Renvoi du code
  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    try {
      final result = await ApiService.resendCode(widget.identifier);
      if (!mounted) return;

      // Afficher le code dans la console Flutter (debug)
      print("🔄 Nouveau code reçu: ${result["code"]}");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Code renvoyé")),
      );
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors du renvoi du code ❌")),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  //  Vérification du code
  Future<void> _verifyCode() async {
    setState(() => _isVerifying = true);

    try {
      final enteredCode = codeController.text.trim();

      // Appel API /verify
      final result = await ApiService.verifyCode(widget.identifier, enteredCode);

      if (!mounted) return;

      if (result["status"] == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inscription validée")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PageConnexion()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result["message"] ?? "Code invalide ❌")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:
          Text("Erreur de connexion. Veuillez vérifier votre connexion et réessayer")),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _seconds == 0 && !_isResending;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.only(top: 30),
            margin: const EdgeInsets.all(30),
            child: Column(
              children: [
                const Text(
                  "Confirmation du code",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Veuillez entrer le code reçu par ${widget.identifier.contains('@') ? 'email' : 'SMS'}",
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 25),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: codeController,
                        decoration: InputDecoration(
                          labelText: "Code de confirmation",
                          hintText: "Ex: 123456",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez entrer le code";
                          }
                          if (value.trim().length < 6) {
                            return "Code trop court";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isVerifying
                              ? null
                              : () {
                            if (_formKey.currentState!.validate()) {
                              _verifyCode();
                            }
                          },
                          child: Text(
                            _isVerifying ? "Vérification..." : "Confirmer",
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Column(
                        children: [
                          Text(
                            _seconds > 0
                                ? "le code sera envoyé dans $_seconds s"
                                : "Vous pouvez demander de renvoyer le code",
                            style: TextStyle(
                              color: _seconds > 0 ? Colors.black54 : Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 8),

                          OutlinedButton.icon(
                            onPressed: canResend ? _resendCode : null,
                            icon: _isResending
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Icon(Icons.refresh),
                            label: Text(_isResending ? "Renvoi en cours..." : "Renvoyer le code"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: canResend ? Colors.green : Colors.grey,
                              side: BorderSide(
                                color: canResend ? Colors.green : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
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