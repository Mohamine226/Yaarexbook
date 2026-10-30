import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../app_config.dart';
import '../models/models.dart';

/// Un document de la bibliothèque, avec ses fichiers gardés sur l'appareil.
class LocalDoc {
  final Doc doc;
  final String? pdfPath; // fichier chiffré
  final String? coverPath;
  const LocalDoc(this.doc, this.pdfPath, this.coverPath);

  bool get hasPdf => pdfPath != null && File(pdfPath!).existsSync();
}

/// Bibliothèque personnelle : la liste est synchronisée avec le serveur, et
/// chaque PDF est conservé chiffré (AES-256) sur l'appareil pour la lecture
/// hors ligne. Chaque compte a sa propre bibliothèque locale.
class LocalLibrary {
  LocalLibrary._();
  static final LocalLibrary instance = LocalLibrary._();

  static const _secure = FlutterSecureStorage();
  static const _keyName = 'file_encryption_key';

  Database? _db;
  Directory? _dir;
  enc.Key? _key;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'yaarexbook_library.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) => db.execute('''
        CREATE TABLE library (
          user_id INTEGER NOT NULL,
          doc_id INTEGER NOT NULL,
          json TEXT NOT NULL,
          pdf_path TEXT,
          cover_path TEXT,
          position INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (user_id, doc_id)
        )
      '''),
    );
    return _db!;
  }

  Future<Directory> get _files async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    _dir = await Directory(p.join(base.path, 'library')).create(recursive: true);
    return _dir!;
  }

  Future<enc.Key> get _encKey async {
    if (_key != null) return _key!;
    var stored = await _secure.read(key: _keyName);
    if (stored == null) {
      stored = enc.Key.fromSecureRandom(32).base64;
      await _secure.write(key: _keyName, value: stored);
    }
    _key = enc.Key.fromBase64(stored);
    return _key!;
  }

  // ------------------------------------------------------------ chiffrement
  Future<Uint8List> _encrypt(List<int> data) async {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(await _encKey, mode: enc.AESMode.cbc));
    final cipher = encrypter.encryptBytes(data, iv: iv).bytes;
    return Uint8List.fromList([...iv.bytes, ...cipher]);
  }

  Future<Uint8List> _decrypt(Uint8List data) async {
    final iv = enc.IV(data.sublist(0, 16));
    final encrypter = enc.Encrypter(enc.AES(await _encKey, mode: enc.AESMode.cbc));
    return Uint8List.fromList(encrypter.decryptBytes(enc.Encrypted(data.sublist(16)), iv: iv));
  }

  // ------------------------------------------------------------ lecture locale
  Future<List<LocalDoc>> list(int userId) async {
    if (kIsWeb) return []; // pas de stockage local sur le web
    final db = await _database;
    final rows = await db.query(
      'library',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'position ASC',
    );
    return rows
        .map((r) => LocalDoc(
      Doc.fromJson(jsonDecode(r['json'] as String) as Map<String, dynamic>),
      r['pdf_path'] as String?,
      r['cover_path'] as String?,
    ))
        .toList();
  }

  Future<LocalDoc?> find(int userId, int docId) async {
    if (kIsWeb) return null;
    try {
      return await _find(userId, docId);
    } catch (_) {
      return null; // base locale indisponible : on se rabat sur le serveur
    }
  }

  Future<LocalDoc?> _find(int userId, int docId) async {
    final db = await _database;
    final rows = await db.query(
      'library',
      where: 'user_id = ? AND doc_id = ?',
      whereArgs: [userId, docId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return LocalDoc(
      Doc.fromJson(jsonDecode(r['json'] as String) as Map<String, dynamic>),
      r['pdf_path'] as String?,
      r['cover_path'] as String?,
    );
  }

  /// Contenu déchiffré du PDF gardé sur l'appareil (null s'il n'y est pas).
  Future<Uint8List?> readPdf(int userId, int docId) async {
    if (kIsWeb) return null;
    try {
      final local = await find(userId, docId);
      if (local == null || !local.hasPdf) return null;
      return await _decrypt(await File(local.pdfPath!).readAsBytes());
    } catch (_) {
      return null; // fichier illisible : on retélécharge depuis le serveur
    }
  }

  // ------------------------------------------------------------ écriture
  Future<LocalDoc> _store(int userId, Doc doc, int position, {LocalDoc? existing}) async {
    final dir = await _files;
    String? pdfPath = existing?.hasPdf == true ? existing!.pdfPath : null;
    String? coverPath = existing?.coverPath;

    pdfPath ??= await _saveEncryptedPdf(dir, userId, doc.id);

    if (coverPath == null || !File(coverPath).existsSync()) {
      coverPath = await _saveCover(dir, userId, doc);
    }

    final db = await _database;
    await db.insert(
      'library',
      {
        'user_id': userId,
        'doc_id': doc.id,
        'json': jsonEncode(_docToJson(doc)),
        'pdf_path': pdfPath,
        'cover_path': coverPath,
        'position': position,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return LocalDoc(doc, pdfPath, coverPath);
  }

  Future<String?> _saveEncryptedPdf(Directory dir, int userId, int docId) async {
    try {
      final bytes = await Api.downloadPdf(docId);
      final file = File(p.join(dir.path, 'u${userId}_d$docId.enc'));
      await file.writeAsBytes(await _encrypt(bytes), flush: true);
      return file.path;
    } on ApiException {
      return null; // sera retenté à la prochaine synchronisation
    }
  }

  Future<String?> _saveCover(Directory dir, int userId, Doc doc) async {
    try {
      final res = await http.get(Uri.parse(AppConfig.absolute(doc.couvertureUrl)));
      if (res.statusCode != 200) return null;
      final ext = p.extension(doc.couvertureUrl).isEmpty ? '.jpg' : p.extension(doc.couvertureUrl);
      final file = File(p.join(dir.path, 'u${userId}_d${doc.id}_cover$ext'));
      await file.writeAsBytes(res.bodyBytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Ajoute un document : serveur d'abord, puis copie locale.
  Future<void> add(int userId, Doc doc) async {
    await Api.addToLibrary(doc.id);
    if (kIsWeb) return;
    final count = (await list(userId)).length;
    await _store(userId, doc.copyWith(dansBibliotheque: true), -count - 1);
  }

  Future<void> remove(int userId, int docId) async {
    await Api.removeFromLibrary(docId);
    await removeLocal(userId, docId);
  }

  Future<void> removeLocal(int userId, int docId) async {
    if (kIsWeb) return;
    final existing = await find(userId, docId);
    if (existing != null) {
      for (final path in [existing.pdfPath, existing.coverPath]) {
        if (path != null) {
          final f = File(path);
          if (f.existsSync()) await f.delete();
        }
      }
    }
    final db = await _database;
    await db.delete('library', where: 'user_id = ? AND doc_id = ?', whereArgs: [userId, docId]);
  }

  /// Supprime toute la bibliothèque locale d'un compte (compte supprimé).
  Future<void> clearUser(int userId) async {
    if (kIsWeb) return;
    for (final d in await list(userId)) {
      await removeLocal(userId, d.doc.id);
    }
  }

  /// Aligne l'appareil sur le serveur : retire ce qui a été retiré ailleurs,
  /// télécharge ce qui manque. Hors ligne, renvoie simplement le contenu local.
  Future<List<LocalDoc>> sync(int userId) async {
    final List<Doc> remote;
    try {
      remote = await Api.library();
    } on ApiException {
      return list(userId);
    }

    if (kIsWeb) return remote.map((d) => LocalDoc(d, null, null)).toList();

    final local = {for (final d in await list(userId)) d.doc.id: d};
    final remoteIds = remote.map((d) => d.id).toSet();

    for (final id in local.keys.where((id) => !remoteIds.contains(id))) {
      await removeLocal(userId, id);
    }

    final result = <LocalDoc>[];
    for (var i = 0; i < remote.length; i++) {
      result.add(await _store(userId, remote[i], i, existing: local[remote[i].id]));
    }
    return result;
  }

  Map<String, dynamic> _docToJson(Doc d) => {
    'id': d.id,
    'titre': d.titre,
    'description': d.description,
    'categorie': d.categorie,
    'langue': d.langue,
    'domaine': d.domaine,
    'couverture_url': d.couvertureUrl,
    'auteur_id': d.auteurId,
    'auteur_nom': d.auteurNom,
    'nb_likes': d.nbLikes,
    'nb_commentaires': d.nbCommentaires,
    'nb_ajouts': d.nbAjouts,
    'liked': d.liked,
    'dans_bibliotheque': true,
    'is_disabled': d.isDisabled,
    'created_at': d.createdAt?.toUtc().toIso8601String(),
  };
}