import 'package:flutter/material.dart';

import '../app_config.dart';
import '../state/session.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Session.instance.login(_id.text, _pw.text);
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _serverDialog() async {
    final ctrl = TextEditingController(text: AppConfig.baseUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adresse du serveur'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'http://192.168.1.10:8000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await AppConfig.setBaseUrl(ctrl.text);
      if (mounted) {
        setState(() {});
        showMsg(context, 'Serveur : ${AppConfig.baseUrl}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.auto_stories, size: 64, color: scheme.primary),
                    const SizedBox(height: 8),
                    Text('Yaarexbook', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: scheme.primary)),
                    const SizedBox(height: 4),
                    Text('Partagez et découvrez des documents', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _id,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(labelText: 'Email ou téléphone', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => requiredField(v, 'Ce champ'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pw,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) => requiredField(v, 'Le mot de passe'),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Se connecter'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () async {
                        final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
                        if (created == true && context.mounted) showMsg(context, 'Compte créé : connectez-vous.');
                      },
                      child: const Text('Créer un compte'),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: _serverDialog,
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: Text('Serveur : ${AppConfig.baseUrl}', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
