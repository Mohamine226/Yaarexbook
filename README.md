# Yaarexbook

Réseau social de partage de documents : tout le monde peut publier un PDF, suivre des personnes,
aimer et commenter, et garder ses documents dans une bibliothèque lisible hors ligne.

```
assets/        images de l'app
lib/           application Flutter (Android / iOS)
lapi/          API FastAPI + SQLite
pubspec.yaml
```

## 1. Lancer le serveur

```bash
cd lapi
python -m venv venv && source venv/bin/activate      # facultatif
pip install -r requirements.txt
cp .env.example .env                                  # puis éditez ADMIN_EMAIL / ADMIN_PASSWORD
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- Toutes les tables sont créées au démarrage dans `lapi/data/yaarexbook.db` (SQLite). Aucune migration.
- Les PDF sont dans `lapi/data/uploads/pdfs` (jamais publics), les couvertures dans `uploads/covers`.
- Le premier administrateur est créé depuis `ADMIN_EMAIL` / `ADMIN_PASSWORD` (changez le mot de passe !).
- Mot de passe oublié : le code à 6 chiffres s'affiche dans la console du serveur, sauf si `SMTP_*` est configuré.
- Documentation interactive : http://localhost:8000/docs
- Tests : `pytest` (35 tests).

## 2. Lancer l'application

Les dossiers `android/` et `ios/` ne sont pas fournis : copiez `lib/`, `assets/` et `pubspec.yaml` dans un projet
Flutter (`flutter create yaarexbook`), puis :

```bash
flutter pub get
flutter run
```

Sur l'écran de connexion, appuyez sur **Serveur** pour saisir l'adresse de l'API :

| Cas | Adresse |
|---|---|
| Émulateur Android | `http://10.0.2.2:8000` (défaut) |
| Téléphone sur le même Wi-Fi | `http://IP-DU-PC:8000` |

### Réglages Android obligatoires (HTTP non chiffré)

Dans `android/app/src/main/AndroidManifest.xml` :

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<application android:usesCleartextTraffic="true" ...>
```

`flutter_secure_storage` demande `minSdkVersion 23` (`android/app/build.gradle`).
Sur iOS, autorisez HTTP dans `Info.plist` (`NSAppTransportSecurity` → `NSAllowsArbitraryLoads`).

## Multi-appareils

Chaque connexion crée une session propre à l'appareil : le même compte peut être connecté sur plusieurs
téléphones en même temps. Se déconnecter n'affecte que l'appareil courant. Réglages → « Mes appareils »
permet de voir et déconnecter les autres. Changer ou réinitialiser le mot de passe déconnecte les autres appareils.

## Blocage des captures d'écran (facultatif, Android)

Le plugin `screen_protector` ne compile pas avec les versions récentes d'Android Gradle Plugin ; il est remplacé par un
canal natif. Sans la modification ci-dessous, l'app fonctionne normalement, mais les captures ne sont pas bloquées.

Dans `android/app/src/main/kotlin/com/example/yaarexbook/MainActivity.kt` :

```kotlin
package com.example.yaarexbook

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yaarexbook/screen")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    if (call.arguments as? Boolean == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else result.notImplemented()
            }
    }
}
```
