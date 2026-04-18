import 'package:daaga/client/Fichiers.dart';
import 'package:daaga/PageConnexion.dart';
import 'package:flutter/material.dart';
import 'package:daaga/client/HomePage.dart';
import 'package:daaga/client/Categorie.dart';
import 'package:daaga/client/Compte.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daaga/widget/Utilisateur.dart';

import 'local/database_service.dart';
import 'local/document_repository.dart'; //  pour recharger les infos utilisateur

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //  Initialiser Hive
  await Hive.initFlutter();
  await Hive.openBox('bibliotheque');

  //  Vérifier si un token existe déjà
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString("jwt");
  final userId = prefs.getInt("userId");
  final db = await DatabaseService.initDB();
  final repository = DocumentRepository(db);

  //  Recharger les infos utilisateur si elles existent
  if (userId != null) {
    Utilisateur.id = userId;
    Utilisateur.nom = prefs.getString("nom") ?? "";
    Utilisateur.prenom = prefs.getString("prenom") ?? "";
    Utilisateur.email = prefs.getString("email") ?? "";
    Utilisateur.telephone = prefs.getString("telephone") ?? "";
    Utilisateur.pays = prefs.getString("pays") ?? "";
    Utilisateur.travail = prefs.getString("travail") ?? "";
    Utilisateur.role = prefs.getString("role") ?? "";
  }

  runApp(
    MyApp(
      token: token,
      userId: userId,
      repository: repository,
    ),
  );
}

class MyApp extends StatefulWidget {
  final String? token;
  final int? userId;
  final DocumentRepository repository;

  const MyApp({super.key, this.token, this.userId, required this.repository});


  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;
  int? userId;
  bool isLoading = true;
  bool isLoggedIn = false;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    //  Si userId est déjà passé depuis PageConnexion ou sauvegardé
    if (widget.userId != null) {
      setState(() {
        userId = widget.userId;
        isLoggedIn = true;
        _screens = [
          HomePage(userId: userId!, repository: widget.repository),
          Categorie(userId: userId!, repository: widget.repository),
          Fichiers(repository: widget.repository), //  correction
          Compte(repository: widget.repository),   //  ajout
        ];
        isLoading = false;
      });
      return;
    }

    //  Sinon, vérifier le token auprès du backend
    if (widget.token != null && widget.token!.isNotEmpty) {
      final response = await http.get(
        Uri.parse("http://daaga-production.up.railway.app/auth/me"),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final id = data["id"] ?? data["user"]?["id"];

        if (id != null) {
          // 🔹 Sauvegarde l'userId pour persistance
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt("userId", id);

          setState(() {
            userId = id;
            isLoggedIn = true;
            _screens = [
              HomePage(userId: userId!, repository: widget.repository),
              Categorie(userId: userId!, repository: widget.repository),
              Fichiers(repository: widget.repository), // ✅ correction
              Compte(repository: widget.repository),   // ✅ ajout
            ];
            isLoading = false;
          });
        } else {
          setState(() {
            isLoggedIn = false;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoggedIn = false;
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoggedIn = false;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: isLoading
          ? Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      )
          : isLoggedIn
          ? Scaffold(
        backgroundColor: Colors.white,
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.black87,
          type: BottomNavigationBarType.fixed,
          items: List.generate(4, (index) {
            return BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == index
                    ? selectedIcons[index]
                    : unselectedIcons[index],
              ),
              label: ['Accueil', 'Catégorie', 'Fichiers', 'Profil'][index],
            );
          }),
        ),
      )
          : const PageConnexion(),
    );
  }

  final List<IconData> selectedIcons = [
    Icons.home,
    Icons.category,
    Icons.folder,
    Icons.person,
  ];

  final List<IconData> unselectedIcons = [
    Icons.home_outlined,
    Icons.category_outlined,
    Icons.folder_outlined,
    Icons.person_outline,
  ];
}