class PdfData {
  final int? id;
  final String title;
  final int price;
  String? image;       // chemin local OU URL
  final String domain;
  final String language;
  final String description;
  String? pdfPath;     // chemin local OU URL

  final String? nom;
  final String? prenom;
  final String? numero;
  final String? mail;
  final String? profession;
  final String? pays;

  final int achats;
  final String categorie;

  final int? vendeurId;
  final DateTime? datePublication;

  final int? userId;    // 🔹 ajouté


  PdfData({
    this.id,
    required this.title,
    required this.price,
    this.image,
    required this.domain,
    required this.language,
    required this.description,
    this.achats = 0,
    this.pdfPath,
    this.nom,
    this.prenom,
    this.numero,
    this.mail,
    this.profession,
    this.pays,
    this.categorie = "",
    this.vendeurId,
    this.datePublication,
    this.userId,

  });

  // 🔹 Depuis API → JSON
  factory PdfData.fromJson(Map<String, dynamic> json) {
    return PdfData(
      id: json["id"],
      title: json["titre"] ?? "",
      price: int.tryParse(json["prix"].toString()) ?? 0,
      image: json["couverture_path"],
      domain: json["domaine"] ?? "",
      language: json["langue"] ?? "",
      description: json["description"] ?? "",
      pdfPath: json["pdf_path"],
      achats: json["achats"] ?? 0,
      nom: json["nom"],
      prenom: json["prenom"],
      numero: json["numero"],
      mail: json["mail"],
      profession: json["profession"],
      pays: json["pays"],
      categorie: json["categorie"] ?? "",
      vendeurId: json["vendeur_id"],
      userId: json["user_id"],

      datePublication: json["date_publication"] != null
          ? DateTime.tryParse(json["date_publication"].toString())
          : null,
    );
  }

  // 🔹 Pour envoi JSON (API ou Hive)
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "titre": title,
      "prix": price,
      "couverture_path": image,
      "domaine": domain,
      "langue": language,
      "description": description,
      "pdf_path": pdfPath,
      "achats": achats,
      "nom": nom,
      "prenom": prenom,
      "numero": numero,
      "mail": mail,
      "profession": profession,
      "pays": pays,
      "categorie": categorie,
      "vendeur_id": vendeurId,
      "date_publication": datePublication?.toIso8601String(),
      "user_id": userId,
    };
  }

  // 🔹 Pour SQLite → Map
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "title": title,
      "price": price,
      "imagePath": image,
      "domain": domain,
      "language": language,
      "description": description,
      "pdfPath": pdfPath,
      "achats": achats,
      "categorie": categorie,
      "vendeurId": vendeurId,
      "datePublication": datePublication?.toIso8601String(),
      "userId": userId,

    };
  }

  factory PdfData.fromMap(Map<String, dynamic> map) {
    return PdfData(
      id: map["id"],
      title: map["title"] ?? "",
      price: (map["price"] is num) ? (map["price"] as num).toInt() : 0,
      image: map["imagePath"],
      domain: map["domain"] ?? "",
      language: map["language"] ?? "",
      description: map["description"] ?? "",
      pdfPath: map["pdfPath"],
      achats: map["achats"] ?? 0,
      categorie: map["categorie"] ?? "",
      vendeurId: map["vendeurId"],
      datePublication: map["datePublication"] != null
          ? DateTime.tryParse(map["datePublication"])
          : null,
      userId: map["userId"],
    );
  }

  // 🔹 Utilitaires
  bool get isLocalPdf => pdfPath != null && !pdfPath!.startsWith("http");
  bool get isLocalImage => image != null && !image!.startsWith("http");

  String? get pdfUrl =>
      (pdfPath != null && pdfPath!.startsWith("http")) ? pdfPath : null;
  String? get imageUrl =>
      (image != null && image!.startsWith("http")) ? image : null;

  String get displayPdfPath => isLocalPdf ? pdfPath! : pdfUrl ?? "";
  String get displayImagePath => isLocalImage ? image! : imageUrl ?? "";

  // 🔹 copyWith
  PdfData copyWith({
    int? id,
    String? title,
    int? price,
    String? pdfPath,
    String? image,
    int? achats,
    int? userId,
    String? domain,
    String? language,
    String? description,
    String? nom,
    String? prenom,
    String? numero,
    String? mail,
    String? profession,
    String? pays,
    String? categorie,
    int? vendeurId,
    DateTime? datePublication,
  }) {
    return PdfData(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      pdfPath: pdfPath ?? this.pdfPath,
      image: image ?? this.image,
      achats: achats ?? this.achats,
      userId: userId ?? this.userId,
      domain: domain ?? this.domain,
      language: language ?? this.language,
      description: description ?? this.description,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      numero: numero ?? this.numero,
      mail: mail ?? this.mail,
      profession: profession ?? this.profession,
      pays: pays ?? this.pays,
      categorie: categorie ?? this.categorie,
      vendeurId: vendeurId ?? this.vendeurId,
      datePublication: datePublication ?? this.datePublication,
    );
  }
}