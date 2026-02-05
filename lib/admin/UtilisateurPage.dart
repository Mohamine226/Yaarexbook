import 'package:daaga/admin/PageAcheteur.dart';
import 'package:daaga/admin/PageVendeur.dart';
import 'package:flutter/material.dart';

class UtilisateurPage extends StatefulWidget {
  const UtilisateurPage({super.key});

  @override
  State<UtilisateurPage> createState() => _UtilisateurPageState();
}

class _UtilisateurPageState extends State<UtilisateurPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 🔹 2 onglets
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des Utilisateurs"),
        bottom: TabBar(
          labelColor: Colors.green,
          indicatorColor: Colors.green,
          controller: _tabController,
          tabs: const [
            Tab(text: "Vendeur"),
            Tab(text: "Acheteur"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PageVendeur(),
          PageAcheteur(),
        ],
      ),
    );
  }
}

// 🔹 Page Acheteur
class Acheteur extends StatelessWidget {
  const Acheteur({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Liste des Acheteurs",
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// 🔹 Page Vendeur
class Vendeur extends StatelessWidget {
  const Vendeur({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Liste des Vendeurs",
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}