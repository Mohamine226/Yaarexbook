import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FileService {
  static const _secureStorage = FlutterSecureStorage();
  static const _keyName = 'file_encryption_key';

  static Future<enc.Key> _getOrCreateKey() async {
    String? storedKey = await _secureStorage.read(key: _keyName);
    if (storedKey == null) {
      final key = enc.Key.fromSecureRandom(32);
      await _secureStorage.write(
        key: _keyName,
        value: base64Encode(key.bytes),
      );
      return key;
    }
    return enc.Key(base64Decode(storedKey));
  }

  static Future<Directory> _baseDir() async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(join(dir.path, 'files'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  static Future<String> downloadEncryptAndSaveFile(String url, String fileName) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception("Téléchargement échoué : $url");
    }

    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));

    final encrypted = encrypter.encryptBytes(response.bodyBytes, iv: iv);

    final dir = await _baseDir();
    final file = File(join(dir.path, fileName));

    await file.writeAsBytes(iv.bytes + encrypted.bytes, flush: true);
    return file.path;
  }

  static Future<Uint8List> decryptFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    if (bytes.length < 17) throw Exception("Fichier chiffré invalide");

    final iv = enc.IV(bytes.sublist(0, 16));
    final encryptedBytes = bytes.sublist(16);

    final key = await _getOrCreateKey();
    final encrypter = enc.Encrypter(enc.AES(key));

    final decrypted = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  static Future<Map<String, String?>> downloadAssetsForDoc(int docId, String? pdfUrl, String? imageUrl) async {
    String? pdfPath;
    String? imagePath;
    final dir = await _baseDir();

    if (pdfUrl != null && pdfUrl.isNotEmpty) {
      pdfPath = await downloadEncryptAndSaveFile(pdfUrl, "livre_$docId.enc");
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imagePath = await downloadEncryptAndSaveFile(imageUrl, "image_$docId.enc");
    }

    return {"pdfPath": pdfPath, "imagePath": imagePath};
  }

  static Future<String?> downloadAndSaveImage(
      int docId,
      String imageUrl, {
        String prefix = "image",
      }) async {
    if (imageUrl.isEmpty) return null;

    try {
      final dir = await _baseDir();
      final uniqueName = "${prefix}_${docId}_${DateTime.now().millisecondsSinceEpoch}.enc";
      final file = File(join(dir.path, uniqueName));

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception("Téléchargement échoué pour l'image : $imageUrl");
      }

      final key = await _getOrCreateKey();
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key));

      final encrypted = encrypter.encryptBytes(response.bodyBytes, iv: iv);

      await file.writeAsBytes(iv.bytes + encrypted.bytes, flush: true);

      return file.path;
    } catch (e) {
      print("Erreur downloadAndSaveImage($docId): $e");
      return null;
    }
  }

  static Future<Uint8List?> decryptImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();

      // 🔹 Si fichier non chiffré (ex: PNG/JPG brut)
      if (!path.endsWith(".enc")) {
        return bytes; // retourne directement l'image brute
      }

      // 🔹 Fichier chiffré
      if (bytes.length < 17) throw Exception("Fichier chiffré invalide");

      final iv = enc.IV(bytes.sublist(0, 16));
      final encryptedBytes = bytes.sublist(16);

      final key = await _getOrCreateKey();
      final encrypter = enc.Encrypter(enc.AES(key));

      final decrypted = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      print("Erreur decryptImage($path): $e");
      return null;
    }
  }
}