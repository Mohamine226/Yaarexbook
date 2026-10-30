import 'package:flutter/material.dart';

import '../api/api.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _pays = TextEditingController();
  final _profession = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_prenom, _nom, _email, _tel, _pays, _profession, _pw]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.register(
        nom: _nom.text.trim(),
        prenom: _prenom.text.trim(),
        email: _email.text.trim(),
        password: _pw.text,
        telephone: _tel.text.trim(),
        pays: _pays.text.trim(),
        profession: _profession.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, TextInputType? type, bool obscure = false, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        obscureText: obscure,
        decoration: InputDecoration(labelText: required ? label : '$label (facultatif)'),
        validator: validator ?? (required ? (v) => requiredField(v, label) : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _field(_prenom, 'Prénom', required: true),
              _field(_nom, 'Nom', required: true),
              _field(_email, 'Email', required: true, type: TextInputType.emailAddress, validator: (v) {
                if (v == null || !v.contains('@') || !v.contains('.')) return 'Email invalide';
                return null;
              }),
              _field(_tel, 'Téléphone', type: TextInputType.phone),
              _field(_pays, 'Pays'),
              _field(_profession, 'Profession'),
              _field(_pw, 'Mot de passe (8 caractères minimum)', required: true, obscure: true, validator: (v) {
                if (v == null || v.length < 8) return '8 caractères minimum';
                return null;
              }),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Créer mon compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
