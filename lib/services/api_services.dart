import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../client/PdfData.dart';
import 'package:uuid/uuid.dart';

class ApiService {
  static const String baseUrl = "http://10.17.104.142:8000"; // ton backend FastAPI


  // -----------------------------
  // 🔹 Récupération de livres
  // -----------------------------
  static Future<List<PdfData>> getDocuments() async {
    final response = await http.get(Uri.parse("$baseUrl/documents"));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PdfData.fromJson(json)).toList();
    } else {
      throw Exception("Erreur lors du chargement des documents");
    }
  }

  // -----------------------------
// 🔹 Gestion du token
// -----------------------------
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("jwt", token);
    print("✅ Token sauvegardé: $token"); // Vérification console
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("jwt");
    print("📦 Token récupéré: $token"); // Vérification console
    return token;
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final loggedIn = token != null && token.isNotEmpty;
    print("🔐 Utilisateur connecté ? $loggedIn"); // Vérification console
    return loggedIn;
  }

  // -----------------------------
  // 🔹 Connexion utilisateur
  // -----------------------------
  static Future<Map<String, dynamic>> login({
    required String identifier, // email ou téléphone
    required String password,
  }) async {
    final url = Uri.parse("$baseUrl/auth/login");

    try {
      // 🔹 Récupérer ou générer un device_id
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString("device_id");
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await prefs.setString("device_id", deviceId);
      }

      // 🔹 Détecter automatiquement le type d’appareil
      String deviceType;
      if (Platform.isAndroid || Platform.isIOS) {
        deviceType = "mobile";
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        deviceType = "pc";
      } else {
        deviceType = "unknown";
      }

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "identifier": identifier,
          "password": password,
          "device_id": deviceId,
          "device_type": deviceType,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["status"] == "success") {
        final token = data["access_token"] ?? "";
        if (token.isNotEmpty) {
          await saveToken(token);
        }
      }

      return data;
    } catch (e) {
      return {"status": "error", "message": "Exception: $e"};
    }
  }

  // ----------------------------- // 🔹 Déconnexion utilisateur // -----------------------------
  static Future<Map<String, dynamic>> logout({int? userId, String? deviceType}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {"status": "error", "message": "Non connecté"};
    }

    final url = Uri.parse("$baseUrl/auth/logout");

    Map<String, dynamic>? body;
    if (userId != null && deviceType != null && deviceType.isNotEmpty) {
      body = {
        "user_id": userId,
        "device_type": deviceType,
      };
      print("🔹 Déconnexion ciblée: $body");
    } else {
      print("🔹 Déconnexion globale");
    }

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: body != null ? jsonEncode(body) : null,
    );

    // 🔹 Supprimer le token local
    final prefs = await SharedPreferences.getInstance();
    print("Token avant suppression: ${prefs.getString("jwt")}");
    await prefs.remove("jwt");
    await prefs.remove("token");
    print("Token après suppression: ${prefs.getString("jwt")}");

    if (response.statusCode == 200) {
      print("✅ Réponse serveur logout: ${response.body}");
      return jsonDecode(response.body);
    } else {
      print("❌ Erreur logout: ${response.body}");
      throw Exception("Erreur logout: ${response.body}");
    }
  }

  // -----------------------------
  // 🔹 Endpoint protégé : Profil utilisateur
  // -----------------------------
  static Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {"status": "error", "message": "Non connecté"};
    }

    final response = await http.get(
      Uri.parse("$baseUrl/auth/me"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    return jsonDecode(response.body);
  }

  // -----------------------------
// 🔹 Changement de mot de passe
// -----------------------------
  static Future<Map<String, dynamic>> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse("$baseUrl/users/change-password");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "old_password": oldPassword,
          "new_password": newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"status": "success", "message": "Mot de passe changé avec succès"};
      } else {
        return {"status": "error", "message": data["detail"] ?? "Erreur inconnue"};
      }
    } catch (e) {
      return {"status": "error", "message": "Exception: $e"};
    }
  }

  // 🔹 Pré-inscription (POST /pre_register)
  static Future<Map<String, dynamic>> preRegister(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/pre_register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur pré-inscription: ${response.body}");
    }
  }
  // 🔹 Vérification du code (POST /verify)
  static Future<Map<String, dynamic>> verifyCode(String email, String code) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/verify"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "code": code}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur vérification: ${response.body}");
    }
  }

  static Future<Map<String, dynamic>> resendCode(String email) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/resend_code"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur renvoi code: ${response.body}");
    }
  }


}