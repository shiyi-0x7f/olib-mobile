import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hive_service.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import 'auth_provider.dart';
import 'books_provider.dart';
import 'zlibrary_provider.dart';

const defaultDomain = 'bookroom.lifestyle';
const _retiredBuiltInDomains = {
  'zlibraryf.online',
  'zlibraryh.online',
  'zlibraryd.online',
  'zlibrary6.online',
  'zlibraryg.online',
  '777495.best',
  'freezlib.me',
  'sibaihua.pro',
  'pkuedu.online',
  '101intj.ru',
  '101w.online',
  'zlibraryj.online',
  'biblioteca.pro',
};

/// All available mirror domains (flat list).
final domainListProvider = Provider<List<String>>((ref) {
  const base = [
    'bookroom.lifestyle',
    'bibliotheca.world',
    'bibliotheca.study',
    'bibliotheca.lifestyle',
    'luto.top',
    'bibliotheca.life',
    'anthology.lifestyle',
    'elaborate.monster',
    's0u1.top',
    '26h2.tech',
    'orangerain.space',
    'zouwu.top',
    'xn--t8j0bxa8hymnb.jp',
    '553211.xyz',
    'loves.works',
    'z-library.im',
    'ireadhuang.sbs',
    'elaborate.quest',
    'elaborate.wtf',
    '9libmirror.tech',
    'shunfei.shop',
    'elaboratethinking.online',
    'bookorg.tech',
    'booook.me',
    '95427279.xyz',
    'zkoo.site',
    'adsblaze.com',
    '817523.xyz',
    'toffeeboba.com',
    'interflow.ch',
    'free2read.cc',
    '8964520.xyz',
    'umq.me',
    '110434.xyz',
    'frank9527.site',
    'freebooks.lol',
    '226272.xyz',
    'jdbooks.xyz',
    'arcfoxxxxxx.site',
    '86110101.xyz',
    '909190.xyz',
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

  DomainNotifier(this._api, this._ref) : super(_initialDomain()) {
    if (HiveService.settingsBox.get('domain') != state) {
      HiveService.settingsBox.put('domain', state);
    }
    // Ensure API is in sync with initial state (no side effects: auth init
    // handles cookie setup on first boot).
    _api.setDomain(state);
  }

  static String _initialDomain() {
    final saved = HiveService.settingsBox.get('domain') as String?;
    if (saved == null || _retiredBuiltInDomains.contains(saved)) {
      return defaultDomain;
    }
    return saved;
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
    _ref.invalidate(bookDetailsProvider);
    _ref.invalidate(recommendedBooksProvider);
    _ref.invalidate(mostPopularBooksProvider);
    _ref.invalidate(recentBooksProvider);
    _ref.invalidate(downloadedBooksProvider);
    _ref.invalidate(savedBooksProvider);
  }
}
