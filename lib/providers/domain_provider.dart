import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hive_service.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import 'auth_provider.dart';
import 'books_provider.dart';
import 'zlibrary_provider.dart';

/// All available mirror domains (flat list).
final domainListProvider = Provider<List<String>>((ref) {
  const base = [
    'zlibraryf.online',
    'zlibraryh.online',
    'free2read.cc',
    'zlibraryd.online',
    'zlibrary6.online',
    'zlibraryg.online',
    '26h2.tech',
    '777495.best',
    'freezlib.me',
    'sibaihua.pro',
    '86110101.xyz',
    'umq.me',
    'pkuedu.online',
    'loves.works',
    'adsblaze.com',
    '101intj.ru',
    'zkoo.site',
    '101w.online',
    'zlibraryj.online',
    'biblioteca.pro',
    'toffeeboba.com',
  ];
  return base;
});

final domainProvider = StateNotifierProvider<DomainNotifier, String>((ref) {
  final api = ref.watch(zlibraryApiProvider);
  return DomainNotifier(api, ref);
});

class DomainNotifier extends StateNotifier<String> {
  final ZLibraryApi _api;
  final Ref _ref;

  DomainNotifier(this._api, this._ref)
      : super(HiveService.settingsBox.get('domain', defaultValue: 'pkuedu.online')) {
    // Ensure API is in sync with initial state (no side effects: auth init
    // handles cookie setup on first boot).
    _api.setDomain(state);
  }

  /// Switch to a new line. Fire-and-forget: callers don't need to await.
  /// Internally we re-establish cookies on the new domain (reverify) and
  /// invalidate data providers so they refetch against the new line.
  void setDomain(String domain) {
    if (domain == state) return;
    state = domain;
    HiveService.settingsBox.put('domain', domain);
    _api.setDomain(domain);
    _refreshAfterSwitch();
  }

  void setCustomDomain(String domain) {
    String cleanDomain = domain.replaceAll(RegExp(r'^https?://'), '');
    if (cleanDomain.endsWith('/')) {
      cleanDomain = cleanDomain.substring(0, cleanDomain.length - 1);
    }
    setDomain(cleanDomain);
  }

  Future<void> _refreshAfterSwitch() async {
    // Cookies are domain-scoped — re-issue remix_userid/remix_userkey on the
    // new domain and re-fetch profile. This also clears the lineUnavailable
    // flag on success.
    await _ref.read(authProvider.notifier).reverify();
    // Bust caches for anything that depends on the line. List individual
    // providers explicitly so adding a new one is a deliberate decision.
    _ref.invalidate(recommendedBooksProvider);
    _ref.invalidate(mostPopularBooksProvider);
    _ref.invalidate(recentBooksProvider);
    _ref.invalidate(downloadedBooksProvider);
    _ref.invalidate(savedBooksProvider);
  }
}
