import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../client/PdfData.dart';

class DocumentRepository {
  final Database db;
  DocumentRepository(this.db);

  // -------------------------
  // INSERT / UPDATE
  // -------------------------

  /// ➕ Insérer ou mettre à jour un document
  Future<void> saveDocument(PdfData doc) async {
    await db.insert(
      'documents',
      doc.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // -------------------------
  // READ
  // -------------------------

  /// 📂 Tous les documents
  Future<List<PdfData>> getAllDocuments({int limit = 20}) async {
    final maps = await db.query(
      'documents',
      limit: limit, // 🔹 applique la limite
    );

    return maps.map((e) => PdfData.fromMap(e)).toList();
  }

  /// 📚 Bibliothèque utilisateur (documents achetés)
  Future<List<PdfData>> getBibliotheque(int userId) async {
    final maps = await db.query(
      'documents',
      where: 'userId = ? AND achats > 0',
      whereArgs: [userId],
    );
    final docs = maps.map((e) => PdfData.fromMap(e)).toList();
    return docs.reversed.toList(); // 🔹 inverse l’ordr
  }

  /// 🧑‍💼 Documents par vendeur
  Future<List<PdfData>> getDocumentsParVendeur(int vendeurId) async {
    final maps = await db.query(
      'documents',
      where: 'vendeurId = ?',
      whereArgs: [vendeurId],
    );
    return maps.map((e) => PdfData.fromMap(e)).toList();
  }

  Future<List<PdfData>> getSolde(int userId) async {
    final maps = await db.query(
      'documents',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    return maps.map((e) => PdfData.fromMap(e)).toList();
  }

  Future<List<PdfData>> getNombreVentesParUser(int userId) async {
    final maps = await db.query(
      'documents',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    return maps.map((e) => PdfData.fromMap(e)).toList();
  }

  /// ⭐ Livres populaires
  /// ⭐ Livres populaires
  Future<List<PdfData>> getLivresPopulaires({int limit = 10}) async {
    final maps = await db.query(
      'documents',
      where: 'achats > ?',
      whereArgs: [0],
      orderBy: 'achats DESC',
      limit: limit,
    );
    return maps.map((e) => PdfData.fromMap(e)).toList();
  }

    /// 🏷️ Documents groupés par domaine (cursor-ready)
  Future<Map<String, List<PdfData>>> getDocumentsParDomaines({
    String? search,
    int? cursor, // ✅ identifiant du dernier document lu
    int limit = 20,
  }) async {
    String? where;
    List<Object?>? whereArgs;

    if (search != null && search.isNotEmpty) {
      where = 'title LIKE ? OR domain LIKE ? OR categorie LIKE ?';
      final pattern = '%$search%';
      whereArgs = [pattern, pattern, pattern];
    }

    // 🔹 Si cursor est fourni, on ajoute une condition
    if (cursor != null) {
      where = (where != null ? "$where AND " : "") + "id > ?";
      whereArgs = (whereArgs ?? [])..add(cursor);
    }

    final maps = await db.query(
      'documents',
      where: where,
      whereArgs: whereArgs,
      limit: limit, // ✅ limite fixée à 20 par défaut
      orderBy: "id ASC", // important pour cursor
    );

    final Map<String, List<PdfData>> result = {};
    for (final map in maps) {
      final doc = PdfData.fromMap(map);
      final domaine = doc.domain.isNotEmpty ? doc.domain : "Autres";
      result.putIfAbsent(domaine, () => []);
      result[domaine]!.add(doc);
    }
    return result;
  }

    /// 📂 Documents par catégorie (cursor-ready)
  Future<List<PdfData>> getDocumentsParCategorie(
    String categorie, {
    String? search,
    int? cursor, // ✅ identifiant du dernier document lu
    int limit = 20,
  }) async {
    String where = 'categorie = ?';
    List<Object?> whereArgs = [categorie];

    if (search != null && search.isNotEmpty) {
      where += ' AND (title LIKE ? OR domain LIKE ? OR language LIKE ?)';
      final pattern = '%$search%';
      whereArgs.addAll([pattern, pattern, pattern]);
    }

    // 🔹 Si cursor est fourni, on ajoute une condition
    if (cursor != null) {
      where += ' AND id > ?';
      whereArgs.add(cursor);
    }

    final maps = await db.query(
      'documents',
      where: where,
      whereArgs: whereArgs,
      limit: limit, // ✅ limite fixée à 20 par défaut
      orderBy: "id ASC", // important pour cursor
    );

    return maps.map((e) => PdfData.fromMap(e)).toList();
  }

  // -------------------------
  // DELETE
  // -------------------------

  /// 🗑️ Supprimer un document + ses fichiers locaux
  Future<void> deleteDocument(PdfData doc) async {
    try {
      if (doc.isLocalPdf && doc.pdfPath != null) {
        final file = File(doc.pdfPath!);
        if (await file.exists()) await file.delete();
      }
      if (doc.isLocalImage && doc.image != null) {
        final file = File(doc.image!);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      print("Erreur suppression fichiers locaux: $e");
    }

    await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  // -------------------------
  // UPDATE ACHATS
  // -------------------------

  /// ➕ Incrémenter les achats
  Future<void> incrementAchats(int documentId) async {
    await db.rawUpdate(
      'UPDATE documents SET achats = achats + 1 WHERE id = ?',
      [documentId],
    );
  }

  /// 🔁 Associer un document à un utilisateur
  Future<void> assignUser(int documentId, int userId) async {
    await db.update(
      'documents',
      {'userId': userId},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }
}