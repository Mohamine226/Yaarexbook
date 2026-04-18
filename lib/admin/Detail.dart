import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:daaga/client/PdfData.dart';

class Detail extends StatefulWidget {
  final PdfData data;

  const Detail({
    super.key,
    required this.data,
  });

  @override
  State<Detail> createState() => _DetailState();
}

class _DetailState extends State<Detail> {
  UserData? auteur;
  bool isLoadingAuteur = true;

  @override
  void initState() {
    super.initState();
    _fetchAuteur();
  }

  Future<void> _fetchAuteur() async {
    try {
      // 🔹 On suppose que PdfData contient vendeurId
      final vendeurId = widget.data.vendeurId;
      if (vendeurId == null) {
        setState(() => isLoadingAuteur = false);
        return;
      }

      final response = await http.get(
        Uri.parse("https://daaga-production.up.railway.app/dates/users/$vendeurId"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          auteur = UserData.fromJson(data);
          isLoadingAuteur = false;
        });
      } else {
        setState(() => isLoadingAuteur = false);
      }
    } catch (e) {
      debugPrint("Erreur API auteur: $e");
      setState(() => isLoadingAuteur = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Détail document")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Image du document
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 70.0, vertical: 8.0),
              child: SizedBox(
                height: 320,
                width: 200,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(2, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                leading: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                title: const Text("Couverture"),
                              ),
                              body: Center(
                                child: widget.data.image != null && widget.data.image!.isNotEmpty
                                    ? (widget.data.image!.startsWith("http")
                                    ? Image.network(widget.data.image!, fit: BoxFit.contain)
                                    : widget.data.image!.startsWith("assets/")
                                    ? Image.asset(widget.data.image!, fit: BoxFit.contain)
                                    : Image.file(File(widget.data.image!), fit: BoxFit.contain))
                                    : const Icon(Icons.picture_as_pdf,
                                    size: 120, color: Colors.green),
                              ),
                            ),
                          ),
                        );
                      },
                      child: widget.data.image != null && widget.data.image!.isNotEmpty
                          ? (widget.data.image!.startsWith("http")
                          ? Image.network(widget.data.image!, fit: BoxFit.cover)
                          : widget.data.image!.startsWith("assets/")
                          ? Image.asset(widget.data.image!, fit: BoxFit.cover)
                          : Image.file(File(widget.data.image!), fit: BoxFit.cover))
                          : const Center(
                        child: Icon(Icons.picture_as_pdf,
                            size: 80, color: Colors.green),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 Bloc infos document
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black26, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.data.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text("Domaine : ${widget.data.domain}", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("Langue : ${widget.data.language}", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("Prix : \$${widget.data.price.toStringAsFixed(2)}",
                      style: const TextStyle(
                          fontSize: 16, color: Colors.green, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Text(widget.data.description, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 16),
                  if (widget.data.pdfPath != null && widget.data.pdfPath!.isNotEmpty)
                    Text("Lien PDF : ${widget.data.pdfPath}",
                        style: const TextStyle(
                            fontSize: 14, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Bloc infos auteur
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black26, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoadingAuteur
                  ? const Center(child: CircularProgressIndicator())
                  : auteur == null
                  ? const Text("Auteur introuvable")
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Informations sur l'auteur",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 10),
                  Text("Nom : ${auteur!.nom}", style: const TextStyle(fontSize: 15)),
                  Text("Prénom : ${auteur!.prenom}", style: const TextStyle(fontSize: 15)),
                  Text("Email : ${auteur!.email}", style: const TextStyle(fontSize: 15)),
                  Text("Téléphone : ${auteur!.telephone}",
                      style: const TextStyle(fontSize: 15)),
                  Text("Profession : ${auteur!.profession}",
                      style: const TextStyle(fontSize: 15)),
                  Text("Pays : ${auteur!.pays}", style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}

// ---------------- Models ----------------

class UserData {
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final String pays;
  final String profession;

  UserData({
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.pays,
    required this.profession,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      nom: json['nom'] ?? 'Inconnu',
      prenom: json['prenom'] ?? 'Inconnu',
      email: json['email'] ?? 'Non renseigné',
      telephone: json['telephone'] ?? 'Non renseigné',
      pays: json['pays'] ?? 'Non renseigné',
      profession: json['profession'] ?? 'Non renseignée',
    );
  }
}