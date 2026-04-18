import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:daaga/client/Categorie.dart';
import 'package:daaga/client/PdfData.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../local/file_service.dart';
import '../local/document_repository.dart';

class FetchDocumentsResult {
  final List<PdfData> docs;
  final int? nextCursor;

  const FetchDocumentsResult({required this.docs, this.nextCursor});
}

class LivreManager {
  //  Définir l’URL de base pour éviter l’erreur sur $baseUrl
  static const String baseUrl = "https://daaga-production.up.railway.app/documents";

  static final Map<String, List<DomainData>> domainesParCategorie = {
    "Roman": [],
    "Éducation": [],
    "Business": [],
    "Science": [],
    "Poésie": [],
    "Histoire": [],
    "Arts": [],
    "Bibliothèque": [], // 🔹 réservé aux livres achetés
  };



  // ============================================================
// 🔹 API : Publier un document (API uniquement, pas de SQLite)
// ============================================================
  static Future<bool> publierDocument(int vendeurId, PdfData livre) async {
    final uri = Uri.parse("$baseUrl/users/$vendeurId/upload");

    var request = http.MultipartRequest("POST", uri);

    // Champs texte
    request.fields["titre"] = livre.title;
    request.fields["description"] = livre.description;
    request.fields["prix"] = livre.price.toString();
    request.fields["categorie"] = livre.categorie;
    request.fields["langue"] = livre.language;
    request.fields["domaine"] = livre.domain;

    // Fichiers
    if (livre.pdfPath != null) {
      request.files.add(await http.MultipartFile.fromPath("pdf", livre.pdfPath!));
    }
    if (livre.image != null) {
      request.files.add(await http.MultipartFile.fromPath("couverture", livre.image!));
    }

    // Envoi
    final response = await request.send();

    if (response.statusCode == 200 || response.statusCode == 201) {
      // ✅ Pas de sauvegarde SQLite ici
      // Tu peux juste recharger depuis l’API si besoin
      return true;
    } else {
      print("Erreur publication: ${response.statusCode}");
      return false;
    }
  }


// ============================================================
// 🔹 API + SQLite : Ajouter un document dans la bibliothèque
// ============================================================

  static Future<bool> ajouterDansBibliotheque(int userId, int docId) async {
    final url = Uri.parse("$baseUrl/users/$userId/bibliotheque/$docId");
    final response = await http.post(url);

    if (response.statusCode == 201 || response.statusCode == 200) {
      // Livre ajouté ou déjà présent
      return true;
    } else {
      // Tu peux aussi logger ou afficher un message selon le code
      print("Erreur: ${response.statusCode} - ${response.body}");
      return false;
    }
  }


  static Future<List<PdfData>> fetchBibliotheque(
      int userId, DocumentRepository repository) async {
    final url = Uri.parse("$baseUrl/users/$userId/bibliotheque");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final bibliotheque = <PdfData>[];

        for (var docJson in data) {
          var doc = PdfData.fromJson(docJson);

          // 🔹 Vérifier PDF
          String? pdfPath;
          if (doc.pdfPath != null && File(doc.pdfPath!).existsSync()) {
            pdfPath = doc.pdfPath;
          } else if (doc.pdfUrl != null && doc.pdfUrl!.isNotEmpty) {
            pdfPath = await FileService.downloadEncryptAndSaveFile(
              doc.pdfUrl!,
              "livre_${doc.id}.enc",
            );
          }

          // 🔹 Vérifier image
          String? imagePath;
          if (doc.image != null && File(doc.image!).existsSync()) {
            imagePath = doc.image;
          } else if (doc.imageUrl != null && doc.imageUrl!.isNotEmpty) {
            imagePath = await FileService.downloadEncryptAndSaveFile(
              doc.imageUrl!,
              "image_${doc.id}.enc",
            );
          }

          // 🔹 Mettre à jour le document avec les chemins valides
          doc = doc.copyWith(pdfPath: pdfPath, image: imagePath);

          bibliotheque.insert(0, doc);

          // 🔹 Sauvegarde dans SQLite
          await repository.saveDocument(doc);
        }

        // 🔹 Sauvegarde dans Hive
        final box = await Hive.openBox('bibliotheque_$userId');
        await box.put('livres', bibliotheque.map((d) => d.toJson()).toList());

        return bibliotheque;
      }
    } catch (e) {
      print("Erreur fetchBibliotheque: $e");
      // 🔹 Pas de connexion → lecture locale
    }

    // 🔹 Lecture hors connexion depuis Hive
    final box = await Hive.openBox('bibliotheque_$userId');
    final cached = box.get('livres');
    if (cached != null) {
      final List<dynamic> data = cached;
      return data.map((doc) => PdfData.fromJson(doc)).toList();
    }

    return [];
  }


  // ============================================================
// 🔹 Récupérer tous les documents (API uniquement, Admin)
//    ⚠️ Pas de token requis
// ============================================================
  static Future<List<PdfData>> fetchDocumentAdmin({
    String? search,
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      // 🔹 Construire l’URL avec search + pagination
      final queryParams = {
        if (search != null && search.isNotEmpty) 'search': search,
        'skip': '$skip',
        'limit': '$limit',
      };

      final uri = Uri.parse("$baseUrl/admin")
          .replace(queryParameters: queryParams);

      // 🔹 Appel API sans Authorization
      final response = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final dynamic parsed = jsonDecode(response.body);

        List<PdfData> docs;

        // ✅ Supporter deux formats possibles : liste brute ou objet {items: [...]}
        if (parsed is List<dynamic>) {
          docs = parsed.map((doc) => PdfData.fromJson(doc)).toList();
        } else if (parsed is Map<String, dynamic> && parsed['items'] != null) {
          docs = (parsed['items'] as List<dynamic>)
              .map((doc) => PdfData.fromJson(doc))
              .toList();
        } else {
          docs = [];
        }

        return docs;
      } else {
        print("Erreur API Admin: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("Exception fetchDocumentAdmin: $e");
      return [];
    }
  }

// ============================================================
// 🔹 API + SQLite : Récupérer les documents (search, cursor, limit)
//    Retourne un objet avec docs + nextCursor
// ============================================================
  static Future<FetchDocumentsResult> fetchDocuments({
    String? search,
    required DocumentRepository repository,
    bool forceRefresh = false,
    int cursor = 0,
    int limit = 20,
  }) async {
    try {
      // 🔹 Fallback SQLite si pas de refresh
      if (!forceRefresh) {
        final local = await repository.getAllDocuments(limit: limit);
        if (local.isNotEmpty) {
          return FetchDocumentsResult(docs: local, nextCursor: null);
        }
      }

      // 🔹 Construire l’URL
      final queryParams = {
        if (search != null && search.isNotEmpty) 'search': search,
        'cursor': '$cursor',
        'limit': '$limit',
      };
      final uri = Uri.parse("$baseUrl/").replace(queryParameters: queryParams);
      final response = await http.get(uri);

      print("Réponse brute API: ${response.body}");

      if (response.statusCode == 200) {
        final dynamic parsed = jsonDecode(response.body);

        List<PdfData> docs;
        int? nextCursor;

        // ✅ Deux formats possibles: {items, next_cursor} OU liste brute
        if (parsed is Map<String, dynamic>) {
          final items = (parsed['items'] as List<dynamic>? ?? []);
          docs = items.map((j) => PdfData.fromJson(j as Map<String, dynamic>)).toList();
          nextCursor = parsed['next_cursor'];
        } else if (parsed is List<dynamic>) {
          docs = parsed.map((j) => PdfData.fromJson(j as Map<String, dynamic>)).toList();
          nextCursor = null;
        } else {
          docs = [];
          nextCursor = null;
        }

        // ✅ Réinitialiser domainesParCategorie
        domainesParCategorie.forEach((key, value) => value.clear());

        // ✅ Alimenter domainesParCategorie directement
        // ✅ Alimenter domainesParCategorie directement
        for (var doc in docs) {
          final domaines = domainesParCategorie[doc.categorie];
          if (domaines != null) {
            // Vérifier si le domaine existe déjà
            final domain = domaines.firstWhere(
                  (d) => d.name == doc.domain,
              orElse: () {
                final newDomain = DomainData(doc.domain, []);
                // 👉 Insérer directement en haut si nouveau domaine
                domaines.insert(0, newDomain);
                return newDomain;
              },
            );

            // Ajouter le livre en première position
            domain.items.insert(0, doc);

            // 🔹 Remonter le domaine en haut de la liste (même si déjà existant)
            domaines.remove(domain);
            domaines.insert(0, domain);
          }
        }

        // ✅ Sauvegarde SQLite
        for (final doc in docs.take(limit)) {
          await repository.saveDocument(doc);
        }

        return FetchDocumentsResult(docs: docs.take(limit).toList(), nextCursor: nextCursor);
      } else {
        print("Erreur API: ${response.statusCode} - ${response.body}");
        return FetchDocumentsResult(docs: [], nextCursor: null);
      }
    } catch (e) {
      print("Exception fetchDocuments: $e");
      final local = await repository.getAllDocuments(limit: limit);
      return FetchDocumentsResult(docs: local, nextCursor: null);
    }
  }

  // ============================================================
// 🔹 API : Récupérer les livres publiés par un vendeur (avec pagination)
// ============================================================
  static Future<List<PdfData>> fetchDocumentsParVendeur(
      int vendeurId, {
        int skip = 0,
        int limit = 20,
      }) async {
    final url = Uri.parse("$baseUrl/users/$vendeurId?skip=$skip&limit=$limit");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((doc) => PdfData.fromJson(doc)).toList();
    }
    return [];
  }

  // 🔹 Récupérer les documents vendus par un vendeur
  static Future<List<PdfData>> fetchDocumentsVendus(int vendeurId) async {
    final response = await http.get(Uri.parse("$baseUrl/users/$vendeurId/ventes"));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PdfData.fromJson(json)).toList();
    } else {
      throw Exception("Erreur lors du chargement des documents vendus");
    }
  }

// ============================================================
// 🔹 API + SQLite : Récupérer les livres par catégorie (cursor-ready)
// ============================================================
  static Future<List<PdfData>> getLivresParCategorieAPI(
      String categorie, {
        String? search,
        required DocumentRepository repository,
        bool forceRefresh = false,
        int? cursor,         // ✅ optionnel pour enchaîner les pages
        int limit = 20,
      }) async {
    // 🔹 Vérifier SQLite si pas de refresh
    if (!forceRefresh) {
      final local = await repository.getDocumentsParCategorie(categorie, search: search);
      if (local.isNotEmpty) return local.take(limit).toList();
    }

    try {
      // 🔹 Récupérer depuis API avec curseur optionnel
      final result = await fetchDocuments(
        search: search,
        repository: repository,
        forceRefresh: true,
        cursor: cursor ?? 0,
        limit: limit,
      );

      // ✅ Filtrer par catégorie
      final filtered = result.docs
          .where((doc) => doc.categorie == categorie)
          .take(limit)
          .toList();

      // (Optionnel) Tu peux remonter result.nextCursor à l’appelant si besoin
      return filtered;
    } catch (e) {
      // 🔹 Fallback SQLite
      return await repository.getDocumentsParCategorie(categorie, search: search);
    }
  }

// ============================================================
// 🔹 API + SQLite : Récupérer les livres par domaine (cursor-ready)
// ============================================================
  static Future<List<PdfData>> getLivresParDomaineAPI(
      String categorie,
      String domaine, {
        String? search,
        required DocumentRepository repository,
        bool forceRefresh = false,
        int? cursor,         // ✅ optionnel pour enchaîner les pages
        int limit = 20,
      }) async {
    // 🔹 Vérifier SQLite si pas de refresh
    if (!forceRefresh) {
      final local = await repository.getDocumentsParDomaines(search: search);
      if (local.containsKey(domaine)) {
        return local[domaine]!.take(limit).toList();
      }
    }

    try {
      // 🔹 Récupérer depuis API avec curseur optionnel
      final result = await fetchDocuments(
        search: search,
        repository: repository,
        forceRefresh: true,
        cursor: cursor ?? 0,
        limit: limit,
      );

      // ✅ Filtrer par catégorie + domaine
      final filtered = result.docs
          .where((doc) => doc.categorie == categorie && doc.domain == domaine)
          .take(limit)
          .toList();

      // (Optionnel) Tu peux remonter result.nextCursor à l’appelant si besoin
      return filtered;
    } catch (e) {
      // 🔹 Fallback SQLite
      final local = await repository.getDocumentsParDomaines(search: search);
      return local[domaine] ?? [];
    }
  }

  // ============================================================
// 🔹 API + SQLite : Explorer les documents par domaine (cursor-ready)
// ============================================================
  static Future<List<PdfData>> explorerParDomaineAPI(
      String domaine, {
        String? search,
        required DocumentRepository repository,
        bool forceRefresh = false,
        int? cursor,        // ✅ identifiant du dernier document lu
        int limit = 20,
      }) async {
    // 🔹 Vérifier SQLite si pas de refresh
    if (!forceRefresh) {
      final local = await repository.getDocumentsParDomaines(
        search: search,
        cursor: cursor,
        limit: limit,
      );
      if (local.containsKey(domaine)) {
        return local[domaine]!.take(limit).toList();
      }
    }

    try {
      // 🔹 Récupérer depuis API avec curseur optionnel
      final result = await fetchDocuments(
        search: search,
        repository: repository,
        forceRefresh: true,
        cursor: cursor ?? 0,
        limit: limit,
      );

      // ✅ Filtrer uniquement par domaine
      final filtered = result.docs
          .where((doc) => doc.domain == domaine)
          .take(limit)
          .toList();

      return filtered;
    } catch (e) {
      // 🔹 Fallback SQLite
      final local = await repository.getDocumentsParDomaines(
        search: search,
        cursor: cursor,
        limit: limit,
      );
      return local[domaine] ?? [];
    }
  }

  // 🔹 Récupérer les 10 livres les plus populaires (API)
  static Future<List<PdfData>> fetchLivresPopulaires() async {
    final response = await http.get(Uri.parse("$baseUrl/populaires"));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PdfData.fromJson(json)).toList();
    } else {
      throw Exception("Erreur lors du chargement des livres populaires");
    }
  }


  // ============================================================
// 🔹 LOGIQUE LOCALE : Explorer par domaine
// ============================================================
  static Map<String, List<PdfData>> getExplorerParDomaines({String? search}) {
    final Map<String, List<PdfData>> result = {};

    domainesParCategorie.forEach((categorie, domaines) {
      if (categorie == "Bibliothèque") return; // on ignore la bibliothèque
      for (var d in domaines) {
        if (d.items.isNotEmpty) {
          var items = d.items;

          // 🔹 Appliquer le filtre search
          if (search != null && search.isNotEmpty) {
            items = items.where((livre) =>
            livre.title.toLowerCase().contains(search.toLowerCase()) ||
                livre.domain.toLowerCase().contains(search.toLowerCase()) ||
                livre.categorie.toLowerCase().contains(search.toLowerCase())
            ).toList();
          }

          if (items.isNotEmpty) {
            result[d.name] = List<PdfData>.from(items);
          }
        }
      }
    });
    return result;
  }

  // Desativation
  static Future<bool> desactiverDocumentAPI(int id) async {
    final response = await http.put(
      Uri.parse("https://daaga-production.up.railway.app/$id/disable"),
    );
    return response.statusCode == 200;
  }

  // 🔹 Récupérer les documents désactivés avec pagination
  static Future<List<PdfData>> fetchDocumentsDesactives({
    int skip = 0,
    int limit = 20,
  }) async {
    final queryParams = {
      'skip': '$skip',
      'limit': '$limit',
    };

    final uri = Uri.parse("$baseUrl/desactives").replace(queryParameters: queryParams);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PdfData.fromJson(json)).toList();
    } else {
      throw Exception("Erreur lors du chargement des documents désactivés");
    }
  }



  // ============================================================
  // 🔹 API : Supprimer un document
  // ============================================================
  static Future<bool> supprimerDocumentAPI(int docId) async {
    final url = Uri.parse("$baseUrl/$docId");
    final response = await http.delete(url);

    if (response.statusCode == 200 || response.statusCode == 204) {
      domainesParCategorie.forEach((categorie, domaines) {
        for (var d in domaines) {
          d.items.removeWhere((livre) => livre.id == docId); // ✅ utiliser id
        }
      });
      return true;
    }
    return false;
  }


  // 📌 Récupérer le solde d’un utilisateur via son user_id
  static Future<Map<String, dynamic>> getSolde(int userId) async {
    final response = await http.get(
      Uri.parse("https://daaga-production.up.railway.app/wallets/$userId/solde"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur lors de la récupération du solde: ${response.body}");
    }
  }

// 📌 Récupérer le nombre de ventes d’un utilisateur (vendeur) via son user_id
  static Future<Map<String, dynamic>> getNombreVentesParUser(int userId) async {
    final response = await http.get(
      Uri.parse("https://daaga-production.up.railway.app/wallets/$userId/ventes"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur lors de la récupération du nombre de vente: ${response.body}");
    }
  }
}