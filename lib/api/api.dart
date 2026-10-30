import '../models/models.dart';
import 'api_client.dart';

PageResult<T> _page<T>(dynamic json, T Function(Map<String, dynamic>) parse) {
  final m = json as Map<String, dynamic>;
  final items = (m['items'] as List).map((e) => parse(e as Map<String, dynamic>)).toList();
  return PageResult<T>(items, m['next_cursor'] as int?);
}

/// Tous les appels au serveur, regroupés par domaine.
class Api {
  // ---------------------------------------------------------------- compte
  static Future<({String token, User user})> login({
    required String identifier,
    required String password,
    required String deviceId,
    required String deviceName,
  }) async {
    final j = await ApiClient.post('/auth/login', auth: false, body: {
      'identifier': identifier,
      'password': password,
      'device_id': deviceId,
      'device_name': deviceName,
    });
    return (token: j['access_token'] as String, user: User.fromJson(j['user']));
  }

  static Future<void> register({
    required String nom,
    required String prenom,
    required String email,
    required String password,
    String? telephone,
    String? pays,
    String? profession,
  }) =>
      ApiClient.post('/auth/register', auth: false, body: {
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'password': password,
        if (telephone != null && telephone.isNotEmpty) 'telephone': telephone,
        if (pays != null && pays.isNotEmpty) 'pays': pays,
        if (profession != null && profession.isNotEmpty) 'profession': profession,
      });

  static Future<void> logout() => ApiClient.post('/auth/logout');

  static Future<User> me() async => User.fromJson(await ApiClient.get('/auth/me'));

  static Future<User> updateProfile({
    required String nom,
    required String prenom,
    String? telephone,
    String? pays,
    String? profession,
  }) async =>
      User.fromJson(await ApiClient.put('/auth/me', body: {
        'nom': nom,
        'prenom': prenom,
        'telephone': telephone ?? '',
        'pays': pays ?? '',
        'profession': profession ?? '',
      }));

  static Future<void> changePassword(String oldPassword, String newPassword) =>
      ApiClient.post('/auth/change-password', body: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });

  static Future<void> deleteAccount(String password) =>
      ApiClient.post('/auth/delete-account', body: {'password': password});

  static Future<void> forgotPassword(String identifier) =>
      ApiClient.post('/auth/forgot-password', auth: false, body: {'identifier': identifier});

  static Future<void> resetPassword(String identifier, String code, String newPassword) =>
      ApiClient.post('/auth/reset-password', auth: false, body: {
        'identifier': identifier,
        'code': code,
        'new_password': newPassword,
      });

  static Future<List<Device>> devices() async =>
      (await ApiClient.get('/auth/sessions') as List).map((e) => Device.fromJson(e)).toList();

  static Future<void> revokeDevice(int id) => ApiClient.delete('/auth/sessions/$id');

  static Future<void> revokeOtherDevices() => ApiClient.delete('/auth/sessions');

  // ---------------------------------------------------------------- personnes
  static Future<Person> profile(int id) async => Person.fromJson(await ApiClient.get('/users/$id/profile'));

  static Future<void> follow(int id) => ApiClient.post('/users/$id/follow');

  static Future<void> unfollow(int id) => ApiClient.delete('/users/$id/follow');

  static Future<PageResult<Person>> searchPeople(String q, {int cursor = 0}) async => _page(
    await ApiClient.get('/users/search', query: {'q': q, 'cursor': '$cursor'}),
    Person.fromJson,
  );

  static Future<PageResult<Person>> followers(int id, {int cursor = 0}) async =>
      _page(await ApiClient.get('/users/$id/abonnes', query: {'cursor': '$cursor'}), Person.fromJson);

  static Future<PageResult<Person>> following(int id, {int cursor = 0}) async =>
      _page(await ApiClient.get('/users/$id/abonnements', query: {'cursor': '$cursor'}), Person.fromJson);

  // ---------------------------------------------------------------- documents
  static Future<PageResult<Doc>> documents({
    String? search,
    String? categorie,
    int? auteurId,
    int cursor = 0,
  }) async =>
      _page(
        await ApiClient.get('/documents', query: {
          'search': search?.trim(),
          'categorie': categorie,
          'auteur_id': auteurId?.toString(),
          'cursor': '$cursor',
        }),
        Doc.fromJson,
      );

  static Future<PageResult<Doc>> feed({int cursor = 0}) async =>
      _page(await ApiClient.get('/documents/feed', query: {'cursor': '$cursor'}), Doc.fromJson);

  static Future<PageResult<Doc>> popular({int cursor = 0}) async =>
      _page(await ApiClient.get('/documents/populaires', query: {'cursor': '$cursor'}), Doc.fromJson);

  static Future<Doc> document(int id) async => Doc.fromJson(await ApiClient.get('/documents/$id'));

  static Future<Doc> publish({
    required String titre,
    required String description,
    required String categorie,
    required String langue,
    required String domaine,
    required List<int> pdfBytes,
    required String pdfName,
    required List<int> coverBytes,
    required String coverName,
  }) async =>
      Doc.fromJson(await ApiClient.multipart(
        '/documents',
        fields: {
          'titre': titre,
          'description': description,
          'categorie': categorie,
          'langue': langue,
          'domaine': domaine,
        },
        files: {
          'pdf': (bytes: pdfBytes, filename: pdfName),
          'couverture': (bytes: coverBytes, filename: coverName),
        },
      ));

  static Future<void> deleteDocument(int id) => ApiClient.delete('/documents/$id');

  static Future<List<int>> downloadPdf(int id) => ApiClient.download('/documents/$id/fichier');

  static Future<({bool liked, int nbLikes})> like(int id) async {
    final j = await ApiClient.post('/documents/$id/like');
    return (liked: j['liked'] as bool, nbLikes: j['nb_likes'] as int);
  }

  static Future<({bool liked, int nbLikes})> unlike(int id) async {
    final j = await ApiClient.delete('/documents/$id/like');
    return (liked: j['liked'] as bool, nbLikes: j['nb_likes'] as int);
  }

  static Future<PageResult<Comment>> comments(int docId, {int cursor = 0}) async =>
      _page(await ApiClient.get('/documents/$docId/commentaires', query: {'cursor': '$cursor'}), Comment.fromJson);

  static Future<Comment> addComment(int docId, String contenu) async =>
      Comment.fromJson(await ApiClient.post('/documents/$docId/commentaires', body: {'contenu': contenu}));

  static Future<void> deleteComment(int id) => ApiClient.delete('/documents/commentaires/$id');

  static Future<List<Doc>> library() async =>
      (await ApiClient.get('/documents/bibliotheque') as List).map((e) => Doc.fromJson(e)).toList();

  static Future<void> addToLibrary(int id) => ApiClient.post('/documents/bibliotheque/$id');

  static Future<void> removeFromLibrary(int id) => ApiClient.delete('/documents/bibliotheque/$id');

  // ---------------------------------------------------------------- administration
  static Future<Stats> stats() async => Stats.fromJson(await ApiClient.get('/admin/stats'));

  static Future<PageResult<User>> adminUsers({String? search, int cursor = 0}) async =>
      _page(await ApiClient.get('/admin/users', query: {'search': search, 'cursor': '$cursor'}), User.fromJson);

  static Future<void> setRole(int userId, String role) =>
      ApiClient.put('/admin/users/$userId/role', body: {'role': role});

  static Future<void> adminDeleteUser(int id) => ApiClient.delete('/admin/users/$id');

  /// [etat] : actifs | desactives | tous
  static Future<PageResult<Doc>> adminDocuments({String etat = 'tous', String? search, int cursor = 0}) async =>
      _page(
        await ApiClient.get('/admin/documents', query: {'etat': etat, 'search': search, 'cursor': '$cursor'}),
        Doc.fromJson,
      );

  static Future<void> disableDocument(int id) => ApiClient.put('/admin/documents/$id/disable');

  static Future<void> enableDocument(int id) => ApiClient.put('/admin/documents/$id/enable');

  static Future<void> adminDeleteDocument(int id) => ApiClient.delete('/documents/$id');
}