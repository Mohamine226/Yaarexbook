import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HistoriquePage1 extends StatefulWidget {
  final int userId; // 🔹 identifiant de l'acheteur

  const HistoriquePage1({super.key, required this.userId});

  @override
  State<HistoriquePage1> createState() => _HistoriquePage1State();
}

class _HistoriquePage1State extends State<HistoriquePage1> {
  late Future<List<dynamic>> transactionsFuture;

  @override
  void initState() {
    super.initState();
    transactionsFuture = fetchTransactions(widget.userId);
  }

  // 🔹 Fonction pour récupérer les transactions de l'acheteur
  Future<List<dynamic>> fetchTransactions(int userId, {int skip = 0, int limit = 10}) async {
    final response = await http.get(
      Uri.parse("https://daaga-production.up.railway.app/wallets/achats/$userId?skip=$skip&limit=$limit"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur lors de la récupération des transactions");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des paiements"),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
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
                  leading: const Icon(Icons.payment, color: Colors.red),
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