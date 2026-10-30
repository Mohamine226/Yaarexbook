import 'package:flutter/material.dart';

import '../api/api.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Étape 1 : demander un code. Étape 2 : saisir le code et le nouveau mot de passe.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _code = TextEditingController();
  final _pw = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    _code.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (requiredField(_id.text) != null) {
      showMsg(context, 'Saisissez votre email ou téléphone.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.forgotPassword(_id.text.trim());
      if (mounted) {
        setState(() => _codeSent = true);
        showMsg(context, 'Si le compte existe, un code a été envoyé.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.resetPassword(_id.text.trim(), _code.text.trim(), _pw.text);
      if (mounted) {
        showMsg(context, 'Mot de passe modifié : connectez-vous.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _codeSent
                    ? 'Saisissez le code reçu (valable 15 minutes) et votre nouveau mot de passe.'
                    : 'Nous vous enverrons un code pour choisir un nouveau mot de passe.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _id,
                enabled: !_codeSent,
                decoration: const InputDecoration(labelText: 'Email ou téléphone'),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Code à 6 chiffres'),
                  validator: (v) => requiredField(v, 'Le code'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pw,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                  validator: (v) => (v == null || v.length < 8) ? '8 caractères minimum' : null,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_codeSent ? 'Changer le mot de passe' : 'Envoyer le code'),
              ),
              if (_codeSent)
                TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Renvoyer un code')),
            ],
          ),
        ),
      ),
    );
  }
}
