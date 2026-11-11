import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hive_service.dart';

/// Hive settings：最近搜索关键词（沿用旧 key）。
const _kRecentKey = 'recent_search_keywords';
const _limit = 12;

/// 最近搜索（跨来源共用，按大小写不敏感去重，最新在前）。
class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super(_load());

  static List<String> _load() {
    final raw = HiveService.settingsBox.get(_kRecentKey);
    if (raw is! List) return const [];
    final seen = <String>{};
    return raw
        .whereType<String>()
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty && seen.add(k.toLowerCase()))
        .take(_limit)
        .toList();
  }

  /// 保存失败时抛出，由界面提示。
  Future<void> remember(String query) {
    final lower = query.toLowerCase();
    return _save(
      [
        query,
        ...state.where((k) => k.toLowerCase() != lower),
      ].take(_limit).toList(),
    );
  }

  Future<void> remove(String keyword) =>
      _save(state.where((k) => k != keyword).toList());

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> next) async {
    state = next;
    await HiveService.settingsBox.put(_kRecentKey, next);
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
      (ref) => RecentSearchesNotifier(),
    );
