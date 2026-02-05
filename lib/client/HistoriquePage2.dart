import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HistoriquePage2 extends StatefulWidget {
  final int userId;    // identifiant de l'utilisateur (vendeur)
  final int walletId;  // identifiant du wallet du vendeur

  const HistoriquePage2({super.key, required this.userId, required this.walletId});

  @override
  State<HistoriquePage2> createState() => _HistoriquePage2State();
}

class _HistoriquePage2State extends State<HistoriquePage2> {
  late Future<List<dynamic>> transactionsFuture;

  @override
  void initState() {
    super.initState();
    transactionsFuture = fetchTransactions(widget.userId, widget.walletId);
  }

  // 🔹 Récupérer toutes les transactions (achats + wallet)
  Future<List<dynamic>> fetchTransactions(
      int userId,
      int walletId, {
        int skip = 0,
        int limit = 10,
      }) async {
    // Appel API pour les achats
    final achatsResponse = await http.get(
      Uri.parse("http://10.17.104.142:8000/wallets/achats/$userId?skip=$skip&limit=$limit"),
    );

    // Appel API pour les transactions du wallet
    final walletResponse = await http.get(
      Uri.parse("http://10.17.104.142:8000/wallets/$walletId/retrait?skip=$skip&limit=$limit"),
    );

    if (achatsResponse.statusCode == 200 && walletResponse.statusCode == 200) {
      final achats = jsonDecode(achatsResponse.body);
      final walletTx = jsonDecode(walletResponse.body);

      // Fusionner les deux listes
      return [...achats, ...walletTx];
    } else {
      throw Exception("Erreur lors de la récupération des transactions");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des transactions"),
        backgroundColor: Colors.green,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Aucune transaction trouvée"));
          }

          // ✅ Ici tu récupères et tries
          final transactions = snapshot.data!;
          transactions.sort((a, b) {
            final dateA = DateTime.parse(a['date_transaction']);
            final dateB = DateTime.parse(b['date_transaction']);
            return dateB.compareTo(dateA); // les plus récentes d'abord
          });

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    tx["type"] == "paiement"
                        ? Icons.arrow_upward
                        : tx["type"] == "retrait"
                        ? Icons.arrow_downward
                        : Icons.attach_money,
                    color: tx["type"] == "paiement"
                        ? Colors.red
                        : tx["type"] == "retrait"
                        ? Colors.orange
                        : Colors.green,
                  ),
                  title: Text("${tx['type']} de ${tx['montant']} F"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Date : ${tx['date_transaction']}"),
                      if (tx['document_nom'] != null)
                        Text("Document : ${tx['document_nom']}"),
                      Text("Référence : ${tx['reference'] ?? 'N/A'}"),
                    ],
                  ),
                  trailing: Text(tx['status']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}