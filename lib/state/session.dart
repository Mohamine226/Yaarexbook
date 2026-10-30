import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../app_config.dart';
import '../models/models.dart';

enum SessionStatus { loading, loggedOut, loggedIn }

/// État de connexion de l'application. Chaque appareil a sa propre session
/// côté serveur : on peut être connecté au même compte sur plusieurs appareils.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userKey = 'cached_user';
  static const _deviceKey = 'device_id';

  SessionStatus status = SessionStatus.loading;
  User? user;

  User get me => user!;
  bool get isAdmin => user?.isAdmin ?? false;

  /// Au démarrage : retrouve le jeton, puis vérifie qu'il est toujours valable.
  Future<void> init() async {
    await AppConfig.load();
    ApiClient.onUnauthorized = _expired;

    final token = await _storage.read(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_userKey);
    if (token == null || cached == null) {
      await _clear();
      return;
    }

    ApiClient.token = token;
    user = User.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    status = SessionStatus.loggedIn;
    notifyListeners();

    try {
      final fresh = await Api.me();
      await _saveUser(fresh);
    } on ApiException catch (e) {
      // 401 : déjà géré par _expired. Hors ligne : on reste connecté avec le profil en cache.
      if (e.status == 401) return;
    }
  }

  Future<void> login(String identifier, String password) async {
    final res = await Api.login(
      identifier: identifier.trim(),
      password: password,
      deviceId: await _deviceId(),
      deviceName: _deviceName(),
    );
    await _storage.write(key: _tokenKey, value: res.token);
    ApiClient.token = res.token;
    await _saveUser(res.user);
    status = SessionStatus.loggedIn;
    notifyListeners();
  }

  /// Déconnecte cet appareil uniquement (les autres restent connectés).
  Future<void> logout() async {
    try {
      await Api.logout();
    } catch (_) {
      // Hors ligne : on se déconnecte quand même localement.
    }
    await _clear();
  }

  Future<void> refreshUser() async {
    try {
      await _saveUser(await Api.me());
    } on ApiException catch (_) {}
  }

  Future<void> setUser(User u) => _saveUser(u);

  /// Après suppression du compte : plus rien à appeler côté serveur.
  Future<void> forget() => _clear();

  Future<void> _saveUser(User u) async {
    user = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userKey,
      jsonEncode({
        'id': u.id,
        'nom': u.nom,
        'prenom': u.prenom,
        'email': u.email,
        'telephone': u.telephone,
        'pays': u.pays,
        'profession': u.profession,
        'role': u.role,
      }),
    );
    notifyListeners();
  }

  void _expired() {
    if (status == SessionStatus.loggedIn) {
      _clear();
    }
  }

  Future<void> _clear() async {
    ApiClient.token = null;
    user = null;
    await _storage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    status = SessionStatus.loggedOut;
    notifyListeners();
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceKey);
    if (id == null) {
      final rnd = Random.secure();
      id = List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(_deviceKey, id);
    }
    return id;
  }

  String _deviceName() {
    if (kIsWeb) return 'Navigateur web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Téléphone Android';
      case TargetPlatform.iOS:
        return 'iPhone / iPad';
      case TargetPlatform.windows:
        return 'PC Windows';
      case TargetPlatform.macOS:
        return 'Mac';
      case TargetPlatform.linux:
        return 'PC Linux';
      default:
        return 'Appareil';
    }
  }
}