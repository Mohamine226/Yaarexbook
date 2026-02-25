import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:daaga/local/document_repository.dart';
import 'package:flutter/material.dart';
import 'package:daaga/client/LivreManager.dart';
import 'package:daaga/client/PdfData.dart';
import 'package:daaga/client/DetailPage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:typed_data';
import '../local/file_service.dart';

class HomePage extends StatefulWidget {
  final int userId;
  final DocumentRepository repository;

  const HomePage({
    super.key,
    required this.userId,
    required this.repository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  List<PdfData> populaires = [];
  Map<String, List<PdfData>> domainesParCategorie = {};
  bool isLoadingMore = true;
  int currentCursor = 0;

  @override
  void initState() {
    super.initState();
    _chargerAccueil();
    _chargerExplorer();
  }

  Future<void> _chargerAccueil() async {
    var boxPopulaires = await Hive.openBox('accueil_populaires');
    var cachedPopulaires = boxPopulaires.get('data');

    if (cachedPopulaires != null) {
      setState(() {
        populaires = (cachedPopulaires as List)
            .map((json) => PdfData.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      });
    } else {
      final local = await widget.repository.getLivresPopulaires();
      if (local.isNotEmpty) {
        setState(() {
          populaires = local;
        });
      }
    }

    try {
      print("Appel API livres populaires...");
      final apiData = await LivreManager.fetchLivresPopulaires();
      final updatedDocs = <PdfData>[];

      for (var doc in apiData) {
        if (doc.imageUrl != null && doc.imageUrl!.isNotEmpty) {
          final localImagePath = await FileService.downloadAndSaveImage(
            doc.id!,
            doc.imageUrl!,
            prefix: "image_populaire",
          );
          doc = doc.copyWith(image: localImagePath);
        }

        if (doc.pdfUrl != null && doc.pdfUrl!.isNotEmpty) {
          final pdfPath = await FileService.downloadEncryptAndSaveFile(
            doc.pdfUrl!,
            "livre_${doc.id}.enc",
          );
          doc = doc.copyWith(pdfPath: pdfPath);
        }

        await widget.repository.saveDocument(doc);
        updatedDocs.add(doc);
      }

      setState(() {
        populaires = updatedDocs;
      });

      await boxPopulaires.put(
        'data',
        updatedDocs.map((l) => l.toJson()).toList(),
      );
    } catch (e) {
      print("Erreur API populaires: $e");
      final local = await widget.repository.getLivresPopulaires();
      if (local.isNotEmpty) {
        setState(() {
          populaires = local;
        });
      }
    }
  }

  Future<void> _chargerExplorer({String? search, String? domaine}) async {
    var boxExplorer = await Hive.openBox('accueil_explorer');
    var cachedExplorer = boxExplorer.get('data');

    // 🔹 Charger depuis Hive si dispo
    if (cachedExplorer != null && cachedExplorer is Map) {
      final map = <String, List<PdfData>>{};
      cachedExplorer.forEach((key, value) {
        final domaineKey = key as String;
        final list = (value as List)
            .map((json) => PdfData.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        map[domaineKey] = list;
      });
      setState(() {
        domainesParCategorie = map;
      });
    } else {
      final local = await widget.repository.getDocumentsParDomaines(
        search: search,
        cursor: currentCursor,
        limit: 20,
      );
      if (local.isNotEmpty) {
        setState(() {
          domainesParCategorie = local;
        });
      }
    }

    try {
      // 🔹 Appel API : si domaine est fourni → explorerParDomaineAPI, sinon fetchDocuments
      List<PdfData> docs;
      int? nextCursor;
      if (domaine != null) {
        docs = await LivreManager.explorerParDomaineAPI(
          domaine,
          search: search,
          repository: widget.repository,
          cursor: currentCursor,
          limit: 20,
          forceRefresh: true,
        );
      } else {
        final result = await LivreManager.fetchDocuments(
          search: search,
          repository: widget.repository,
          cursor: currentCursor,
          limit: 20,
          forceRefresh: true,
        );
        docs = result.docs;
        nextCursor = result.nextCursor;
      }

      // 🔹 Enrichir les documents (images + PDF)
      final updatedDocs = <PdfData>[];
      for (var doc in docs) {
        // 🔹 Télécharger et sauvegarder l’image localement
        if (doc.imageUrl != null && doc.imageUrl!.isNotEmpty) {
          final localImagePath = await FileService.downloadAndSaveImage(
            doc.id!,
            doc.imageUrl!,
            prefix: "image_explorer",
          );
          doc = doc.copyWith(image: localImagePath);
        }

        // 🔹 Télécharger et chiffrer le PDF
        if (doc.pdfUrl != null && doc.pdfUrl!.isNotEmpty) {
          final pdfPath = await FileService.downloadEncryptAndSaveFile(
            doc.pdfUrl!,
            "livre_${doc.id}.enc",
          );
          doc = doc.copyWith(pdfPath: pdfPath);
        }

        await widget.repository.saveDocument(doc);
        updatedDocs.add(doc);
      }

      // 🔹 Regrouper par domaine
      final grouped = Map<String, List<PdfData>>.from(domainesParCategorie);
      for (var doc in updatedDocs) {
        final domaineKey = doc.domain.isNotEmpty ? doc.domain : "Autres";
        grouped.putIfAbsent(domaineKey, () => []);
        final existe = grouped[domaineKey]!.any((d) => d.id == doc.id);
        if (!existe) {
          grouped[domaineKey]!.insert(0, doc);

          // 🔹 Faire remonter le domaine en haut
          final domaineDocs = grouped.remove(domaineKey);
          // recréer la map avec ce domaine en premier
          final newGrouped = <String, List<PdfData>>{domaineKey: domaineDocs!};
          newGrouped.addAll(grouped);
          grouped
            ..clear()
            ..addAll(newGrouped);
        }
      }

      // 🔹 Mise à jour du curseur
      setState(() {
        domainesParCategorie = grouped;
        if (nextCursor != null) {
          currentCursor = nextCursor;
        } else if (updatedDocs.isNotEmpty) {
          currentCursor = updatedDocs.last.id ?? currentCursor;
        }
      });

      // 🔹 Sauvegarde Hive
      final toStore = grouped.map((domaine, list) =>
          MapEntry(domaine, list.map((p) => p.toJson()).toList()));
      await boxExplorer.put('data', toStore);

    } catch (e) {
      final local = await widget.repository.getDocumentsParDomaines(
        search: search,
        cursor: currentCursor,
        limit: 20,
      );
      setState(() {
        domainesParCategorie = local;
      });
    }
  }

  List<PdfData> _filterLivres(List<PdfData> livres) {
    if (_searchQuery.isEmpty) return livres;
    final query = _searchQuery.toLowerCase();
    return livres.where((livre) =>
    livre.title.toLowerCase().contains(query) ||
        livre.domain.toLowerCase().contains(query) ||
        livre.language.toLowerCase().contains(query)).toList();
  }

  Widget _coverImage(String? path) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith("http")) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.picture_as_pdf,
                size: 48, color: Colors.red);
          },
        );
      } else if (path.startsWith("assets/")) {
        return Image.asset(path, fit: BoxFit.cover);
      } else {
        if (path.endsWith(".enc")) {
          return FutureBuilder<Uint8List?>(
            future: FileService.decryptImage(path),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink(); // pas de spinner visible
              }
              if (snapshot.hasData && snapshot.data != null) {
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              }
              return const Icon(Icons.picture_as_pdf,
                  size: 48, color: Colors.red);
            },
          );
        } else {
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
          );
        }
      }
    }
    return const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red);
  }

  Widget _bookCard(PdfData livre) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPage(
              data: livre,
              userId: widget.userId,
              repository: widget.repository,
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _coverImage(livre.image),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                livre.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            //Text(
            //  "${livre.price} FCFA",
            //  style: const TextStyle(color: Colors.green),
            //  textAlign: TextAlign.center,
            //),
          ],
        ),
      ),
    );
  }

  Widget _domainSection(String domaine, List<PdfData> livres) {
    final sorted = List<PdfData>.from(livres)
      ..sort((a, b) => b.achats.compareTo(a.achats));
    final filtered = _filterLivres(sorted);
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(domaine,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length,
              itemBuilder: (context, index) => _bookCard(filtered[index]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDomainSections() {
    final map = domainesParCategorie;
    final List<Widget> sections = [];

    map.forEach((categorie, livres) {
      if (livres.isEmpty) return;
      final filtered = _filterLivres(livres);
      if (filtered.isEmpty) return;
      sections.add(_domainSection(categorie, filtered));
      sections.add(const Divider());
    });

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final filteredPopulaires = _filterLivres(populaires);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          automaticallyImplyLeading: false, // ✅ enlève la flèche
          elevation: 0,
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Accueil",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: "Rechercher un livre...",
                      prefixIcon: Icon(Icons.search, color: Colors.black54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (!isLoadingMore &&
              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            // 🔹 Vérifier s’il reste des données
            if (currentCursor != null) {
              setState(() => isLoadingMore = true);
              _chargerExplorer().then((_) {
                setState(() => isLoadingMore = false);
              });
            }
            // 🔹 Sinon, ne rien faire
          }
          return false;
        },
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Livres populaires 🔥",
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (filteredPopulaires.isEmpty)
                    const Center(
                      child: Text(
                        "Aucun livre populaire disponible",
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else
                    SizedBox(
                      height: 190,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (scrollInfo) {
                          if (!isLoadingMore &&
                              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                            _chargerExplorer(); // charge uniquement cette section
                          }
                          return false;
                        },
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredPopulaires.length,
                          itemBuilder: (context, index) => _bookCard(filteredPopulaires[index]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                "Explorer par domaine",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ..._buildDomainSections(),
          ],
        ),
      ),
    );
  }
}