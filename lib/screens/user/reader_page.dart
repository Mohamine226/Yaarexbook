import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../utils/screen_guard.dart';

/// Lecteur PDF. Les captures d'écran sont bloquées pendant la lecture.
class ReaderPage extends StatefulWidget {
  final String title;
  final Uint8List bytes;
  const ReaderPage({super.key, required this.title, required this.bytes});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  @override
  void initState() {
    super.initState();
    _protect(true);
  }

  @override
  void dispose() {
    _protect(false);
    super.dispose();
  }

  Future<void> _protect(bool on) => ScreenGuard.setSecure(on);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: SfPdfViewer.memory(widget.bytes),
    );
  }
}
