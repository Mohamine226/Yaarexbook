import 'package:daaga/InscritConfirme.dart';
import 'package:flutter/material.dart';
import 'package:daaga/widget/Input.dart';
import 'package:country_calling_code_picker/picker.dart'; // ✅ garde uniquement celui-ci

class PageInscription extends StatefulWidget {
  const PageInscription({super.key});

  @override
  State<PageInscription> createState() => _PageInscriptionState();
}

class _PageInscriptionState extends State<PageInscription> {
  final mailController = TextEditingController();
  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final telephoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Country? _selectedCountry;

  @override
  void initState() {
    super.initState();
    initCountry(); //  Burkina Faso par défaut
  }

  void initCountry() async {
    final country = await getCountryByCountryCode(context, 'BF'); // Burkina Faso
    setState(() {
      _selectedCountry = country;
    });
  }

  void _showCountryPicker() async {
    final country = await showCountryPickerSheet(context);
    if (country != null) {
      setState(() {
        _selectedCountry = country;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.only(top: 30),
            margin: const EdgeInsets.all(30),
            child: Column(
              children: [
                const Text(
                  "Inscription",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Input(
                        label: "Prénom",
                        hint: "Veuillez entrer votre prénom",
                        controller: prenomController,
                        validator: (value) =>
                        value == null || value.isEmpty ? "Veuillez saisir votre prénom" : null,
                      ),
                      const SizedBox(height: 15),
                      Input(
                        label: "Nom",
                        hint: "Veuillez entrer votre nom",
                        controller: nomController,
                        validator: (value) =>
                        value == null || value.isEmpty ? "Veuillez saisir votre nom" : null,
                      ),

                      const SizedBox(height: 15),

                      //  Champ du Téléphone
                      TextFormField(
                        controller: telephoneController,
                        decoration: InputDecoration(
                          hintText: "Numéro de téléphone",
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          prefixIcon: InkWell(
                            onTap: _showCountryPicker,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                Text(
                                  _selectedCountry?.callingCode != null
                                      ? "${_selectedCountry!.callingCode}"
                                      : "+226", //  utilise callingCode
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez saisir votre numéro de téléphone";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 15),

                      Input(
                        label: "Email",
                        hint: "Veuillez entrer votre mail",
                        controller: mailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez saisir votre mail";
                          }
                          final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                          if (!regex.hasMatch(value.trim())) {
                            return "Adresse email invalide";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              //  Concaténation code pays + numéro
                              final fullPhone =
                                  "${_selectedCountry?.callingCode ?? "226"}${telephoneController.text}";

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InscritConfirme(
                                    nom: nomController.text,
                                    prenom: prenomController.text,
                                    email: mailController.text,
                                    telephone: fullPhone, //  numéro complet envoyé
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text(
                            "Continuer",
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}