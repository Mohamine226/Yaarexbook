# Yaarexbook

> Le réseau social de partage de documents éducatifs.

Projet présenté au Hackathon 226 – Édition 2026, domaine **Éducation**. Licence : **Apache 2.0**.

## 1. Présentation du projet

Yaarexbook est une application mobile où chacun peut **publier un document PDF**, le faire découvrir, le commenter, et le **garder dans sa bibliothèque personnelle**, lisible sans connexion. Chaque document a une couverture, un titre, une description, une catégorie, une langue et un domaine. Les utilisateurs peuvent suivre leurs auteurs préférés, aimer et commenter les documents.

## 2. Problématique et objectifs

**Problème.** Les cours, annales et livres circulent par messageries, clés USB et groupes de discussion : sans classement, sans auteur identifié, difficiles à retrouver, et sans contrôle sur leur diffusion.

**Objectifs.**
- réunir les documents éducatifs en un seul endroit, classés et recherchables ;
- relier auteurs et lecteurs (abonnements, mentions j'aime, commentaires) ;
- permettre la lecture hors connexion ;
- protéger les documents (accès authentifié, blocage des captures d'écran sur Android) ;
- donner aux administrateurs les moyens de modérer.

## 3. Architecture technique

```
Application Flutter  <--HTTP + JSON, jeton JWT-->  Serveur FastAPI  -->  SQLite (9 tables)
 (écrans, lecteur PDF,                                                -->  Disque privé (PDF)
  bibliothèque chiffrée AES)                                          -->  Dossier public (couvertures)
                                                                      -->  Brevo (emails de code)
```

- **`lib/`** : application Flutter (interface en français).
- **`lapi/`** : serveur FastAPI (`app/routers`, `app/models.py`, `app/services`) et ses tests (`tests/`).
- **Données** : tables créées au démarrage du serveur ; PDF stockés hors accès public et servis aux seuls utilisateurs connectés ; copie locale chiffrée (AES) sur le téléphone pour la bibliothèque.
- **Sessions** : une session par appareil, donc plusieurs appareils sur un même compte.

## 4. Technologies et licences

| Technologie | Usage | Licence |
|---|---|---|
| Flutter / Dart | Application mobile | BSD-3-Clause |
| Python | Langage du serveur | PSF License |
| FastAPI | API REST | MIT |
| Uvicorn | Serveur d'exécution | BSD-3-Clause |
| SQLAlchemy, aiosqlite | Accès à la base | MIT |
| SQLite | Base de données | Domaine public |
| Pydantic, PyJWT, argon2-cffi | Validation, jetons, mots de passe | MIT |
| python-multipart | Envoi de fichiers | Apache-2.0 |
| Packages Flutter : http, shared_preferences, path_provider, flutter_secure_storage, encrypt | Réseau, stockage, chiffrement | BSD-3-Clause |
| file_picker, cupertino_icons | Choix de fichiers, icônes | MIT |
| sqflite | Bibliothèque locale | BSD-2-Clause |
| Syncfusion PDF Viewer | Lecture des PDF | Licence communautaire Syncfusion (gratuite sous conditions, non open source) |
| Brevo | Envoi d'emails (service externe) | Service commercial (offre gratuite) |

Les licences sont celles indiquées par chaque projet sur [pub.dev](https://pub.dev) et [PyPI](https://pypi.org) ; vérifiez-les avant toute redistribution.

## 5. Engagement Open Source

Le code de Yaarexbook est publié sous **licence Apache 2.0** (fichier `LICENSE`) : il peut être utilisé, modifié et redistribué, avec mention des auteurs. Le dépôt est public sur GitHub : https://github.com/Mohamine226/Yaarexbook. Les contributions (corrections, traductions, idées) sont les bienvenues via des *issues* et des *pull requests*.

**État d'avancement.** Prototype fonctionnel de bout en bout : inscription avec code par email, connexion, mot de passe oublié, profil, publication de PDF avec couverture, catégories, recherche, fils « Pour vous » et « Abonnements », mentions j'aime, commentaires, abonnements, bibliothèque chiffrée, gestion des appareils, administration. Le serveur est couvert par 39 tests automatiques ; l'application a été testée à la main sur Android et dans un navigateur.

## 6. Installation et lancement

**Prérequis :** Python 3.10 ou plus, Flutter (SDK Dart 3.5 ou plus), Android Studio pour Android.

**Serveur** (dossier `lapi`) :

```bash
cd lapi
python -m venv .venv
.venv\Scripts\activate          # Windows  (Linux/Mac : source .venv/bin/activate)
pip install -r requirements.txt
cp .env.example .env            # Windows : copy .env.example .env
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Documentation interactive de l'API : http://localhost:8000/docs. Le premier administrateur est créé au premier démarrage avec `ADMIN_EMAIL` et `ADMIN_PASSWORD` du fichier `.env` (**changez le mot de passe par défaut**). Pour recréer ou réparer un administrateur : `python reset_admin.py email@exemple.com MotDePasse`. Tests : `pytest`.

**Emails (facultatif).** Dans `.env`, renseignez `BREVO_API_KEY` et `MAIL_FROM_EMAIL`. Sans eux, les codes de vérification s'affichent dans la console du serveur.

**Application** (racine du projet) :

```bash
flutter pub get
flutter run
```

L'adresse du serveur se règle depuis l'écran de connexion : `http://10.0.2.2:8000` pour l'émulateur Android, `http://<IP de l'ordinateur>:8000` pour un vrai téléphone sur le même réseau Wi-Fi.

## 7. Limites connues

- Serveur non hébergé : l'application fonctionne pour l'instant sur réseau local, sans HTTPS.
- Blocage des captures d'écran **limité à Android** ; impossible sur le web, non traité sur iPhone. Aucune protection ne peut empêcher de photographier l'écran.
- Documents au format **PDF uniquement** (pas de conversion Word).
- Bibliothèque hors connexion **indisponible sur le web**.
- Pas encore de notifications, de signalement de contenus par les utilisateurs ni de filigrane.
- SQLite et sauvegardes manuelles : suffisant pour un prototype, à faire évoluer pour une forte charge.
- Application non compilée ni testée sur iPhone ; pas de tests automatiques côté application.

## 8. Démonstration vidéo

[https://youtube.com/shorts/jLg9ocpxTeE?feature=share]