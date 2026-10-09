import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'routes/app_routes.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
// import 'screens/auth/register_screen.dart'; // Registration disabled - API不支持
import 'screens/home/home_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/book_detail/book_detail_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/settings/history_screen.dart';
import 'screens/downloads/local_downloads_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/similar/similar_books_screen.dart';
import 'screens/reader/reader_screen.dart';
import 'screens/prescriber/prescriber_screen.dart';
import 'screens/auth/qr_auth_screen.dart';
import 'screens/weread/weread_home_screen.dart';
import 'screens/weread/weread_book_detail_screen.dart';
import 'services/hive_service.dart';
import 'services/booklist_share_codec.dart';
import 'services/share_intent_handler.dart';
import 'l10n/app_localizations.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget: start listening for shared booklists.
    ref.read(shareIntentHandlerProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    final themeModeState = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // When a shared booklist arrives while we're elsewhere in the app,
    // jump to favorites — that screen consumes the pending data.
    ref.listen<BooklistShareData?>(pendingBooklistImportProvider,
        (prev, next) {
      if (next == null) return;
      final nav = rootNavigatorKey.currentState;
      if (nav == null) return;
      nav.pushNamedAndRemoveUntil(AppRoutes.favorites, (r) => r.isFirst);
    });
    
    // Convert AppThemeMode to ThemeMode
    ThemeMode themeMode;
    switch (themeModeState) {
      case AppThemeMode.light:
        themeMode = ThemeMode.light;
      case AppThemeMode.dark:
        themeMode = ThemeMode.dark;
      case AppThemeMode.system:
        themeMode = ThemeMode.system;
    }

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Olib',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      
      // Localization
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        // AppRoutes.register: (context) => const RegisterScreen(), // Disabled
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.search: (context) => const SearchScreen(),
        AppRoutes.bookDetail: (context) => const BookDetailScreen(),
        AppRoutes.favorites: (context) => const FavoritesScreen(),
        AppRoutes.history: (context) => const HistoryScreen(),
        AppRoutes.downloads: (context) => const LocalDownloadsScreen(),
        AppRoutes.settings: (context) => const SettingsScreen(),
        AppRoutes.similarBooks: (context) => const SimilarBooksScreen(),
        AppRoutes.prescriber: (context) => const PrescriberScreen(),
        AppRoutes.qrAuth: (context) => const QrAuthScreen(),
        AppRoutes.wereadHome: (context) => const WereadHomeScreen(),
        AppRoutes.wereadBookDetail: (context) => const WereadBookDetailScreen(),
        AppRoutes.reader: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as ReaderArgs;
          return ReaderScreen(url: args.url, title: args.title);
        },
      },
    );
  }
}
