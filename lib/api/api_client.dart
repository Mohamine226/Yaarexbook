import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../app_config.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  const ApiException(this.status, this.message);

  @override
  String toString() => message;
}

/// Client HTTP : ajoute le jeton, décode le JSON et traduit les erreurs en
/// messages lisibles. Un 401 sur une requête authentifiée appelle [onUnauthorized]
/// (l'appareil a été déconnecté depuis un autre appareil, ou le jeton a expiré).
class ApiClient {
  static String? token;
  static void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 30);

  static Map<String, String> _headers({bool json = false}) => {
    if (token != null) 'Authorization': 'Bearer $token',
    if (json) 'Content-Type': 'application/json',
  };

  static Uri uri(String path, [Map<String, String?>? query]) {
    final q = <String, String>{
      for (final e in (query ?? {}).entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    return Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  static Future<dynamic> get(String path, {Map<String, String?>? query}) =>
      _send(() => http.get(uri(path, query), headers: _headers()));

  static Future<dynamic> post(String path, {Object? body, bool auth = true}) => _send(
        () => http.post(uri(path), headers: auth ? _headers(json: true) : {'Content-Type': 'application/json'}, body: jsonEncode(body ?? {})),
    auth: auth,
  );

  static Future<dynamic> put(String path, {Object? body}) =>
      _send(() => http.put(uri(path), headers: _headers(json: true), body: jsonEncode(body ?? {})));

  static Future<dynamic> delete(String path) =>
      _send(() => http.delete(uri(path), headers: _headers()));

  /// Envoi multipart. Les fichiers sont fournis par leur contenu (octets) :
  /// cela fonctionne sur mobile comme sur le web.
  static Future<dynamic> multipart(
      String path, {
        required Map<String, String> fields,
        required Map<String, ({List<int> bytes, String filename})> files,
      }) async {
    return _send(() async {
      final req = http.MultipartRequest('POST', uri(path));
      req.headers.addAll(_headers());
      req.fields.addAll(fields);
      for (final e in files.entries) {
        req.files.add(http.MultipartFile.fromBytes(e.key, e.value.bytes, filename: e.value.filename));
      }
      final streamed = await req.send();
      return http.Response.fromStream(streamed);
    }, timeout: const Duration(minutes: 5));
  }

  /// Télécharge un fichier (authentifié).
  static Future<List<int>> download(String path) async {
    final res = await _raw(() => http.get(uri(path), headers: _headers()), const Duration(minutes: 3));
    return res.bodyBytes;
  }

  static Future<http.Response> _raw(
      Future<http.Response> Function() call,
      Duration timeout, {
        bool auth = true,
      }) async {
    http.Response res;
    try {
      res = await call().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(0, 'Le serveur ne répond pas. Vérifiez sa connexion.');
    } on SocketException {
      throw const ApiException(0, 'Impossible de joindre le serveur. Vérifiez votre connexion et son adresse.');
    } on http.ClientException {
      throw const ApiException(0, 'Impossible de joindre le serveur. Vérifiez votre connexion et son adresse.');
    }
    if (res.statusCode == 401 && auth && token != null) {
      onUnauthorized?.call();
      throw const ApiException(401, 'Session expirée, reconnectez-vous.');
    }
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, _errorMessage(res));
    }
    return res;
  }

  static Future<dynamic> _send(
      Future<http.Response> Function() call, {
        bool auth = true,
        Duration timeout = _timeout,
      }) async {
    final res = await _raw(call, timeout, auth: auth);
    if (res.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static String _errorMessage(http.Response res) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final detail = body is Map ? body['detail'] : null;
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          return 'Données invalides : ${first['msg']}';
        }
      }
    } catch (_) {}
    if (res.statusCode == 413) return 'Fichier trop volumineux.';
    return 'Erreur ${res.statusCode}';
  }
}