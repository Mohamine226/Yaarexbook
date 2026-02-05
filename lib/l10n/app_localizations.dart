import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @accueil.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get accueil;

  /// No description provided for @categorie.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categorie;

  /// No description provided for @fichiers.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get fichiers;

  /// No description provided for @profil.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profil;

  /// No description provided for @parametres.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get parametres;

  /// No description provided for @compte.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get compte;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @securite.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securite;

  /// No description provided for @langue.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get langue;

  /// No description provided for @aide.
  ///
  /// In en, this message translates to:
  /// **'Help and feedback'**
  String get aide;

  /// No description provided for @maj.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get maj;

  /// No description provided for @apropos.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get apropos;

  /// No description provided for @modifier.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get modifier;

  /// No description provided for @annuler.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get annuler;

  /// No description provided for @enregistrer.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get enregistrer;

  /// No description provided for @misAJour.
  ///
  /// In en, this message translates to:
  /// **'updated'**
  String get misAJour;

  /// No description provided for @nonRenseigne.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get nonRenseigne;

  /// No description provided for @activerOuDesactiver.
  ///
  /// In en, this message translates to:
  /// **'Enable or disable notifications'**
  String get activerOuDesactiver;

  /// No description provided for @changerMotDePasse.
  ///
  /// In en, this message translates to:
  /// **'Change password, enable 2FA'**
  String get changerMotDePasse;

  /// No description provided for @envoyerFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback or check help'**
  String get envoyerFeedback;

  /// No description provided for @verifierMaj.
  ///
  /// In en, this message translates to:
  /// **'Check for available updates'**
  String get verifierMaj;

  /// No description provided for @infosApp.
  ///
  /// In en, this message translates to:
  /// **'Information about Daaga app'**
  String get infosApp;

  /// No description provided for @langueChangee.
  ///
  /// In en, this message translates to:
  /// **'Language changed to'**
  String get langueChangee;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
