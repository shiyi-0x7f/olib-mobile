import 'package:flutter/material.dart';

import 'translations/en.dart' as t_en;
import 'translations/zh.dart' as t_zh;

/// App translations for all supported languages
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': t_en.en,
    'zh': t_zh.zh,
  };

  String get(String key) {
    final langCode = locale.languageCode;
    return _localizedValues[langCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  // Convenience getters
  String get appName => get('app_name');
  String get cancel => get('cancel');
  String get save => get('save');
  String get close => get('close');
  String get login => get('login');
  String get logout => get('logout');
  String get settings => get('settings');
  String get downloads => get('downloads');
  String get favorites => get('favorites');
  String get search => get('search');
  String get home => get('home');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Supported locales
const supportedLocales = [
  Locale('en'),
  Locale('zh'),
];

/// Language display names
const localeDisplayNames = {
  'en': 'English',
  'zh': '简体中文',
};

/// Get locale key for storage
String getLocaleKey(Locale locale) {
  return locale.languageCode;
}

/// Parse locale from key
Locale parseLocaleKey(String key) {
  return Locale(key);
}
