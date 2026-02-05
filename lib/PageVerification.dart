import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:daaga/PageConnexion.dart';
import 'package:daaga/widget/Input.dart';

class PageVerification extends StatefulWidget {
  final String identifier;
  final String newPassword;

  const PageVerification({
    super.key,
    required this.identifier,
    required this.newPassword,
  });

  @override
  State<PageVerification> createState() => _PageVerificationState();
}

class _PageVerificationState extends State<PageVerification> {
  final _formKey = GlobalKey<FormState>();
  final codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isResending = false;
  int _seconds = 60;
  Timer? _timer;

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

  // 🔄 Renvoi du code
  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    try {
      final response = await http.post(
        Uri.parse("http://10.17.104.142:8000/users/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"identifier": widget.identifier}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("🔄 Nouveau code reçu: ${data["code"]}");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Code renvoyé")),
        );

        codeController.clear();
        _startTimer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur serveur ❌")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de renvoyer le code ❌")),
      );
    } finally {
      setState(() => _isResending = false);
    }
  }

  // 🔐 Vérification du code
  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isVerifying = true);
    final enteredCode = codeController.text.trim();

    try {
      final verifyResponse = await http.post(
        Uri.parse("http://10.17.104.142:8000/auth/verify-reset-code"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "identifier": widget.identifier,
          "code": enteredCode,
        }),
      );

      if (verifyResponse.statusCode == 200) {
        final verifyData = jsonDecode(verifyResponse.body);

        if (verifyData["status"] == "success") {
          final resetResponse = await http.put(
            Uri.parse("http://10.17.104.142:8000/auth/set-password"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "identifier": widget.identifier,
              "code": enteredCode,
              "new_password": widget.newPassword,
            }),
          );

          if (resetResponse.statusCode == 200) {
            final resetData = jsonDecode(resetResponse.body);
            if (resetData["status"] == "success") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const PageConnexion()),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(resetData["message"] ?? "Erreur lors de la mise à jour ❌")),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Erreur serveur lors de la mise à jour ❌")),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Code invalide ou expiré ❌")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur de connexion. Veuillez vérifier votre connexion et réessayer")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur de connexion. Veuillez vérifier votre connexion et réessayer")),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _seconds == 0 && !_isResending;

    return Scaffold(
      appBar: AppBar(title: const Text("Vérification du code")),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
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
                  const SizedBox(height: 20),

                  Input(
                    label: "Code de vérification",
                    hint: "Ex: 123456",
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Veuillez entrer le code";
                      }
                      if (value.length != 6) {
                        return "Le code doit contenir 6 chiffres";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyCode,
                    child: Text(
                      _isVerifying ? "Vérification..." : "Valider",
                      style: const TextStyle(color: Colors.green),
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
          ),
        ),
      ),
    );
  }
}