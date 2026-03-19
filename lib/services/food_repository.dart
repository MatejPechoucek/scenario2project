import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../database/db_helper.dart';
import '../database/food_item.dart';
import 'usda_api_service.dart';

/// Single point of contact for all food lookups in CleanEater.
///
/// Lookup order:
///   1. In-memory cache of bundled foods (base_foods.json) — instant, offline.
///   2. SQLite food_cache — persisted results from prior API calls.
///   3. USDA FoodData Central API — live, requires internet.
///
/// The UI layer should always use this class, never call UsdaApiService
/// or DbHelper directly for food lookups.
///
/// Call [initialize] once before using — it loads the bundled asset into
/// memory. Calling [initialize] multiple times is safe (idempotent).
class FoodRepository {
  FoodRepository._();

  static List<FoodItem> _baseFoods = [];
  static bool _initialized = false;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Loads the bundled base_foods.json asset into memory.
  /// Must be called once at app startup (or before first search).
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/base_foods.json');
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      _baseFoods = jsonList
          .whereType<Map<String, dynamic>>()
          .map(FoodItem.fromJson)
          .toList();
    } catch (e) {
      // Asset load failed — app continues with empty base, API still works.
      _baseFoods = [];
    }
    _initialized = true;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns all 250 bundled foods.
  /// Used by [NutritionalProximityAlgorithm] to build the candidate pool.
  static Future<List<FoodItem>> getAllBaseFoods() async {
    await initialize();
    return List.unmodifiable(_baseFoods);
  }

  /// Searches for foods matching [query].
  ///
  /// Steps:
  ///   1. Filter bundled foods locally (case-insensitive substring match).
  ///   2. If ≥5 local results: return top 10 local.
  ///   3. Else: check SQLite cache, then hit USDA API.
  ///      Merge and deduplicate results; cache API results for 24h.
  static Future<List<FoodItem>> searchFoods(String query) async {
    await initialize();

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    // 1. Local search.
    final localResults = _baseFoods
        .where((f) => f.name.toLowerCase().contains(q) ||
            f.category.toLowerCase().contains(q))
        .toList();

    if (localResults.length >= 5) {
      return localResults.take(10).toList();
    }

    // 2. SQLite cache.
    final cached = await DbHelper.searchCachedFoods(q);
    final combined = _merge(localResults, cached);
    if (combined.length >= 5) {
      return combined.take(10).toList();
    }

    // 3. USDA API.
    final apiResults = await UsdaApiService.searchFoods(q);
    if (apiResults.isNotEmpty) {
      await DbHelper.cacheFoodItems(apiResults);
    }

    return _merge(combined, apiResults).take(10).toList();
  }

  /// Finds foods by category. Only searches the bundled base foods.
  static Future<List<FoodItem>> getFoodsByCategory(String category) async {
    await initialize();
    return _baseFoods
        .where((f) => f.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  /// Returns a list of all distinct categories in the bundled food bank.
  static Future<List<String>> getCategories() async {
    await initialize();
    final cats = _baseFoods.map((f) => f.category).toSet().toList();
    cats.sort();
    return cats;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Merges two lists of [FoodItem]s, deduplicating by ID.
  /// Items from [primary] take precedence.
  static List<FoodItem> _merge(
      List<FoodItem> primary, List<FoodItem> secondary) {
    final seen = <String>{};
    final result = <FoodItem>[];
    for (final item in [...primary, ...secondary]) {
      if (seen.add(item.id)) {
        result.add(item);
      }
    }
    return result;
  }
}
