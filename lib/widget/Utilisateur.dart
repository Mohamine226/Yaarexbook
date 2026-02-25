class Utilisateur {
  static int id = 0;
  static String nom = "";
  static String prenom = "";
  static String pays = "";
  static String email = "";
  static String telephone = "";
  static String travail = "";
  static String password = "";
  static String role = "";
  static String deviceType = "";

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
    };
  }
}