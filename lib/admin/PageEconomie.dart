import 'package:flutter/material.dart';

class PageEconomie extends StatefulWidget {
  const PageEconomie({super.key});

  @override
  State<PageEconomie> createState() => _PageEconomieState();
}

class _PageEconomieState extends State<PageEconomie> {
  double solde = 1500.00; // 🔹 solde fictif
  final List<Map<String, dynamic>> transactions = [
    {"type": "Paiement", "montant": 200.0, "date": "2025-12-20"},
    {"type": "Réception", "montant": 500.0, "date": "2025-12-21"},
    {"type": "Retrait", "montant": 100.0, "date": "2025-12-22"},
  ];

  void _ajouterTransaction(String type, double montant) {
    setState(() {
      if (type == "Paiement" || type == "Retrait") {
        solde -= montant;
      } else {
        solde += montant;
      }
      transactions.insert(0, {
        "type": type,
        "montant": montant,
        "date": DateTime.now().toString().substring(0, 10),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Économie"),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // 🔹 Affichage du solde
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.green[100],
            child: Column(
              children: [
                const Text(
                  "Solde actuel",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "\$${solde.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 🔹 Liste des transactions
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Icon(
                      tx["type"] == "Paiement"
                          ? Icons.arrow_upward
                          : tx["type"] == "Retrait"
                          ? Icons.arrow_downward
                          : Icons.attach_money,
                      color: tx["type"] == "Paiement"
                          ? Colors.red
                          : tx["type"] == "Retrait"
                          ? Colors.orange
                          : Colors.green,
                    ),
                    title: Text("${tx['type']} de \$${tx['montant']}"),
                    subtitle: Text("Date : ${tx['date']}"),
                  ),
                );
              },
            ),
          ),

          // 🔹 Boutons d’action
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _ajouterTransaction("Paiement", 50.0),
                  icon: const Icon(Icons.payment),
                  label: const Text("Payer"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: () => _ajouterTransaction("Réception", 100.0),
                  icon: const Icon(Icons.add),
                  label: const Text("Recevoir"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: () => _ajouterTransaction("Retrait", 30.0),
                  icon: const Icon(Icons.money_off),
                  label: const Text("Retirer"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}