import 'package:flutter/material.dart';

import 'screens/user/home_shell.dart';
import 'screens/login/login_page.dart';
import 'state/session.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YaarexbookApp());
}

class YaarexbookApp extends StatelessWidget {
  const YaarexbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yaarexbook',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

/// Affiche l'application ou l'écran de connexion selon l'état de la session.
/// Quand la session se ferme (déconnexion, appareil révoqué…), toutes les
/// pages ouvertes sont fermées pour revenir à cette racine.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  SessionStatus? _last;

  @override
  void initState() {
    super.initState();
    Session.instance.addListener(_onChange);
    Session.instance.init();
  }

  @override
  void dispose() {
    Session.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final status = Session.instance.status;
    if (_last != null && status != _last && status != SessionStatus.loading) {
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
    }
    _last = status;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Session.instance,
      builder: (context, _) {
        switch (Session.instance.status) {
          case SessionStatus.loading:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case SessionStatus.loggedOut:
            return const LoginPage();
          case SessionStatus.loggedIn:
            return HomeShell(key: ValueKey(Session.instance.me.id));
        }
      },
    );
  }
}
