import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  static const _dbName = 'daaga.db';
  static const _dbVersion = 2;

  static Future<Database> initDB() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dbPath = await getDatabasesPath();
      return _open(join(dbPath, _dbName));
    } else {
      // Desktop (Windows / Linux / Mac)
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final dbPath = await databaseFactory.getDatabasesPath();
      return databaseFactory.openDatabase(
        join(dbPath, _dbName),
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }
  }

  static Future<Database> _open(String path) async {
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE documents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      description TEXT,
      domain TEXT,
      language TEXT,
      categorie TEXT,

      imagePath TEXT,
      pdfPath TEXT,
      textPath TEXT,

      price REAL,
      achats INTEGER DEFAULT 0,

      nom TEXT,
      prenom TEXT,
      numero TEXT,
      mail TEXT,
      profession TEXT,
      pays TEXT,

      vendeurId INTEGER,
      userId INTEGER,

      datePublication TEXT
    );
  ''');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await _safeAddColumn(db, "documents", "userId", "INTEGER");
      await _safeAddColumn(db, "documents", "achats", "INTEGER DEFAULT 0");
    }
  }

  static Future<void> _safeAddColumn(
      Database db, String table, String column, String type) async {
    final result = await db.rawQuery("PRAGMA table_info($table)");
    final exists = result.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute("ALTER TABLE $table ADD COLUMN $column $type");
    }
  }
}