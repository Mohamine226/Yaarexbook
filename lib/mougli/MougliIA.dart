import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

// 🔹 Classe Message pour éviter les Map fragiles
class Message {
  final String role; // "user" ou "ia"
  final String type; // "text" ou "file"
  final String? text;
  final String? path;
  final String? name;
  final String? size;

  Message({
    required this.role,
    required this.type,
    this.text,
    this.path,
    this.name,
    this.size,
  });
}

class MougliIA extends StatefulWidget {
  const MougliIA({super.key});

  @override
  State<MougliIA> createState() => _MougliIAState();
}

class _MougliIAState extends State<MougliIA> {
  final TextEditingController questionController = TextEditingController();
  final List<Message> messages = [];

  bool isLoading = false;
  bool hasStarted = false;

  final ImagePicker picker = ImagePicker();

  // 🔹 Image sélectionnée AVANT envoi
  File? selectedImage;
  String? selectedImageName;
  int? selectedImageSize;

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  // 🔹 Galerie
  Future<void> _pickImageFromFiles() async {
    FilePickerResult? result =
    await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedImage = File(result.files.single.path!);
        selectedImageName = result.files.single.name;
        selectedImageSize = result.files.single.size;
      });
    }
  }

  // 🔹 Caméra
  Future<void> _pickImageFromCamera() async {
    final ok = await _ensureCameraPermission();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permission caméra refusée")),
      );
      return;
    }

    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final file = File(image.path);
      setState(() {
        selectedImage = file;
        selectedImageName = image.name;
        selectedImageSize = file.lengthSync();
      });
    }
  }

  // 🔹 Envoi message
  void _envoyerMessage() {
    final text = questionController.text.trim();

    if (text.isEmpty && selectedImage == null) return;

    setState(() {
      // 🔹 Envoi image + texte ensemble
      if (selectedImage != null) {
        messages.add(Message(
          role: "user",
          type: "file+text", // ✅ nouveau type combiné
          path: selectedImage!.path,
          name: selectedImageName,
          size: (selectedImageSize! / 1024).round().toString(),
          text: text.isNotEmpty ? text : null, // ✅ texte attaché à l’image
        ));

        // reset image
        selectedImage = null;
        selectedImageName = null;
        selectedImageSize = null;
      } else {
        // 🔹 Envoi texte seul
        messages.add(Message(
          role: "user",
          type: "text",
          text: text,
        ));
      }

      hasStarted = true;
      isLoading = true;
    });

    questionController.clear();

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        messages.add(Message(
          role: "ia",
          type: "text",
          text: "Mougli IA a bien reçu votre message",
        ));
        isLoading = false;
      });
    });
  }

  void _nouvelleDiscussion() {
    setState(() {
      messages.clear();
      hasStarted = false;
      questionController.clear();
      selectedImage = null;
    });
  }

  // 🔹 Message (texte ou fichier)
  Widget _buildMessage(Message msg) {
    final isUser = msg.role == "user";

    if (msg.type == "file" || msg.type == "file+text") {
      return Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          width: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Miniature de l’image
              if (msg.path != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(msg.path!),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 8),

              // 🔹 Nom + taille
              if (msg.name != null)
                Text(
                  msg.name!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              if (msg.size != null)
                Text(
                  "${msg.size} KB",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),

              // 🔹 Texte attaché
              if (msg.text != null && msg.text!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    msg.text!,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 🔹 Message texte simple
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? Colors.grey.shade300 : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg.text ?? "",
          style: TextStyle(
            color: isUser ? Colors.black : Colors.black,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // ✅ ajuste quand le clavier apparaît
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          hasStarted ? "Discussion en cours" : "Nouvelle discussion",
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.black),
            onPressed: _nouvelleDiscussion,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Zone messages scrollable
            Expanded(
              child: messages.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset("assets/images/mougli.png", height: 50),
                    const SizedBox(height: 20),
                    const Text(
                      "Bonjour, je suis Mougli IA.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Comment puis-je vous aider aujourd’hui ?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) =>
                    _buildMessage(messages[index]),
              ),
            ),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),

            // 🔹 Barre de saisie FIXE en bas
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔹 Preview image AVANT envoi
                  if (selectedImage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Miniature de l’image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              selectedImage!,
                              height: 50,
                              width: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Nom du fichier
                          Expanded(
                            child: Text(
                              selectedImageName ?? "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),

                          // Bouton pour supprimer l’image
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                selectedImage = null;
                                selectedImageName = null;
                                selectedImageSize = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                  // 🔹 Ligne avec bouton +, champ texte et bouton envoyer
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.black),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (_) => Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text("Choisir une image"),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImageFromFiles();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text("Prendre une photo"),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImageFromCamera();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: questionController,
                          minLines: 1,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: "Demande à Mougli IA",
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            // 🔹 Bouton intégré dans le champ
                            suffixIcon: Container(
                              margin: const EdgeInsets.only(right: 4, bottom: 4),
                              width: 36,   // ✅ largeur du cercle
                              height: 36,  // ✅ hauteur du cercle
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero, // ✅ enlève le padding interne
                                iconSize: 20,             // ✅ réduit la taille de l’icône
                                icon: const Icon(Icons.arrow_upward,
                                    color: Colors.white),
                                onPressed: _envoyerMessage,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}