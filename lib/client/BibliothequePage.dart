import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daaga/client/LivreManager.dart';
import 'package:daaga/client/PdfData.dart';
import 'package:daaga/widget/LecteurPage.dart';
import 'package:daaga/widget/AffichageList.dart';
import 'package:daaga/widget/RecentPdf.dart';
import 'package:daaga/widget/RecentManager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:typed_data';
import '../local/document_repository.dart';
import '../local/file_service.dart';

class BibliothequePage extends StatefulWidget {
  final int userId;
  final DocumentRepository repository;

  const BibliothequePage({
    super.key,
    required this.userId,
    required this.repository,
  });

  @override
  State<BibliothequePage> createState() => _BibliothequePageState();
}

class _BibliothequePageState extends State<BibliothequePage> {
  List<PdfData> livres = [];
  List<PdfData> livresFiltres = [];
  String searchQuery = "";
  bool affichageListe = false;

  @override
  void initState() {
    super.initState();
    chargerLivres();
    _chargerPreferenceAffichage();
  }

  Future<void> chargerLivres() async {
    final box = await Hive.openBox('bibliotheque_${widget.userId}');
    final cached = box.get('livres');

    List<PdfData> result = [];

    // 🔹 1️⃣ Hive (rapide)
    if (cached != null) {
      result = (cached as List)
          .map((json) => PdfData.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } else {
      // 🔹 2️⃣ SQLite (offline fiable)
      final local = await widget.repository.getBibliotheque(widget.userId);
      if (local.isNotEmpty) {
        result = local;
      }
    }

    if (result.isNotEmpty) {
      setState(() {
        livres = result;
        livresFiltres = result;
      });
    }

    // 🔹 3️⃣ API (source de vérité)
    try {
      final apiDocs = await LivreManager.fetchBibliotheque(
        widget.userId,
        widget.repository,
      );

      if (apiDocs.isNotEmpty) {
        setState(() {
          livres = apiDocs.reversed.toList();
          livresFiltres = livres;
        });

        // ✅ Hive seulement (SQLite déjà géré)
        await box.put(
          'livres',
          apiDocs.map((l) => l.toJson()).toList(),
        );
      }
    } catch (_) {
      // 🔹 4️⃣ fallback silencieux (déjà chargé)
    }
  }


  void _filtrerLivres(String query) {
    setState(() {
      searchQuery = query;
      livresFiltres = livres.where((livre) {
        return livre.title.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _trierLivres(bool asc) {
    setState(() {
      livresFiltres.sort((a, b) =>
      asc ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
    });
  }

  void _trierParInsertion(bool plusRecent) {
    setState(() {
      if (plusRecent) {
        livresFiltres = List.from(livres);
      } else {
        livresFiltres = List.from(livres.reversed);
      }
    });
  }

  Widget _coverImage(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith("assets/")) {
        return Image.asset(imagePath, fit: BoxFit.cover, width: double.infinity);
      } else if (imagePath.startsWith("http://") || imagePath.startsWith("https://")) {
        return Image.network(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red);
          },
        );
      } else {
        // 🔹 Cas fichier local chiffré
        return FutureBuilder<Uint8List>(
          future: FileService.decryptFile(imagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Icon(Icons.error, size: 48, color: Colors.red);
            }
            if (!snapshot.hasData) {
              return const Icon(Icons.image_not_supported, size: 48, color: Colors.grey);
            }
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              width: double.infinity,
            );
          },
        );
      }
    }
    return const Icon(Icons.book, size: 60, color: Colors.red);
  }

  Future<void> _chargerPreferenceAffichage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      affichageListe = prefs.getBool("affichageListe") ?? false;
    });
  }

  Future<void> _sauvegarderPreferenceAffichage(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("affichageListe", value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bibliothèque"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Rechercher",
            onPressed: () {
              showSearch(
                context: context,
                delegate: _LivreSearchDelegate(livres, _filtrerLivres),
              );
            },
          ),
          IconButton(
            icon: Icon(
              affichageListe
                  ? Icons.grid_view_rounded
                  : Icons.view_list_rounded,
            ),
            tooltip: "Changer affichage",
            onPressed: () {
              setState(() {
                affichageListe = !affichageListe;
              });
              _sauvegarderPreferenceAffichage(affichageListe);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'asc') {
                _trierLivres(true);
              } else if (value == 'desc') {
                _trierLivres(false);
              } else if (value == 'recent') {
                _trierParInsertion(true);
              } else if (value == 'old') {
                _trierParInsertion(false);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'asc', child: Text('Trier par nom A → Z')),
              PopupMenuItem(value: 'desc', child: Text('Trier par nom Z → A')),
              PopupMenuItem(value: 'recent', child: Text('Plus récent')),
              PopupMenuItem(value: 'old', child: Text('Moins récent')),
            ],
          ),
        ],
      ),
      body: livresFiltres.isEmpty
          ? const Center(
        child: Text(
          "Aucun livre acheté pour l'instant",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: affichageListe
            ? AffichageList(
          userId: widget.userId,
          repository: widget.repository,
        )
            : GridView.builder(
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.75,
          ),
          itemCount: livresFiltres.length,
          itemBuilder: (context, index) {
            final livre = livresFiltres[index];
            return InkWell(
              onTap: () {
                if (livre.pdfPath != null &&
                    livre.pdfPath!.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LecteurPage(
                        path: livre.pdfPath!,
                        isLocalDocument: false,
                        pdfData: livre,
                      ),
                    ),
                  );

                  final recent = RecentPdf(
                    fileName: livre.title,
                    openedAt: DateTime.now().toString(),
                    path: livre.pdfPath!,
                  );
                  RecentManager.addRecent(recent);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Chemin PDF invalide")),
                  );
                }
              },
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius:
                        const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: _coverImage(livre.image),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      livre.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// 🔍 Delegate de recherche corrigé (évite setState pendant build)
class _LivreSearchDelegate extends SearchDelegate {
  final List<PdfData> livres;
  final Function(String) onQueryChanged;

  _LivreSearchDelegate(this.livres, this.onQueryChanged)
      : super(searchFieldLabel: "Recherche"); // 🔹 Ici tu mets "Recherche"


  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear),
      onPressed: () {
        query = "";
        onQueryChanged(query);
      },
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      // 🔹 Réinitialise la recherche
      query = "";
      onQueryChanged(""); // notifie le parent → recharge tous les documents

      // 🔹 Ferme la barre de recherche
      close(context, null);
    },
  );

  @override
  Widget buildResults(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onQueryChanged(query);
    });
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final filtered = livres.where((livre) {
      return livre.title.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final livre = filtered[index];
        return ListTile(
          leading: const Icon(Icons.book, color: Colors.green),
          title: Text(livre.title),
          onTap: () {
            // ❌ ne pas fermer la recherche ici
            onQueryChanged(livre.title);

            // 🔹 ouvre ton lecteur PDF
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LecteurPage(
                  path: livre.pdfPath!,
                  isLocalDocument: true,
                  pdfData: livre,
                ),
              ),
            );
          },
        );
      },
    );
  }
}