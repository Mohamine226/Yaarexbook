import 'dart:io';

import 'package:flutter/material.dart';

import '../app_config.dart';

/// Couverture d'un document : fichier local s'il existe (lecture hors ligne),
/// sinon image du serveur.
class CoverImage extends StatelessWidget {
  final String url;
  final String? localPath;
  final double? width;
  final double? height;

  const CoverImage({super.key, required this.url, this.localPath, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Icon(Icons.menu_book, color: Colors.grey.shade400),
    );

    Widget image;
    if (localPath != null && File(localPath!).existsSync()) {
      image = Image.file(File(localPath!), width: width, height: height, fit: BoxFit.cover);
    } else if (url.isNotEmpty) {
      image = Image.network(
        AppConfig.absolute(url),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
      );
    } else {
      image = placeholder;
    }
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: image);
  }
}
