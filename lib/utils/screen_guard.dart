import 'package:flutter/services.dart';

/// Bloque les captures d'écran (Android : FLAG_SECURE) pendant la lecture.
/// Sans le code natif de MainActivity (voir README), les appels sont ignorés.
class ScreenGuard {
  static const _channel = MethodChannel('yaarexbook/screen');

  static Future<void> setSecure(bool on) async {
    try {
      await _channel.invokeMethod('setSecure', on);
    } on MissingPluginException {
      // Pas de code natif : la lecture fonctionne, sans blocage des captures.
    } on PlatformException {
      // idem
    }
  }
}
