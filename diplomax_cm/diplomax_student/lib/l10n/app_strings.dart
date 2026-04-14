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
  String get secureAcademicCredentials => isFrench
      ? 'Identifiants académiques sécurisés'
      : 'Secure Academic Credentials';
  String get continueToSignIn =>
      isFrench ? 'Continuer vers la connexion' : 'Continue to sign in';
  String get signIn => isFrench ? 'Se connecter' : 'Sign in';
  String get studentPortal => isFrench ? 'Portail étudiant' : 'Student Portal';
  String get welcomeBack => isFrench ? 'Bon retour' : 'Welcome back';
  String get loginIntro => isFrench
      ? 'Entrez votre matricule universitaire pour acceder a votre coffre-fort.'
      : 'Enter your university matricule to access your vault.';
  String get universityMatricule =>
      isFrench ? 'Matricule universitaire' : 'University matricule';
  String get enterYourMatricule =>
      isFrench ? 'Entrez votre matricule' : 'Enter your matricule';
  String get matriculeTooShort =>
      isFrench ? 'Matricule trop court' : 'Matricule too short';
  String get yourPassword => isFrench ? 'Votre mot de passe' : 'Your password';
  String get enterYourPassword =>
      isFrench ? 'Entrez votre mot de passe' : 'Enter your password';
  String get passwordTooShort =>
      isFrench ? 'Mot de passe trop court' : 'Password too short';
  String get invalidCredentials => isFrench
      ? 'Matricule ou mot de passe incorrect.'
      : 'Incorrect matricule or password.';
  String get accountDeactivated => isFrench
      ? 'Votre compte a ete desactive. Contactez votre universite.'
      : 'Your account has been deactivated. Contact your university.';
  String get connectionTimeout => isFrench
      ? 'Connexion expiree. Verifiez votre internet.'
      : 'Connection timed out. Check your internet connection.';
  String get tooManyAttempts => isFrench
      ? 'Trop de tentatives. Veuillez patienter avant de reessayer.'
      : 'Too many attempts. Please wait before trying again.';
  String get connectionFailed => isFrench
      ? 'Connexion au serveur impossible. Veuillez reessayer.'
      : 'Could not connect to the server. Please try again.';
  String get signInSubtitle => isFrench
      ? 'Accédez à votre espace en toute sécurité.'
      : 'Access your account securely.';
  String get emailOrMatricule =>
      isFrench ? 'E-mail ou matricule' : 'Email or matricule';
  String get password => isFrench ? 'Mot de passe' : 'Password';
  String get login => isFrench ? 'Connexion' : 'Login';
  String get logout => isFrench ? 'Se déconnecter' : 'Logout';
  String get language => isFrench ? 'Langue' : 'Language';
  String get chooseLanguage =>
      isFrench ? 'Choisir la langue' : 'Choose language';
  String get french => isFrench ? 'Français' : 'French';
  String get english => isFrench ? 'Anglais' : 'English';
  String get currentLanguage => isFrench ? 'FR' : 'EN';
  String get dashboard => isFrench ? 'Tableau de bord' : 'Dashboard';
  String get documents => isFrench ? 'Documents' : 'Documents';
  String get vault => isFrench ? 'Coffre-fort' : 'Vault';
  String get search => isFrench ? 'Recherche' : 'Search';
  String get qrGenerate => isFrench ? 'Générer QR' : 'Generate QR';
  String get qrScan => isFrench ? 'Scanner QR' : 'Scan QR';
  String get nfc => 'NFC';
  String get ocr => 'OCR';
  String get liveness => isFrench ? 'Vérification de présence' : 'Liveness';
  String get share => isFrench ? 'Partager' : 'Share';
  String get payment => isFrench ? 'Paiement' : 'Payment';
  String get profile => isFrench ? 'Profil' : 'Profile';
  String get requests => isFrench ? 'Demandes' : 'Requests';
  String get internationalShare =>
      isFrench ? 'Partage international' : 'International share';
  String get switchLanguageHint =>
      isFrench ? 'Appuyez pour changer de langue' : 'Tap to switch language';

  // Document Detail Screen
  String get failedToLoadDocument => isFrench
      ? 'Impossible de charger le document'
      : 'Failed to load document';
  String get documentAuthenticated =>
      isFrench ? 'Document authentifié' : 'Document authenticated';
  String get university => isFrench ? 'Université' : 'University';
  String get diplomaLabel => isFrench ? 'Diplôme' : 'Diploma';
  String get mention => isFrench ? 'Mention' : 'Mention';
  String get issueDate => isFrench ? 'Date d\'émission' : 'Issue date';
  String get certificateLabel => isFrench ? 'Certificat' : 'Certificate';
  String get attestationLabel => isFrench ? 'Attestation' : 'Attestation';
  String get transcriptLabel => isFrench ? 'Relevé de notes' : 'Transcript';
  String get registrationNumber =>
      isFrench ? 'Matricule' : 'Registration number';
  String get documentReference => isFrench ? 'Réf. document' : 'Document ref.';
  String get information => isFrench ? 'Informations' : 'Information';
  String get gradesReport => isFrench ? 'Relevé de notes' : 'Grades report';
  String get average => isFrench ? 'Moy.' : 'Avg.';
  String get gradeOutOf => '/20';
  String get cryptographicFingerprint =>
      isFrench ? 'Empreinte cryptographique' : 'Cryptographic fingerprint';
  String get hashCopied => isFrench ? 'Hash copié !' : 'Hash copied!';
  String get e2eEncryption => isFrench ? 'Chiffrement E2EE' : 'E2E Encryption';
  String get zeroKnowledgeProof =>
      isFrench ? 'Zero-Knowledge Proof' : 'Zero-Knowledge Proof';
  String get tamperProof => isFrench
      ? 'Anti-altération (Hash SHA-256)'
      : 'Tamper-proof (Hash SHA-256)';
  String get qrCodeSharing =>
      isFrench ? 'QR Code de partage' : 'QR Code for sharing';
  String get codeValidSingleUse => isFrench
      ? 'Code valable 24h · Usage unique'
      : 'Code valid 24h · Single use';
  String get generateDynamicQRCode =>
      isFrench ? 'Générer un QR Code dynamique' : 'Generate a dynamic QR Code';
  String get validateViaNCF =>
      isFrench ? 'Valider via NFC' : 'Validate via NFC';
  String get active => isFrench ? 'Actif' : 'Active';
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
