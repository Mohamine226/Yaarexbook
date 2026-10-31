import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../state/session.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _prenom = TextEditingController(text: Session.instance.me.prenom);
  late final _nom = TextEditingController(text: Session.instance.me.nom);
  late final _tel = TextEditingController(text: Session.instance.me.telephone ?? '');
  late final _pays = TextEditingController(text: Session.instance.me.pays ?? '');
  late final _profession = TextEditingController(text: Session.instance.me.profession ?? '');
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_prenom, _nom, _tel, _pays, _profession]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final u = await Api.updateProfile(
        nom: _nom.text.trim(),
        prenom: _prenom.text.trim(),
        telephone: _tel.text.trim(),
        pays: _pays.text.trim(),
        profession: _profession.text.trim(),
      );
      await Session.instance.setUser(u);
      if (mounted) {
        showMsg(context, 'Profil mis à jour');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  Widget _f(TextEditingController c, String label, {bool required = false, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(labelText: label),
          validator: required ? (v) => requiredField(v, label) : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier mon profil')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _f(_prenom, 'Prénom', required: true),
              _f(_nom, 'Nom', required: true),
              _f(_tel, 'Téléphone', type: TextInputType.phone),
              _f(_pays, 'Pays'),
              _f(_profession, 'Profession'),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
