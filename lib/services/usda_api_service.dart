import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../database/food_item.dart';

/// Communicates with the USDA FoodData Central REST API.
///
/// Documentation: https://app.swaggerhub.com/apis/fdcnal/food-data_central_api/1.0.1
///
/// Usage:
///   final results = await UsdaApiService.searchFoods('salmon');
///   final detail  = await UsdaApiService.getFoodById(175167);
///
/// All methods return an empty list / null on error — they never throw,
/// keeping the UI layer simple.
class UsdaApiService {
  static const Duration _timeout = Duration(seconds: 10);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Searches for foods matching [query].
  ///
  /// Strategy: queries Foundation + SR Legacy data types first (these have
  /// complete micronutrient data). Returns up to [pageSize] results.
  ///
  /// Falls back to Branded data if fewer than 3 Foundation/SR Legacy items
  /// are returned (branded foods are common but often lack micro data).
  static Future<List<FoodItem>> searchFoods(
    String query, {
    int pageSize = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // Primary search: Foundation + SR Legacy (scientific, complete data).
    final primary = await _search(trimmed,
        dataTypes: 'Foundation,SR%20Legacy', pageSize: pageSize);

    if (primary.length >= 3) return primary.take(pageSize).toList();

    // Supplement with Branded if primary results are sparse.
    final branded = await _search(trimmed,
        dataTypes: 'Branded', pageSize: pageSize - primary.length);

    return [...primary, ...branded].take(pageSize).toList();
  }

  /// Fetches full nutritional detail for a specific food by its USDA fdcId.
  /// Returns null if not found or on any error.
  static Future<FoodItem?> getFoodById(int fdcId) async {
    final uri = Uri.parse(
        '$kUsdaBaseUrl/food/$fdcId?api_key=$kUsdaApiKey&format=abridged');
    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseSingleFood(json);
    } catch (_) {
      return null;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static Future<List<FoodItem>> _search(
    String query, {
    required String dataTypes,
    required int pageSize,
  }) async {
    if (pageSize <= 0) return [];
    final uri = Uri.parse(
      '$kUsdaBaseUrl/foods/search'
      '?query=${Uri.encodeQueryComponent(query)}'
      '&api_key=$kUsdaApiKey'
      '&pageSize=$pageSize'
      '&dataType=$dataTypes',
    );
    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final foods = (json['foods'] as List<dynamic>?) ?? [];
      return foods
          .whereType<Map<String, dynamic>>()
          .map(_parseSearchFood)
          .whereType<FoodItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Parses a single food item from the /foods/search response.
  /// The search endpoint returns a flat `foodNutrients` list with
  /// `nutrientId` and `value` fields.
  static FoodItem? _parseSearchFood(Map<String, dynamic> food) {
    try {
      final fdcId = food['fdcId'] as int;
      final description = (food['description'] as String?) ?? 'Unknown';
      final category = (food['foodCategory'] as String?) ?? 'General';

      // Build nutrientId -> value map from the flat array.
      final rawNutrients =
          (food['foodNutrients'] as List<dynamic>?) ?? [];
      final nutrientMap = <int, double>{};
      for (final n in rawNutrients) {
        if (n is Map<String, dynamic>) {
          final id = n['nutrientId'] as int?;
          final value = (n['value'] as num?)?.toDouble();
          if (id != null && value != null) {
            nutrientMap[id] = value;
          }
        }
      }

      return FoodItem.fromUsdaJson(
        fdcId: fdcId,
        description: description,
        foodCategory: category,
        nutrientMap: nutrientMap,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parses a single food item from the /food/{fdcId} detail endpoint.
  /// The detail endpoint returns a `foodNutrients` list with nested
  /// `nutrient.id` and `amount` fields (different structure from search).
  static FoodItem? _parseSingleFood(Map<String, dynamic> food) {
    try {
      final fdcId = food['fdcId'] as int;
      final description = (food['description'] as String?) ?? 'Unknown';
      final category = (food['foodCategory'] as String?) ?? 'General';

      final rawNutrients =
          (food['foodNutrients'] as List<dynamic>?) ?? [];
      final nutrientMap = <int, double>{};
      for (final n in rawNutrients) {
        if (n is Map<String, dynamic>) {
          final nutrient = n['nutrient'] as Map<String, dynamic>?;
          final id = nutrient?['id'] as int?;
          final value = (n['amount'] as num?)?.toDouble();
          if (id != null && value != null) {
            nutrientMap[id] = value;
          }
        }
      }

      return FoodItem.fromUsdaJson(
        fdcId: fdcId,
        description: description,
        foodCategory: category,
        nutrientMap: nutrientMap,
      );
    } catch (_) {
      return null;
    }
  }
}
