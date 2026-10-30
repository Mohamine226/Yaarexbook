import 'package:flutter/foundation.dart';

/// Incrémenté après une publication : le fil et le profil se rafraîchissent.
final ValueNotifier<int> publishedTick = ValueNotifier<int>(0);

/// Incrémenté quand la bibliothèque change depuis un autre écran.
final ValueNotifier<int> libraryTick = ValueNotifier<int>(0);
