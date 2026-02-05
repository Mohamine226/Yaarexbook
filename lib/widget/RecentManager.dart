import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:daaga/widget/RecentPdf.dart';

class RecentManager {
  static const String _key = "recent_pdfs";
  static List<RecentPdf> _recents = [];

  /// 🔹 Ajouter un fichier aux récents
  static Future<void> addRecent(RecentPdf pdf) async {
    final prefs = await SharedPreferences.getInstance();

    // Charger les récents existants
    final data = prefs.getStringList(_key) ?? [];
    _recents = data.map((s) => RecentPdf.fromJson(jsonDecode(s))).toList();

    // Supprimer si déjà présent (anti-doublon)
    _recents.removeWhere((r) => r.path == pdf.path);

    // Ajouter en haut
    _recents.insert(0, pdf);

    // Limiter à 100 récents
    if (_recents.length > 100) {
      _recents = _recents.sublist(0, 100);
    }

    // Sauvegarder dans SharedPreferences
    final newData = _recents.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, newData);
  }

  /// 🔹 Récupérer la liste des récents
  static Future<List<RecentPdf>> getRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    return data.map((s) => RecentPdf.fromJson(jsonDecode(s))).toList();
  }

  /// 🔹 Effacer tous les récents
  static Future<void> clearRecents() async {
    final prefs = await SharedPreferences.getInstance();
    _recents.clear();
    await prefs.remove(_key);
  }
}