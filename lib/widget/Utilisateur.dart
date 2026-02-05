class Utilisateur {
  static int id = 0; // 🔹 identifiant unique (vient du backend)
  static String nom = "";
  static String prenom = "";
  static String pays = "";
  static String email = "";
  static String telephone = "";
  static String travail = "";
  static String password = "";
  static String role = "";
  static String deviceType = "";

  static int walletId = 0; // ✅ champ réel pour stocker l'ID du wallet

  static void reset() {
    id = 0;
    nom = "";
    prenom = "";
    pays = "";
    email = "";
    telephone = "";
    travail = "";
    password = "";
    role = "";
    deviceType = "";
    walletId = 0; // ✅ reset aussi le wallet
  }

  static Map<String, dynamic> toJson() {
    return {
      "id": id,
      "nom": nom,
      "prenom": prenom,
      "pays": pays,
      "email": email,
      "telephone": telephone,
      "travail": travail,
      "password": password,
      "role": role,
      "deviceType": deviceType,
      "walletId": walletId, // ✅ ajouté
    };
  }
}