import 'package:flutter/material.dart';
import 'MougliIA.dart';

class MougliPdf extends StatefulWidget {
  final Widget child; // le contenu derrière (ex: PDF viewer)

  const MougliPdf({super.key, required this.child});

  @override
  State<MougliPdf> createState() => MougliPdfState();
}

class MougliPdfState extends State<MougliPdf> {
  bool _isExpanded = false; // ✅ état agrandi/réduit
  bool _isVisible = false;  // ✅ panneau affiché ou non

  /// 🔹 Méthode pour ouvrir/fermer le panneau
  void togglePanel() {
    setState(() {
      _isVisible = !_isVisible;
      _isExpanded = false; // commence réduit
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔹 Contenu principal (PDF)
        widget.child,

        // 🔹 Fenêtre flottante IA
        _isVisible
            ? AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: 0,
          right: 0,
          bottom: 0,
          height: _isExpanded
              ? MediaQuery.of(context).size.height - kToolbarHeight - 80  // plein écran limité
              : MediaQuery.of(context).size.height * 0.4, // réduit
          child: SafeArea(
            child: Material(
              elevation: 8,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
              child: Column(
                children: [
                  // 🔹 Barre de contrôle (AppBar interne)
                  AppBar(
                    automaticallyImplyLeading: false,
                    title: const Text("Mougli IA"),
                    actions: [
                      IconButton(
                        icon: Icon(_isExpanded
                            ? Icons.close_fullscreen
                            : Icons.open_in_full),
                        tooltip: _isExpanded ? "Réduire" : "Agrandir",
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: "Fermer",
                        onPressed: () {
                          setState(() {
                            _isVisible = false;
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  // 🔹 Contenu IA
                  Expanded(child: MougliIA()),
                ],
              ),
            ),
          ),
        )
            : const SizedBox.shrink(), // ✅ widget vide si non visible
      ],
    );
  }
}