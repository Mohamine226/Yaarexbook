import 'dart:io';
import 'package:flutter/material.dart';
import 'package:daaga/client/LivreManager.dart';
import 'package:daaga/client/DetailPage.dart';
import 'package:daaga/client/PdfData.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:typed_data';
import '../local/document_repository.dart';
import '../local/file_service.dart';

class Categorie extends StatefulWidget {
  final int userId;
  final DocumentRepository repository;

  const Categorie({
    super.key,
    required this.userId,
    required this.repository,
  });

  @override
  State<Categorie> createState() => _CategorieState();
}

class _CategorieState extends State<Categorie> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> categories = [
    "Science",
    "Éducation",
    "Roman",
    "Concour",
    "Business",
    "Histoire",
  ];

  String selectedCategory = "Science";
  String searchQuery = '';
  List<DomainData> categoriesData = [];
  int? currentCursor; // au lieu de 0

  @override
  void initState() {
    super.initState();
    _chargerCategories();
  }

  Future<void> _chargerCategories({String? search}) async {
    var box = await Hive.openBox('categories');
    var cached = box.get('data');

    // 🔹 Charger depuis le cache Hive si dispo
    if (cached != null) {
      setState(() {
        categoriesData = (cached as List).map((json) {
          final items = (json['items'] as List)
              .map((item) => PdfData.fromJson(Map<String, dynamic>.from(item)))
              .toList();
          return DomainData(json['name'] as String, items);
        }).toList();
      });
    } else {
      final localDocs = await widget.repository.getAllDocuments(limit: 20);
      if (localDocs.isNotEmpty) {
        _regrouperEtSetState(localDocs);
      }
    }

    try {
      // 🔹 Appel API avec pagination par curseur
      print("Appel API avec cursor=$currentCursor et search=$search"); // debug
      final result = await LivreManager.fetchDocuments(
        search: search,
        repository: widget.repository,
        forceRefresh: true,              // 👈 important pour forcer l’appel API
        cursor: currentCursor ?? 0,      // 👈 utilise 0 si null
        limit: 20,
      );

      // 🔹 Mise à jour du curseur pour la prochaine page
      if (result.nextCursor != null) {
        currentCursor = result.nextCursor; // int
      } else if (result.docs.isNotEmpty) {
        currentCursor = result.docs.last.id; // si id est int
      }

      // 🔹 Regrouper et mettre à jour l’état
      _regrouperEtSetState(result.docs);

      // 🔹 Sauvegarde dans Hive
      await box.put(
        'data',
        categoriesData.map((d) => {
          'name': d.name,
          'items': d.items.map((i) => i.toJson()).toList(),
        }).toList(),
      );
    } catch (e) {
      print("Erreur API: $e"); // debug
      final localDocs = await widget.repository.getAllDocuments(limit: 20);
      _regrouperEtSetState(localDocs);
    }
  }

  void _regrouperEtSetState(List<PdfData> docs) {
    final Map<String, List<PdfData>> regroupement = {
      for (var d in categoriesData) d.name: List<PdfData>.from(d.items)
    };

    final Set<String> domainesMisAJour = {};

    for (var doc in docs) {
      final domaine = doc.domain.isNotEmpty ? doc.domain : "Divers";
      regroupement.putIfAbsent(domaine, () => []);

      // 🔹 Vérifier doublon
      final existe = regroupement[domaine]!.any((d) => d.id == doc.id);
      if (!existe) {
        regroupement[domaine]!.insert(0, doc); // insérer au début
        domainesMisAJour.add(domaine);         // marquer comme mis à jour
      }
    }

    var domaines = regroupement.entries
        .map((entry) => DomainData(entry.key, entry.value))
        .toList();

    // 🔹 Réordonner : domaines mis à jour en haut
    domaines.sort((a, b) {
      if (domainesMisAJour.contains(a.name) && !domainesMisAJour.contains(b.name)) {
        return -1;
      } else if (!domainesMisAJour.contains(a.name) && domainesMisAJour.contains(b.name)) {
        return 1;
      } else {
        return 0;
      }
    });

    setState(() {
      categoriesData = domaines;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 On récupère les domaines de la catégorie sélectionnée depuis LivreManager
    final List<DomainData> domaines =
    (LivreManager.domainesParCategorie[selectedCategory] ?? [])
        .where((domain) =>
    domain.name.toLowerCase().contains(searchQuery) ||
        domain.items.any((item) =>
            item.title.toLowerCase().contains(searchQuery)))
        .toList();

    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          title: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Rechercher une catégorie ou un domaine...",
                prefixIcon: Icon(Icons.search, color: Colors.black54),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () => _chargerCategories(search: searchQuery),
          child: ListView(
            children: [
            SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = cat == selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

              const Divider(),
              ...domaines.map((domain) {
                final filteredItems = domain.items.where((item) {
                  return item.title.toLowerCase().contains(searchQuery) ||
                      item.domain.toLowerCase().contains(searchQuery) ||
                      item.categorie.toLowerCase().contains(searchQuery);
                }).toList();

                if (filteredItems.isEmpty) return const SizedBox.shrink();

                return _domainSection(DomainData(domain.name, filteredItems));
              }).toList(),
            ],
          ),
        ),
    );
  }

  Widget _domainSection(DomainData domain) {
    final filteredItems = domain.items
        .where((item) => item.title.toLowerCase().contains(searchQuery))
        .toList();

    if (filteredItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(domain.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _pdfCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pdfCard(PdfData data) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPage(
              data: data,
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
                child: _coverImage(data.image),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
              child: Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            //Padding(
             // padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
             // child: Text(
              //  "${data.price} FCFA",
               // style: const TextStyle(color: Colors.green),
             // ),
            //),
          ],
        ),
      ),
    );
  }

  Widget _coverImage(String? path) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith("assets/")) {
        return Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
        );
      } else if (path.startsWith("http://") || path.startsWith("https://")) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            // 👉 Affiche juste une image vide ou une icône
            return const SizedBox.shrink();
          },
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
        );
      } else {
        if (path.endsWith(".enc")) {
          return FutureBuilder<Uint8List?>(
            future: FileService.decryptImage(path),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // 👉 Pas de spinner, juste une icône
                return const SizedBox.shrink() ;
              }
              if (snapshot.hasData && snapshot.data != null) {
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              }
              return const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red);
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

    return const Center(
      child: Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
    );
  }
}

// ----------------------------
// Modèles de données
// ----------------------------
class DomainData {
  final String name;
  final List<PdfData> items;
  DomainData(this.name, this.items);
}