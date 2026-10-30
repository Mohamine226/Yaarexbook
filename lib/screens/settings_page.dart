import 'package:flutter/material.dart';

import '../api/api.dart';
import '../app_config.dart';
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

  void _go(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        final me = Session.instance.me;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(title: const Text('Paramètres')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            children: [
              // Carte de profil
              Card(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _go(context, const EditProfilePage()),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Avatar(me.fullName, radius: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(me.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(me.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600)),
                            if (me.isAdmin) ...[
                              const SizedBox(height: 6),
                              const _Badge('Administrateur'),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade500),
                    ]),
                  ),
                ),
              ),

              const _SectionTitle('Compte'),
              _Group(children: [
                _Tile(
                  icon: Icons.person_outline,
                  color: Colors.blue,
                  title: 'Modifier mon profil',
                  subtitle: 'Nom, téléphone, pays, profession',
                  onTap: () => _go(context, const EditProfilePage()),
                ),
                _Tile(
                  icon: Icons.lock_outline,
                  color: Colors.orange,
                  title: 'Mot de passe',
                  subtitle: 'Changer mon mot de passe',
                  onTap: () => _go(context, const ChangePasswordPage()),
                ),
              ]),

              const _SectionTitle('Sécurité'),
              _Group(children: [
                _Tile(
                  icon: Icons.devices,
                  color: Colors.green,
                  title: 'Appareils connectés',
                  subtitle: 'Voir et déconnecter les appareils',
                  onTap: () => _go(context, const DevicesPage()),
                ),
              ]),

              if (Session.instance.isAdmin) ...[
                const _SectionTitle('Administration'),
                _Group(children: [
                  _Tile(
                    icon: Icons.admin_panel_settings_outlined,
                    color: Colors.purple,
                    title: 'Espace administrateur',
                    subtitle: 'Statistiques, membres, modération',
                    onTap: () => _go(context, const AdminPage()),
                  ),
                ]),
              ],

              const _SectionTitle('À propos'),
              _Group(children: [
                _Tile(
                  icon: Icons.dns_outlined,
                  color: Colors.teal,
                  title: 'Serveur',
                  subtitle: AppConfig.baseUrl,
                  showChevron: false,
                ),
                const _Tile(
                  icon: Icons.info_outline,
                  color: Colors.blueGrey,
                  title: 'Yaarexbook',
                  subtitle: 'Version 1.0.0',
                  showChevron: false,
                ),
              ]),

              const SizedBox(height: 20),
              _Group(children: [
                _Tile(
                  icon: Icons.logout,
                  color: Colors.grey.shade700,
                  title: 'Se déconnecter',
                  onTap: () => _logout(context),
                  showChevron: false,
                ),
              ]),
              const SizedBox(height: 12),
              _Group(children: [
                _Tile(
                  icon: Icons.delete_forever,
                  color: Colors.red,
                  title: 'Supprimer mon compte',
                  danger: true,
                  onTap: () => _deleteAccount(context),
                  showChevron: false,
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.grey.shade600),
    ),
  );
}

/// Un bloc arrondi qui regroupe plusieurs lignes, séparées par un trait fin.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1, indent: 68));
      rows.add(children[i]);
    }
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final bool showChevron;

  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: danger ? Colors.red : null),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: (onTap != null && showChevron) ? Icon(Icons.chevron_right, color: Colors.grey.shade500) : null,
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
    );
  }
}