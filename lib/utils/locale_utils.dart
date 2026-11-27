import 'package:flutter/material.dart';

/// Check if current locale is Chinese
bool isZhLocale(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'zh';
}

/// Get locale key for comparison (e.g., 'en', 'zh')
String? getLocaleKey(Locale? locale) {
  if (locale == null) return null;
  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    return '${locale.languageCode}_${locale.countryCode}';
  }
  return locale.languageCode;
}

/// Parse locale key to Locale object
Locale? parseLocaleKey(String? key) {
  if (key == null) return null;
  final parts = key.split('_');
  if (parts.length == 2) {
    return Locale(parts[0], parts[1]);
  }
  return Locale(parts[0]);
}

/// Get localized text with fallback
String getLocalizedText(BuildContext context, String zhText, String enText) {
  return isZhLocale(context) ? zhText : enText;
}
