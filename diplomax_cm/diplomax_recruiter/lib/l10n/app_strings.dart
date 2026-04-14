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

  String get appName => 'Diplomax CM';
  String get recruiterPortal =>
      isFrench ? 'Portail recruteur' : 'Recruiter Portal';
  String get signIn => isFrench ? 'Se connecter' : 'Sign in';
  String get createAccount => isFrench ? 'Créer un compte' : 'Create account';
  String get createRecruiterAccount =>
      isFrench ? 'Créer un compte recruteur' : 'Create recruiter account';
  String get companyName => isFrench ? 'Nom de l’entreprise' : 'Company name';
  String get companyEmail =>
      isFrench ? 'E-mail de l’entreprise' : 'Company email';
  String get phoneOptional =>
      isFrench ? 'Téléphone (facultatif)' : 'Phone (optional)';
  String get password => isFrench ? 'Mot de passe' : 'Password';
  String get confirmPassword =>
      isFrench ? 'Confirmer le mot de passe' : 'Confirm password';
  String get invalidCredentials =>
      isFrench ? 'Identifiants invalides' : 'Invalid credentials';
  String get connectionFailed =>
      isFrench ? 'Connexion échouée' : 'Connection failed';
  String get newRecruiter =>
      isFrench ? 'Nouveau recruteur ?' : 'New recruiter?';
  String get accountCreated => isFrench
      ? 'Compte créé. Vous avez maintenant 5 vérifications gratuites/mois.'
      : 'Account created. You now have 5 free verifications/month.';
  String get freeTierInfo => isFrench
      ? 'L’inscription est instantanée. Le forfait gratuit inclut 5 vérifications/mois.'
      : 'Self-registration is instant. Free tier includes 5 verifications/month.';
  String get dashboard => isFrench ? 'Tableau de bord' : 'Dashboard';
  String get scan => 'Scan';
  String get logout => isFrench ? 'Se déconnecter' : 'Logout';
  String get authentic => isFrench ? 'Authentique' : 'Authentic';
  String get failed => isFrench ? 'Échec' : 'Failed';
  String get total => isFrench ? 'Total' : 'Total';
  String get chooseLanguage =>
      isFrench ? 'Choisir la langue' : 'Choose language';
  String get language => isFrench ? 'Langue' : 'Language';
  String get french => isFrench ? 'Français' : 'French';
  String get english => isFrench ? 'Anglais' : 'English';
  String get switchLanguageHint =>
      isFrench ? 'Appuyez pour changer de langue' : 'Tap to switch language';
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
