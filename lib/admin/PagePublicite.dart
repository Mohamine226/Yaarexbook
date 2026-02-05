import 'package:flutter/material.dart';
import 'package:daaga/admin/PageDocument.dart';
import 'package:daaga/admin/PageSuppression.dart';
import 'package:daaga/admin/PageDesactivation.dart';

class PagePublicite extends StatefulWidget {
  const PagePublicite({super.key}); // ✅ constructeur simple

  @override
  State<PagePublicite> createState() => _PagePubliciteState();
}

class _PagePubliciteState extends State<PagePublicite>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 🔹 3 onglets
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
        title: const Text("📢 Publicité"),
        bottom: TabBar(
          labelColor: Colors.green,
          controller: _tabController,
          indicatorColor: Colors.green,
          tabs: const [
            Tab(text: "Document"),
            Tab(text: "Désactivation"),
            Tab(text: "Suppression"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // 🔹 Onglet Document
          PageDocument(),

          // 🔹 Onglet Désactivation
          PageDesactivation(),

          // 🔹 Onglet Suppression
          PageSuppression(),
        ],
      ),
    );
  }
}