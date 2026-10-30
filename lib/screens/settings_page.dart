import 'package:flutter/material.dart';

import '../api/api.dart';
import '../state/local_library.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import 'admin/admin_page.dart';
import 'change_password_page.dart';
import 'devices_page.dart';
import 'edit_profile_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Se déconnecter ?',
      message: 'Seul cet appareil sera déconnecté. Vos documents locaux restent disponibles à la prochaine connexion.',
      action: 'Se déconnecter',
    );
    if (ok) await Session.instance.logout();
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Votre profil, vos publications, likes et commentaires seront supprimés définitivement. Saisissez votre mot de passe pour confirmer.'),
            const SizedBox(height: 12),
            TextField(controller: ctrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40), backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.isEmpty) return;
    final userId = Session.instance.me.id;
    try {
      await Api.deleteAccount(ctrl.text);
      await LocalLibrary.instance.clearUser(userId);
      await Session.instance.forget();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.me;
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          ListTile(
            leading: Avatar(me.fullName),
            title: Text(me.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(me.email),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Modifier mon profil'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Changer le mot de passe'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage())),
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Mes appareils connectés'),
            subtitle: const Text('Voir et déconnecter les appareils de ce compte'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevicesPage())),
          ),
          if (Session.instance.isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Administration'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage())),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Se déconnecter'),
            onTap: () => _logout(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Supprimer mon compte', style: TextStyle(color: Colors.red)),
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }
}
