import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../services/hive_service.dart';
import '../l10n/app_localizations.dart';

enum AppThemeMode {
  system,
  light,
  dark,
}

/// Theme mode notifier
class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  final StorageService _storage;

  ThemeModeNotifier(this._storage) : super(AppThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final mode = await _storage.getThemeMode();
    state = AppThemeMode.values[mode];
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    await _storage.setThemeMode(mode.index);
  }

  ThemeMode get themeMode {
    switch (state) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
      default:
        return ThemeMode.system;
    }
  }
}

/// Theme mode provider
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier(StorageService());
});

/// Download path notifier for custom download directory (Android only)
class DownloadPathNotifier extends StateNotifier<String?> {
  final StorageService _storage;
  
  DownloadPathNotifier(this._storage) : super(null) {
    _init();
  }
  
  Future<void> _init() async {
    state = await _storage.getDownloadPath();
  }
  
  Future<void> setDownloadPath(String path) async {
    await _storage.setDownloadPath(path);
    state = path;
  }
  
  Future<void> clearDownloadPath() async {
    // Clear by setting empty string, storage will handle deletion
    await _storage.setDownloadPath('');
    state = null;
  }
}

/// Download path provider
final downloadPathProvider = 
    StateNotifierProvider<DownloadPathNotifier, String?>((ref) {
  return DownloadPathNotifier(StorageService());
});

/// Locale notifier for managing app language
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final key = HiveService.settingsBox.get('locale');
    if (key != null && key is String) {
      state = parseLocaleKey(key);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await HiveService.settingsBox.delete('locale');
    } else {
      await HiveService.settingsBox.put('locale', getLocaleKey(locale));
    }
  }

  /// Get display name for current locale
  String getDisplayName() {
    if (state == null) return 'System';
    final key = getLocaleKey(state!);
    return localeDisplayNames[key] ?? key;
  }
}

/// Locale provider
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});
