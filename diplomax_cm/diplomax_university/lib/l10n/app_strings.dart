import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('fr'), Locale('en')];
  static const delegate = _AppStringsDelegate();

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static AppStrings of(BuildContext context) {
    final value = Localizations.of<AppStrings>(context, AppStrings);
    assert(value != null, 'AppStrings not found in the widget tree.');
    return value!;
  }

  bool get isFrench => locale.languageCode == 'fr';

  String tr(String fr, String en) => isFrench ? fr : en;

  String get appName =>
      isFrench ? 'Diplomax CM — Université' : 'Diplomax CM — University';
  String get signIn => isFrench ? 'Se connecter' : 'Sign in';
  String get login => isFrench ? 'Connexion' : 'Login';
  String get register => isFrench ? 'Inscription' : 'Register';
  String get dashboard => isFrench ? 'Tableau de bord' : 'Dashboard';
  String get students => isFrench ? 'Étudiants' : 'Students';
  String get documents => isFrench ? 'Documents' : 'Documents';
  String get issueDocument =>
      isFrench ? 'Émettre un document' : 'Issue document';
  String get requests => isFrench ? 'Demandes' : 'Requests';
  String get ministry => isFrench ? 'Ministère' : 'Ministry';
  String get logout => isFrench ? 'Se déconnecter' : 'Logout';
  String get language => isFrench ? 'Langue' : 'Language';
  String get chooseLanguage =>
      isFrench ? 'Choisir la langue' : 'Choose language';
  String get french => isFrench ? 'Français' : 'French';
  String get english => isFrench ? 'Anglais' : 'English';
  String get switchLanguageHint =>
      isFrench ? 'Appuyez pour changer de langue' : 'Tap to switch language';
  String get universityPortal =>
      isFrench ? 'Portail universite' : 'University Portal';
  String get signInSubtitle => isFrench
      ? 'Emettez, signez et gerez les documents academiques.'
      : 'Issue, sign, and manage academic documents.';
  String get emailAddress => isFrench ? 'Adresse e-mail' : 'Email address';
  String get emailHint =>
      isFrench ? 'admin@votreuniversite.cm' : 'admin@ictuniversity.cm';
  String get password => isFrench ? 'Mot de passe' : 'Password';
  String get yourPassword => isFrench ? 'Votre mot de passe' : 'Your password';
  String get enterEmailAndPassword =>
      isFrench ? 'Entrez e-mail et mot de passe' : 'Enter email and password';
  String get invalidEmailOrPassword => isFrench
      ? 'E-mail ou mot de passe invalide'
      : 'Invalid email or password';
  String get connectionFailedNetwork => isFrench
      ? 'Connexion echouee. Verifiez votre reseau.'
      : 'Connection failed. Check network.';
  String get newInstitutionRegisterHere => isFrench
      ? 'Nouvelle institution ? Inscrivez-vous ici'
      : 'New institution? Register here';
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales
      .any((supported) => supported.languageCode == locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(AppStrings(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}

AppStrings t(BuildContext context) => AppStrings.of(context);
