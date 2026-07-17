# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Olib (`olib_mobile`) is a Flutter-based Z-Library client app. It supports Android, iOS, Windows, macOS, Linux, and Web. The UI and commit messages are primarily in Chinese.

## Build & Run Commands

```bash
flutter pub get                  # Install dependencies
flutter run                      # Run debug build
flutter build apk --release      # Build release APK
dart run msix:create             # Build Windows MSIX package
dart run flutter_launcher_icons  # Regenerate app icons
flutter analyze                  # Run linter

# Code generation (freezed, json_serializable) — required after cloning or modifying models
dart run build_runner build --delete-conflicting-outputs

# Override backend URLs
flutter run --dart-define=BACKEND_URL=https://... --dart-define=AUTH_URL=https://...
```

Generated files (`*.freezed.dart`, `*.g.dart`) are gitignored and must be regenerated locally.

There are no meaningful unit/widget tests. The `test/` directory contains API debugging scripts and is gitignored.

## Architecture

**Layered organization** in `lib/`:

- **`services/`** — API clients and storage. `ZLibraryApi` (Dio + cookie auth) talks to Z-Library's `/eapi/` and `/papi/` endpoints. `BackendApi` and `AiService` (Dio + JWT Bearer) talk to the project's own backends. Services return raw `Map<String, dynamic>`.
- **`providers/`** — Riverpod state management. `StateNotifierProvider` for mutable state (auth, downloads, domain selection, settings). `FutureProvider` / `FutureProvider.family` for async data (search, book details, popular lists). Providers parse raw maps into typed models.
- **`screens/`** — UI pages, each a `ConsumerWidget` or `ConsumerStatefulWidget`.
- **`models/`** — `Book` and `User` use freezed + json_serializable. Other models (`ReadingBag`, `ReadingTip`, `ApiResponse`) are hand-written.
- **`widgets/`** — Shared reusable UI components.

**State management**: Riverpod (classic hand-written providers, not `@riverpod` annotation style).

**Routing**: Named routes via `MaterialApp.routes`. Route constants in `lib/routes/app_routes.dart`. The `reader` route expects `ReaderArgs` via route arguments.

**Local storage**: Hive with two boxes — `settings` (theme, locale, domain, downloads, favorites) and `auth` (credentials, saved accounts, backend JWT).

**Internationalization**: Custom hand-rolled system (not `intl` ARB). Translation files are Dart `Map<String, String>` in `lib/l10n/translations/` (16 locales). Usage: `AppLocalizations.of(context).get('key')`.

## Key Patterns

- `ZLibraryApi` uses lazy async init (`_initFuture`) — all methods await it before proceeding.
- Domain/mirror switching updates Dio's base URL at runtime; speed testing is in `SpeedTestNotifier`.
- Multi-account support: `AuthStorage` persists multiple credential sets in the Hive `auth` box.
- Backend environment URLs are configurable via `--dart-define` (see `lib/config/env.dart`).
- Ads integration exists (Unity Ads) but is globally disabled (`AdService.adsEnabled = false`).

## Repo Notes

- `olib-api/` is a separate Python project (own git repo) for API scraping tools — not part of the Flutter build.
- Android build uses China-based Maven mirrors (configured in `android/build.gradle.kts`).
- Requires Dart SDK ^3.8.1 / Flutter 3.8+. Android minSdk 23, compileSdk 36.
