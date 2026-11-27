import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/unified_shelf_item.dart';
import '../services/hive_service.dart';

class ShelfCategory {
  const ShelfCategory({required this.id, required this.name});

  final String id;
  final String name;
}

class ShelfCategoriesState {
  const ShelfCategoriesState(this.categories, this.assignments);

  final List<ShelfCategory> categories;
  final Map<String, String> assignments;

  String? categoryFor(UnifiedShelfItem item) => assignments[item.categoryKey];

  int countFor(String categoryId, Iterable<UnifiedShelfItem> items) =>
      items.where((item) => categoryFor(item) == categoryId).length;
}

class ShelfCategoriesNotifier extends StateNotifier<ShelfCategoriesState> {
  ShelfCategoriesNotifier() : super(_load());

  static const _storageKey = 'shelf_categories_v1';

  static ShelfCategoriesState _load() {
    final raw = HiveService.settingsBox.get(_storageKey);
    if (raw is! String) return const ShelfCategoriesState([], {});
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final categories = (data['categories'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (value) => ShelfCategory(
              id: value['id'].toString(),
              name: value['name'].toString(),
            ),
          )
          .toList();
      final assignments =
          (data['assignments'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          <String, String>{};
      return ShelfCategoriesState(categories, assignments);
    } catch (error) {
      debugPrint('Could not load shelf categories: ${error.runtimeType}');
      return const ShelfCategoriesState([], {});
    }
  }

  Future<void> _save(ShelfCategoriesState next) async {
    final data = jsonEncode({
      'categories': [
        for (final category in next.categories)
          {'id': category.id, 'name': category.name},
      ],
      'assignments': next.assignments,
    });
    await HiveService.settingsBox.put(_storageKey, data);
    state = next;
  }

  Future<void> create(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty ||
        state.categories.any(
          (category) => category.name.toLowerCase() == cleaned.toLowerCase(),
        )) {
      throw ArgumentError('Duplicate or empty category');
    }
    await _save(
      ShelfCategoriesState([
        ...state.categories,
        ShelfCategory(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: cleaned,
        ),
      ], state.assignments),
    );
  }

  Future<void> rename(String id, String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty ||
        state.categories.any(
          (category) =>
              category.id != id &&
              category.name.toLowerCase() == cleaned.toLowerCase(),
        )) {
      throw ArgumentError('Duplicate or empty category');
    }
    await _save(
      ShelfCategoriesState([
        for (final category in state.categories)
          category.id == id ? ShelfCategory(id: id, name: cleaned) : category,
      ], state.assignments),
    );
  }

  Future<void> delete(String id) async {
    await _save(
      ShelfCategoriesState(
        state.categories.where((category) => category.id != id).toList(),
        Map.of(state.assignments)..removeWhere((_, value) => value == id),
      ),
    );
  }

  Future<void> assign(
    Iterable<UnifiedShelfItem> items,
    String? categoryId,
  ) async {
    if (categoryId != null &&
        !state.categories.any((category) => category.id == categoryId)) {
      throw ArgumentError('Unknown category');
    }
    final assignments = Map<String, String>.of(state.assignments);
    for (final item in items) {
      if (categoryId == null) {
        assignments.remove(item.categoryKey);
      } else {
        assignments[item.categoryKey] = categoryId;
      }
    }
    await _save(ShelfCategoriesState(state.categories, assignments));
  }
}

final shelfCategoriesProvider =
    StateNotifierProvider<ShelfCategoriesNotifier, ShelfCategoriesState>(
      (ref) => ShelfCategoriesNotifier(),
    );
