DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String)?.toLocal();

class User {
  final int id;
  final String nom;
  final String prenom;
  final String email;
  final String? telephone;
  final String? pays;
  final String? profession;
  final String role;

  const User({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    this.telephone,
    this.pays,
    this.profession,
    this.role = 'membre',
  });

  bool get isAdmin => role == 'admin';
  String get fullName => '$prenom $nom'.trim();

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        nom: j['nom'] as String? ?? '',
        prenom: j['prenom'] as String? ?? '',
        email: j['email'] as String? ?? '',
        telephone: j['telephone'] as String?,
        pays: j['pays'] as String?,
        profession: j['profession'] as String?,
        role: j['role'] as String? ?? 'membre',
      );
}

class Person {
  final int id;
  final String nom;
  final String prenom;
  final String? pays;
  final String? profession;
  final int nbDocuments;
  final int nbAbonnes;
  final int nbAbonnements;
  final bool isFollowing;

  const Person({
    required this.id,
    required this.nom,
    required this.prenom,
    this.pays,
    this.profession,
    this.nbDocuments = 0,
    this.nbAbonnes = 0,
    this.nbAbonnements = 0,
    this.isFollowing = false,
  });

  String get fullName => '$prenom $nom'.trim();

  Person copyWith({bool? isFollowing, int? nbAbonnes}) => Person(
        id: id,
        nom: nom,
        prenom: prenom,
        pays: pays,
        profession: profession,
        nbDocuments: nbDocuments,
        nbAbonnes: nbAbonnes ?? this.nbAbonnes,
        nbAbonnements: nbAbonnements,
        isFollowing: isFollowing ?? this.isFollowing,
      );

  factory Person.fromJson(Map<String, dynamic> j) => Person(
        id: j['id'] as int,
        nom: j['nom'] as String? ?? '',
        prenom: j['prenom'] as String? ?? '',
        pays: j['pays'] as String?,
        profession: j['profession'] as String?,
        nbDocuments: j['nb_documents'] as int? ?? 0,
        nbAbonnes: j['nb_abonnes'] as int? ?? 0,
        nbAbonnements: j['nb_abonnements'] as int? ?? 0,
        isFollowing: j['is_following'] as bool? ?? false,
      );
}

class Doc {
  final int id;
  final String titre;
  final String description;
  final String categorie;
  final String langue;
  final String domaine;
  final String couvertureUrl; // chemin relatif
  final int auteurId;
  final String auteurNom;
  final int nbLikes;
  final int nbCommentaires;
  final int nbAjouts;
  final bool liked;
  final bool dansBibliotheque;
  final bool isDisabled;
  final DateTime? createdAt;

  const Doc({
    required this.id,
    required this.titre,
    this.description = '',
    required this.categorie,
    required this.langue,
    this.domaine = '',
    required this.couvertureUrl,
    required this.auteurId,
    this.auteurNom = '',
    this.nbLikes = 0,
    this.nbCommentaires = 0,
    this.nbAjouts = 0,
    this.liked = false,
    this.dansBibliotheque = false,
    this.isDisabled = false,
    this.createdAt,
  });

  Doc copyWith({
    int? nbLikes,
    int? nbCommentaires,
    bool? liked,
    bool? dansBibliotheque,
    bool? isDisabled,
  }) =>
      Doc(
        id: id,
        titre: titre,
        description: description,
        categorie: categorie,
        langue: langue,
        domaine: domaine,
        couvertureUrl: couvertureUrl,
        auteurId: auteurId,
        auteurNom: auteurNom,
        nbLikes: nbLikes ?? this.nbLikes,
        nbCommentaires: nbCommentaires ?? this.nbCommentaires,
        nbAjouts: nbAjouts,
        liked: liked ?? this.liked,
        dansBibliotheque: dansBibliotheque ?? this.dansBibliotheque,
        isDisabled: isDisabled ?? this.isDisabled,
        createdAt: createdAt,
      );

  factory Doc.fromJson(Map<String, dynamic> j) => Doc(
        id: j['id'] as int,
        titre: j['titre'] as String? ?? '',
        description: j['description'] as String? ?? '',
        categorie: j['categorie'] as String? ?? '',
        langue: j['langue'] as String? ?? '',
        domaine: j['domaine'] as String? ?? '',
        couvertureUrl: j['couverture_url'] as String? ?? '',
        auteurId: j['auteur_id'] as int,
        auteurNom: j['auteur_nom'] as String? ?? '',
        nbLikes: j['nb_likes'] as int? ?? 0,
        nbCommentaires: j['nb_commentaires'] as int? ?? 0,
        nbAjouts: j['nb_ajouts'] as int? ?? 0,
        liked: j['liked'] as bool? ?? false,
        dansBibliotheque: j['dans_bibliotheque'] as bool? ?? false,
        isDisabled: j['is_disabled'] as bool? ?? false,
        createdAt: _date(j['created_at']),
      );
}

class Comment {
  final int id;
  final int documentId;
  final int userId;
  final String auteurNom;
  final String contenu;
  final DateTime? createdAt;

  const Comment({
    required this.id,
    required this.documentId,
    required this.userId,
    required this.auteurNom,
    required this.contenu,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as int,
        documentId: j['document_id'] as int,
        userId: j['user_id'] as int,
        auteurNom: j['auteur_nom'] as String? ?? '',
        contenu: j['contenu'] as String? ?? '',
        createdAt: _date(j['created_at']),
      );
}

class Device {
  final int id;
  final String name;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final bool current;

  const Device({
    required this.id,
    required this.name,
    this.createdAt,
    this.lastSeen,
    this.current = false,
  });

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        id: j['id'] as int,
        name: j['device_name'] as String? ?? 'Appareil',
        createdAt: _date(j['created_at']),
        lastSeen: _date(j['last_seen']),
        current: j['current'] as bool? ?? false,
      );
}

class Stats {
  final Map<String, int> values;
  const Stats(this.values);

  int operator [](String k) => values[k] ?? 0;

  factory Stats.fromJson(Map<String, dynamic> j) =>
      Stats({for (final e in j.entries) e.key: (e.value as num).toInt()});
}

/// Une page de résultats + le curseur de la suivante (null = fin).
class PageResult<T> {
  final List<T> items;
  final int? nextCursor;
  const PageResult(this.items, this.nextCursor);
}
