import 'package:daaga/client/PdfData.dart';

class RecentPdf {
  final String fileName;   // Nom affiché
  final String openedAt;   // Date/heure d'ouverture
  final String path;       // Chemin du PDF (local ou URL)

  // 🔹 Nouveaux champs
  final bool isLocal;      // true = fichier local, false = document acheté
  final PdfData? data;     // données du document acheté (si non local)

  RecentPdf({
    required this.fileName,
    required this.openedAt,
    required this.path,
    this.isLocal = true,   // par défaut considéré comme local
    this.data,             // null si local
  });

  // 🔹 Pour sauvegarde en JSON / Hive
  Map<String, dynamic> toJson() {
    return {
      "fileName": fileName,
      "openedAt": openedAt,
      "path": path,
      "isLocal": isLocal,
      "data": data?.toJson(), // ✅ sérialiser PdfData si dispo
    };
  }

  // 🔹 Pour lecture depuis JSON / Hive
  factory RecentPdf.fromJson(Map<String, dynamic> json) {
    return RecentPdf(
      fileName: json["fileName"],
      openedAt: json["openedAt"],
      path: json["path"],
      isLocal: json["isLocal"] ?? true,
      data: json["data"] != null
          ? PdfData.fromJson(Map<String, dynamic>.from(json["data"]))
          : null, // ✅ reconstruire PdfData si sauvegardé
    );
  }

  // 🔹 Getter pratique pour afficher un titre
  String get title => data?.title ?? fileName;
}