import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:daaga/widget/LecteurPage.dart';
import 'package:daaga/widget/RecentPdf.dart';
import 'package:daaga/widget/RecentManager.dart';

// 🔹 Fonction globale pour choisir l’icône selon extension
Widget? _getFileIcon(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.pdf')) {
    return const CircleAvatar(
      backgroundColor: Colors.red,
      child: Text(
        "PDF",
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  // 🔹 Rien pour les autres formats
  return null;
}

class DocumentPage extends StatefulWidget {
  const DocumentPage({super.key});

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}
class _DocumentPageState extends State<DocumentPage> {
  List<FileSystemEntity> allFiles = [];
  List<FileSystemEntity> filteredFiles = [];
  bool loading = true;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _scanDocuments();
  }

  // 🔍 Filtrage des fichiers
  void _filterFiles(String query) {
    setState(() {
      searchQuery = query;
      filteredFiles = allFiles.where((file) {
        final name = file.path.split('/').last.toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  // 🔐 Permission Android
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (status.isGranted) return true;
      status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }
    return true;
  }

  // 📂 Scan documents
  Future<void> _scanDocuments() async {
    setState(() => loading = true);

    if (!await _requestPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permission refusée 📛")),
      );
      setState(() => loading = false);
      return;
    }

    List<FileSystemEntity> files = [];
    final List<String> searchPaths = [
      "/storage/emulated/0/Documents",
      "/storage/emulated/0/Download",
      "/storage/emulated/0/WhatsApp/Media/WhatsApp Documents",
      "/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents",
      "/storage/emulated/0/Telegram/Telegram Documents",
    ];

    for (final path in searchPaths) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        try {
          files.addAll(
            dir.listSync(recursive: true).where((e) {
              if (e is! File) return false;
              final lower = e.path.toLowerCase();
              return lower.endsWith(".pdf");
            }),
          );
        } catch (_) {}
      }
    }

    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    setState(() {
      allFiles = files;
      filteredFiles = files;
      loading = false;
    });
  }

  // 🔄 Tri par nom
  void _trierParNom(bool asc) {
    setState(() {
      filteredFiles.sort((a, b) {
        final nameA = a.path.split('/').last.toLowerCase();
        final nameB = b.path.split('/').last.toLowerCase();
        return asc ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      });
    });
  }

  // 🔄 Tri par date
  void _trierParDate(bool recentFirst) {
    setState(() {
      filteredFiles.sort((a, b) {
        final da = a.statSync().modified;
        final db = b.statSync().modified;
        return recentFirst ? db.compareTo(da) : da.compareTo(db);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Documents"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _DocSearchDelegate(allFiles, _filterFiles),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'asc') {
                _trierParNom(true);
              } else if (value == 'desc') {
                _trierParNom(false);
              } else if (value == 'recent') {
                _trierParDate(true);
              } else if (value == 'old') {
                _trierParDate(false);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'recent', child: Text('Plus récent')),
              PopupMenuItem(value: 'old', child: Text('Moins récent')),
              PopupMenuItem(value: 'asc', child: Text('Trier par nom A → Z')),
              PopupMenuItem(value: 'desc', child: Text('Trier par nom Z → A')),
            ],
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : filteredFiles.isEmpty
          ? const Center(child: Text("Aucun document 📂"))
          : Scrollbar(
        thumbVisibility: true,
        child: ListView.builder(
          itemCount: filteredFiles.length,
          itemBuilder: (context, index) {
            final file = filteredFiles[index];
            final stat = file.statSync();
            final fileName = file.path.split('/').last;

            return ListTile(
              leading: _getFileIcon(file.path),
              title: Text(fileName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                "${(stat.size / (1024 * 1024)).toStringAsFixed(1)} MB • "
                    "${stat.modified.day}/${stat.modified.month}",
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LecteurPage(
                      path: file.path,
                      isLocalDocument: true,
                    ),
                  ),
                );

                final recent = RecentPdf(
                  fileName: file.uri.pathSegments.last,
                  openedAt: DateTime.now().toString(),
                  path: file.path,
                );
                RecentManager.addRecent(recent);
              },
            );
          },
        ),
      ),
    );
  }
}

// 🔍 Delegate de recherche
class _DocSearchDelegate extends SearchDelegate {
  final List<FileSystemEntity> files;
  final Function(String) onQueryChanged;

  _DocSearchDelegate(this.files, this.onQueryChanged)
      : super(searchFieldLabel: "Recherche"); // 🔹 ici tu changes le texte

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
      onQueryChanged(""); // notifie le parent → liste complète

      // 🔹 Ferme la barre de recherche
      close(context, null);
    },
  );

  @override
  Widget buildResults(BuildContext context) {
    // 🔹 Notifie le parent après le build pour éviter l’erreur rouge
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
    final filtered = files.where((file) {
      final name = file.path.split('/').last.toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final file = filtered[index];
        final stat = file.statSync();
        final fileName = file.path.split('/').last;

        return ListTile(
          leading: _getFileIcon(file.path),
          title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            "${(stat.size / (1024 * 1024)).toStringAsFixed(1)} MB • "
                "${stat.modified.day}/${stat.modified.month}",
          ),
          onTap: () {
            // ❌ Ne pas fermer la recherche ici
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LecteurPage(
                  path: file.path,
                  isLocalDocument: true,
                ),
              ),
            ).then((_) {
              // 🔹 Quand on revient du lecteur, la recherche reste active
              // et le champ `query` garde le texte tapé
            });

            // 🔹 Enregistre dans les récents
            final recent = RecentPdf(
              fileName: fileName,
              openedAt: DateTime.now().toString(),
              path: file.path,
            );
            RecentManager.addRecent(recent);
          },
        );
      },
    );
  }
}

// 🔄 Dialog pour renommer
Future<String?> _showRenameDialog(BuildContext context, String oldName) {
  final controller = TextEditingController(text: oldName);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Renommer le fichier"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: "Nouveau nom"),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text("Valider"),
        ),
      ],
    ),
  );
}