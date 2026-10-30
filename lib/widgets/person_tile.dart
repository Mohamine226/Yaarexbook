import 'package:flutter/material.dart';

import '../api/api.dart';
import '../models/models.dart';
import '../screens/user_profile_page.dart';
import '../state/session.dart';
import 'common.dart';

/// Une personne dans une liste (recherche, abonnés…) avec bouton Suivre.
class PersonTile extends StatefulWidget {
  final Person person;
  const PersonTile({super.key, required this.person});

  @override
  State<PersonTile> createState() => _PersonTileState();
}

class _PersonTileState extends State<PersonTile> {
  late Person person = widget.person;
  bool _busy = false;

  bool get _isMe => Session.instance.user?.id == person.id;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (person.isFollowing) {
        await Api.unfollow(person.id);
      } else {
        await Api.follow(person.id);
      }
      setState(() => person = person.copyWith(isFollowing: !person.isFollowing));
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [person.profession, person.pays].where((s) => s != null && s.isNotEmpty).join(' · ');
    return Card(
      child: ListTile(
        leading: Avatar(person.fullName),
        title: Text(person.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: _isMe
            ? null
            : (person.isFollowing
                ? OutlinedButton(onPressed: _toggle, child: const Text('Suivi'))
                : FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                    onPressed: _toggle,
                    child: const Text('Suivre'),
                  )),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserProfilePage(userId: person.id, name: person.fullName)),
        ),
      ),
    );
  }
}
