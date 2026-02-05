import 'package:daaga/admin/PageEconomie.dart';
import 'package:daaga/admin/PagePublicite.dart';
import 'package:daaga/admin/UtilisateurPage.dart';
import 'package:flutter/material.dart';
import 'package:daaga/admin/StatistiquePage.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AdminHomePage(),
    );
  }
}

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      StatistiquePage(),
      PagePublicite(),
      UtilisateurPage(),
      PageEconomie(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.green,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "Statistique",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign),
            label: "Publicité",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "Utilisateur",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: "Économie",
          ),
        ],
      ),
    );
  }
}