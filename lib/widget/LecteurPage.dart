import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path/path.dart' as p;
import 'package:daaga/client/PdfData.dart';
import 'package:daaga/local/file_service.dart';
import 'package:screen_protector/screen_protector.dart';
import 'dart:ffi';
import 'package:win32/win32.dart';

import '../mougli/MougliPdf.dart';

class LecteurPage extends StatefulWidget {
  final String path;
  final bool isLocalDocument;
  final PdfData? pdfData;
  final String? title;

  const LecteurPage({
    super.key,
    required this.path,
    required this.isLocalDocument,
    this.pdfData,
    this.title,
  });

  @override
  State<LecteurPage> createState() => _LecteurPageState();
}

class _LecteurPageState extends State<LecteurPage> {
  final GlobalKey<MougliPdfState> _mougliKey = GlobalKey<MougliPdfState>();
  late PdfViewerController _pdfViewerController;
  bool _isSearching = false;
  String _searchText = "";
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enableProtection();
    });
  }

  Future<void> _enableProtection() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await ScreenProtector.preventScreenshotOn();
    } else if (Platform.isWindows) {
      WindowsCaptureGuard.enable();
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid || Platform.isIOS) {
      ScreenProtector.preventScreenshotOff();
    } else if (Platform.isWindows) {
      WindowsCaptureGuard.disable();
    }
    super.dispose();
  }

  Widget _buildPdfViewer(PdfData doc) {
    if (doc.isLocalPdf) {
      if (doc.pdfPath!.endsWith(".enc")) {
        return FutureBuilder<Uint8List>(
          future: FileService.decryptFile(doc.pdfPath!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text("Erreur de lecture du PDF"));
            }
            if (!snapshot.hasData) {
              return const Center(child: Text("PDF introuvable"));
            }
            return SfPdfViewer.memory(
              snapshot.data!,
              controller: _pdfViewerController,
              onZoomLevelChanged: (_) {}, // zoom n'affecte pas AppBar
            );
          },
        );
      } else {
        return SfPdfViewer.file(
          File(doc.pdfPath!),
          controller: _pdfViewerController,
          onZoomLevelChanged: (_) {}, // zoom n'affecte pas AppBar
        );
      }
    } else {
      return SfPdfViewer.network(
        doc.pdfUrl!,
        controller: _pdfViewerController,
        onZoomLevelChanged: (_) {}, // zoom n'affecte pas AppBar
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdfData doc = widget.pdfData ??
        PdfData(
          title: p.basename(widget.path),
          price: 0,
          domain: "",
          language: "",
          description: "",
          pdfPath: widget.path,
        );

    final String displayTitle = widget.title ?? doc.title;

    return WillPopScope(
      onWillPop: () async {
        if (MediaQuery.of(context).orientation == Orientation.landscape) {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
        }
        return true;
      },
      child: Scaffold(
        appBar: _showAppBar
            ? AppBar(
          titleSpacing: 0,
          title: _isSearching
              ? TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Rechercher...",
              border: InputBorder.none,
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
              if (value.isNotEmpty) {
                _pdfViewerController.searchText(value);
              } else {
                _pdfViewerController.clearSelection();
              }
            },
          )
              : Text(
            displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              tooltip:
              _isSearching ? "Fermer la recherche" : "Rechercher",
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchText = "";
                    _pdfViewerController.clearSelection();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.screen_rotation_rounded),
              tooltip: "Changer orientation",
              onPressed: () {
                if (MediaQuery.of(context).orientation ==
                    Orientation.portrait) {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                } else {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                  ]);
                }
              },
            ),
            //IconButton(
             // icon: Image.asset("assets/images/mougli.png", height: 30),
            //  tooltip: "Ouvrir MougliIA",
            //  onPressed: MediaQuery.of(context).orientation == Orientation.portrait
            //      ? () {
            //    _mougliKey.currentState?.togglePanel();
            //  }
            //      : null, // 🔹 désactivé si paysage
           // ),
          ],
        )
            : null,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            setState(() {
              _showAppBar = !_showAppBar; // toggle simple
            });
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: MougliPdf(
              key: _mougliKey,
              child: _buildPdfViewer(doc),
            ),
          ),
        ),
      ),
    );
  }
}

class WindowsCaptureGuard {
  static const int DISPLAYAFFINITY_EXCLUDE_FROM_CAPTURE = 0x00000011;

  static void enable() {
    final hwnd = GetForegroundWindow();
    if (hwnd != 0) {
      SetWindowDisplayAffinity(hwnd, DISPLAYAFFINITY_EXCLUDE_FROM_CAPTURE);
    }
  }

  static void disable() {
    final hwnd = GetForegroundWindow();
    if (hwnd != 0) {
      SetWindowDisplayAffinity(hwnd, 0);
    }
  }
}