import 'package:daaga/client/PdfData.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daaga/local/document_repository.dart'; // adapte le chemin
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:daaga/main.dart';

class FakeRepository extends DocumentRepository {
  FakeRepository._(Database db) : super(db);

  static Future<FakeRepository> create() async {
    // 🔹 Initialiser SQLite FFI pour desktop
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    return FakeRepository._(db);
  }

  @override
  Future<List<PdfData>> getBibliotheque(int userId) async => [];

  @override
  Future<List<PdfData>> getDocuments() async => [];

  @override
  Future<Map<String, List<PdfData>>> getDocumentsParDomaines({
    String? search,
    int? cursor,
    int limit = 20,
  });
}


void main() {
  late FakeRepository repository;

  setUpAll(() async {
    repository = await FakeRepository.create(); // ✅ instanciation correcte
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyApp(
          token: "fake_token",
          repository: repository, // ✅ passe l’instance créée
        ),
      ),
    );

    // Vérifie que notre compteur démarre à 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap sur l'icône '+' et déclenche un frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Vérifie que le compteur a bien incrémenté.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}