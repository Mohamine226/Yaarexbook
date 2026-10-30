import 'package:shared_preferences/shared_preferences.dart';

/// Adresse du serveur Yaarexbook, modifiable depuis l'écran de connexion.
///
/// - Émulateur Android : http://10.0.2.2:8000
/// - Téléphone sur le même Wi-Fi : http://<IP-de-votre-PC>:8000
class AppConfig {
  static const defaultBaseUrl = 'http://10.17.24.242:8000';
  static const _key = 'server_url';

  static String baseUrl = defaultBaseUrl;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_key) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    var v = url.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      v = 'http://$v';
    }
    baseUrl = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, v);
  }

  /// Transforme un chemin relatif du serveur (/covers/x.jpg) en URL complète.
  static String absolute(String path) =>
      path.startsWith('http') ? path : '$baseUrl$path';

  static const categories = [
    'Science',
    'Éducation',
    'Roman',
    'Concours',
    'Business',
    'Histoire',
    'Poésie',
    'Arts',
    'Autre',
  ];

  static const languages = ['Français', 'English', 'العربية', 'Español', 'Autre'];
}
