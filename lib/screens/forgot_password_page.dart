import 'package:flutter/material.dart';

import '../api/api.dart';
import '../widgets/common.dart';
import 'verify_code_page.dart';

/// Une seule page : email, nouveau mot de passe, confirmation.
/// « Confirmer » envoie un code par email puis ouvre la page de vérification.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hidePw = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.forgotPassword(_email.text.trim());
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyCodePage(email: _email.text.trim(), newPassword: _pw.text),
        ),
      );
    } catch (e) {
      // Ex. « Aucun compte n'existe avec cet email »
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _busy = false);
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
                'Saisissez votre email et choisissez un nouveau mot de passe.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  if (v == null || !v.contains('@') || !v.contains('.')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pw,
                obscureText: _hidePw,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  suffixIcon: IconButton(
                    icon: Icon(_hidePw ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _hidePw = !_hidePw),
                  ),
                ),
                validator: (v) => (v == null || v.length < 8) ? '8 caractères minimum' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _hideConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmer le nouveau mot de passe',
                  suffixIcon: IconButton(
                    icon: Icon(_hideConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                  ),
                ),
                validator: (v) => v != _pw.text ? 'Les mots de passe ne correspondent pas' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirmer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}