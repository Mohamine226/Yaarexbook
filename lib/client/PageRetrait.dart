import 'package:flutter/material.dart';

class PageRetrait extends StatefulWidget {
  final double solde; // 🔹 solde transmis depuis Vendeur

  const PageRetrait({super.key, required this.solde});

  @override
  State<PageRetrait> createState() => _PageRetraitState();
}

class _PageRetraitState extends State<PageRetrait> {
  late double solde; // 🔹 solde actuel

  final List<String> modes = [
    "Orange Money",
    "Moov Money",
    "Banque",
    "PayPal",
    "Western Union",
  ];

  @override
  void initState() {
    super.initState();
    solde = widget.solde; // ✅ initialisation avec le solde reçu
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Page de Retrait"),
        backgroundColor: Colors.white30,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context); // ✅ retour simple
          },
        ),
      ),
      body: Column(
        children: [
          // 🔹 Solde en haut (cercle)
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.orange.shade100,
            child: Column(
              children: [
                const Text(
                  "Solde disponible",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                CircleAvatar(
                  radius: 100, // taille du cercle
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    "${solde.toStringAsFixed(2)} FCFA",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(),

          // 🔹 Modes de retrait en bas (scrollables)
          Expanded(
            child: ListView.builder(
              itemCount: modes.length,
              itemBuilder: (context, index) {
                final mode = modes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                    title: Text(mode),
                    trailing: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Retrait via $mode pas encore activé")),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text("Retirer"),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}