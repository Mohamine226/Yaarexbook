import 'package:flutter/material.dart';

class AidePage extends StatelessWidget {
  const AidePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Aide")),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "Bienvenue dans la section Aide.\n\n"
              "Ici tu peux mettre des instructions, des FAQ, ou un guide utilisateur.",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}