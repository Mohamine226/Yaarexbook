import 'dart:io';
import 'package:flutter/material.dart';
import 'package:daaga/widget/RecentPdf.dart';
import 'package:daaga/widget/LecteurPage.dart';
import 'package:daaga/widget/RecentManager.dart';
import 'package:intl/intl.dart'; // 🔹 pour formater la date

class Recent extends StatefulWidget {
  final List<RecentPdf> recents;

  const Recent({super.key, required this.recents});

  @override
  State<Recent> createState() => _RecentState();
}

class _RecentState extends State<Recent> {
  late List<RecentPdf> _recents;

  @override
  void initState() {
    super.initState();
    _recents = widget.recents;
    _chargerRecents();
  }

  Future<void> _chargerRecents() async {
    final data = await RecentManager.getRecents();
    setState(() {
      _recents = data;
    });
  }

  String _formatDate(String openedAt) {
    final date = DateTime.tryParse(openedAt);
    if (date == null) return openedAt;

    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (isToday) {
      final heureMinute = DateFormat('HH:mm').format(date);
      return "Ouvert aujourd'hui à $heureMinute";
    } else {
      final dateStr = DateFormat('dd/MM').format(date);
      return "Ouvert le $dateStr";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Header avec "Récents" et "Plus"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Récents",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PageRecents(),
                      ),
                    );
                  },
                  child: const Text(
                    "Plus >",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _recents.isNotEmpty
                ? Column(
              // 🔹 Afficher seulement 5 récents
              children: _recents
                  .take(5)
                  .map((pdf) => _buildRecent(context, pdf))
                  .toList(),
            )
                : const Center(
              child: Text(
                "Pas de PDF récent",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Corrigé : prend un seul RecentPdf
  Widget _buildRecent(BuildContext context, RecentPdf pdf) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Colors.red,
        child: Text("PDF", style: TextStyle(color: Colors.white, fontSize: 12)),
      ),
      title: Text(
        pdf.title, // ✅ affiche le vrai titre si dispo
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_formatDate(pdf.openedAt)),
      onTap: () async {
        final updated = RecentPdf(
          fileName: pdf.fileName,
          openedAt: DateTime.now().toString(),
          path: pdf.path,
          isLocal: pdf.isLocal,
          data: pdf.data,
        );
        await RecentManager.addRecent(updated);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LecteurPage(
              path: pdf.path,
              isLocalDocument: pdf.isLocal,
              pdfData: pdf.data,
              title: pdf.title,
            ),
          ),
        );
      },
    );
  }
}

// 🔹 Nouvelle page pour afficher tous les récents
class PageRecents extends StatefulWidget {
  const PageRecents({super.key});

  @override
  State<PageRecents> createState() => _PageRecentsState();
}

class _PageRecentsState extends State<PageRecents> {
  List<RecentPdf> recents = [];

  @override
  void initState() {
    super.initState();
    _chargerRecents();
  }

  Future<void> _chargerRecents() async {
    final data = await RecentManager.getRecents();
    setState(() {
      recents = data;
    });
  }

  String _formatDate(String openedAt) {
    final date = DateTime.tryParse(openedAt);
    if (date == null) return openedAt;

    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (isToday) {
      final heureMinute = DateFormat('HH:mm').format(date);
      return "Ouvert aujourd'hui à $heureMinute";
    } else {
      final dateStr = DateFormat('dd/MM').format(date);
      return "Ouvert le $dateStr";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tous les récents")),
      body: recents.isNotEmpty
          ? ListView.builder(
        itemCount: recents.length,
        itemBuilder: (context, index) {
          final pdf = recents[index];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.red,
              child: Text("PDF",
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
            title: Text(
              pdf.title, // ✅ affiche le vrai titre si dispo
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(_formatDate(pdf.openedAt)),
            onTap: () async {
              // 🔹 Mettre à jour dans les récents
              final updated = RecentPdf(
                fileName: pdf.fileName,
                openedAt: DateTime.now().toString(),
                path: pdf.path,
                isLocal: pdf.isLocal,
                data: pdf.data
              );
              await RecentManager.addRecent(updated);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LecteurPage(
                    path: pdf.path ,
                    isLocalDocument: pdf.isLocal,
                    pdfData: pdf.data,
                    title: pdf.title,
                  ),
                ),
              );
            },
          );
        },
      )
          : const Center(child: Text("Pas de PDF récent")),
    );
  }
}