import 'package:flutter/material.dart';

import '../api/api.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'verify_register_page.dart';

/// Inscription en 2 étapes, puis confirmation de l'email par code.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form1 = GlobalKey<FormState>();
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _tel = TextEditingController();
  final _pays = TextEditingController();
  final _profession = TextEditingController();

  int _step = 0;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    for (final c in [_prenom, _nom, _email, _pw, _tel, _pays, _profession]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_form1.currentState!.validate()) setState(() => _step = 1);
  }

  Future<void> _createAccount() async {
    setState(() => _busy = true);
    try {
      // Envoie le code par email (échoue si l'email a déjà un compte).
      await Api.sendRegisterCode(_email.text.trim());
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyRegisterPage(
            nom: _nom.text.trim(),
            prenom: _prenom.text.trim(),
            email: _email.text.trim(),
            password: _pw.text,
            telephone: _tel.text.trim(),
            pays: _pays.text.trim(),
            profession: _profession.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? type, String? Function(String?)? validator, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(labelText: optional ? '$label (facultatif)' : label),
        validator: validator,
      ),
    );
  }

  Widget _step1() {
    return Form(
      key: _form1,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Inscris-toi et rejoins Yaarexbook',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('Étape 1 sur 2', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 22),
          _field(_prenom, 'Prénom', validator: (v) => requiredField(v, 'Le prénom')),
          _field(_nom, 'Nom', validator: (v) => requiredField(v, 'Le nom')),
          _field(_email, 'Email', type: TextInputType.emailAddress, validator: (v) {
            if (v == null || !v.contains('@') || !v.contains('.')) return 'Email invalide';
            return null;
          }),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextFormField(
              controller: _pw,
              obscureText: _hide,
              decoration: InputDecoration(
                labelText: 'Mot de passe (8 caractères minimum)',
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              validator: (v) => (v == null || v.length < 8) ? '8 caractères minimum' : null,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _next, child: const Text('Continuer')),
        ],
      ),
    );
  }

  Widget _step2() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Parle-nous un peu de toi',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text('Étape 2 sur 2 · tout est facultatif', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 22),
        _field(_tel, 'Téléphone', type: TextInputType.phone, optional: true),
        _field(_pays, 'Pays', optional: true),
        _field(_profession, 'Profession', optional: true),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _createAccount,
          child: _busy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Créer mon compte'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 0); // retour à l'étape 1
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inscription'),
          leading: BackButton(
            onPressed: () => _step == 1 ? setState(() => _step = 0) : Navigator.pop(context),
          ),
        ),
        body: SafeArea(child: _step == 0 ? _step1() : _step2()),
      ),
    );
  }
}