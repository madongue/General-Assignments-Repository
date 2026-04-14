import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appLocaleControllerProvider = ChangeNotifierProvider<AppLocaleController>(
  (ref) => AppLocaleController(),
);

class AppLocaleController extends ChangeNotifier {
  static const Locale frenchLocale = Locale('fr');
  static const Locale englishLocale = Locale('en');
  static const List<Locale> supportedLocales = [frenchLocale, englishLocale];
  static const String _storageKey = 'diplomax_university_locale';

  Locale _locale = frenchLocale;

  Locale get locale => _locale;
  bool get isFrench => _locale.languageCode == 'fr';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_storageKey);
    _locale = code == englishLocale.languageCode ? englishLocale : frenchLocale;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != frenchLocale.languageCode &&
        locale.languageCode != englishLocale.languageCode) {
      return;
    }

    _locale = Locale(locale.languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _locale.languageCode);
    notifyListeners();
  }

  Future<void> toggle() => setLocale(
        isFrench ? englishLocale : frenchLocale,
      );
}
