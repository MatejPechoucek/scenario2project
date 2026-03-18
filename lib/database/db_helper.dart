import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'food_item.dart';
import 'meal.dart';

/// Manages all local SQLite persistence for CleanEater.
///
/// Database version history:
///   v1 — initial: meals(id, name, description, calories)
///   v2 — added macro/micro columns to meals; added food_cache table
///
/// The food_cache table stores USDA API results with a 24-hour TTL,
/// avoiding redundant network calls during a session or the next day.
class DbHelper {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'diet_plan.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Called on fresh install (no existing database).
  static Future<void> _onCreate(Database db, int version) async {
    await _createMealsTable(db);
    await _createFoodCacheTable(db);
    await _seedMeals(db);
  }

  /// Called when the existing database version < current version.
  /// Handles upgrading from v1 → v2 gracefully.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new macro/micro columns to the existing meals table.
      // SQLite requires individual ALTER TABLE statements per column.
      for (final col in [
        'ALTER TABLE meals ADD COLUMN protein_g REAL DEFAULT 0',
        'ALTER TABLE meals ADD COLUMN fat_g REAL DEFAULT 0',
        'ALTER TABLE meals ADD COLUMN carbs_g REAL DEFAULT 0',
        'ALTER TABLE meals ADD COLUMN sugar_g REAL DEFAULT 0',
        'ALTER TABLE meals ADD COLUMN sodium_mg REAL DEFAULT 0',
        'ALTER TABLE meals ADD COLUMN fiber_g REAL DEFAULT 0',
      ]) {
        await db.execute(col);
      }

      // Backfill the three seeded meals with real nutritional data.
      // Values are approximate totals for a typical serving of each meal.
      await _backfillMealNutrition(db);

      // Create the food cache table (new in v2).
      await _createFoodCacheTable(db);
    }
  }

  // ── Schema helpers ────────────────────────────────────────────────────────

  static Future<void> _createMealsTable(Database db) async {
    await db.execute('''
      CREATE TABLE meals (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL,
        description TEXT NOT NULL,
        calories   INTEGER NOT NULL,
        protein_g  REAL DEFAULT 0,
        fat_g      REAL DEFAULT 0,
        carbs_g    REAL DEFAULT 0,
        sugar_g    REAL DEFAULT 0,
        sodium_mg  REAL DEFAULT 0,
        fiber_g    REAL DEFAULT 0
      )
    ''');
  }

  static Future<void> _createFoodCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_cache (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        category   TEXT,
        calories   REAL DEFAULT 0,
        protein_g  REAL DEFAULT 0,
        fat_g      REAL DEFAULT 0,
        carbs_g    REAL DEFAULT 0,
        sugar_g    REAL DEFAULT 0,
        sodium_mg  REAL DEFAULT 0,
        fiber_g    REAL DEFAULT 0,
        source     TEXT DEFAULT 'usda_api',
        cached_at  INTEGER NOT NULL
      )
    ''');
  }

  // ── Seed data ─────────────────────────────────────────────────────────────

  /// Seeds the three default meals on a fresh install.
  /// Nutritional values are approximate totals for a typical serving,
  /// sourced from USDA SR Legacy data for each ingredient.
  static Future<void> _seedMeals(Database db) async {
    final meals = [
      const Meal(
        name: 'Breakfast',
        description: 'Oats, banana, eggs',
        calories: 520,
        proteinG: 22.0,
        fatG: 14.0,
        carbsG: 72.0,
        sugarG: 18.0,
        sodiumMg: 210.0,
        fiberG: 7.0,
      ),
      const Meal(
        name: 'Lunch',
        description: 'Chicken breast, rice, broccoli',
        calories: 680,
        proteinG: 45.0,
        fatG: 8.0,
        carbsG: 78.0,
        sugarG: 4.0,
        sodiumMg: 390.0,
        fiberG: 5.0,
      ),
      const Meal(
        name: 'Dinner',
        description: 'Salmon fillet, sweet potato, mixed salad',
        calories: 600,
        proteinG: 38.0,
        fatG: 18.0,
        carbsG: 48.0,
        sugarG: 12.0,
        sodiumMg: 480.0,
        fiberG: 6.0,
      ),
    ];

    for (final meal in meals) {
      await db.insert('meals', meal.toMap());
    }
  }

  /// Backfills nutritional data for the three existing seeded meals
  /// when upgrading a v1 database to v2.
  static Future<void> _backfillMealNutrition(Database db) async {
    final updates = [
      {
        'name': 'Breakfast',
        'protein_g': 22.0, 'fat_g': 14.0, 'carbs_g': 72.0,
        'sugar_g': 18.0,   'sodium_mg': 210.0, 'fiber_g': 7.0,
      },
      {
        'name': 'Lunch',
        'protein_g': 45.0, 'fat_g': 8.0,  'carbs_g': 78.0,
        'sugar_g': 4.0,    'sodium_mg': 390.0, 'fiber_g': 5.0,
      },
      {
        'name': 'Dinner',
        'protein_g': 38.0, 'fat_g': 18.0, 'carbs_g': 48.0,
        'sugar_g': 12.0,   'sodium_mg': 480.0, 'fiber_g': 6.0,
      },
    ];

    for (final u in updates) {
      await db.update(
        'meals',
        {
          'protein_g': u['protein_g'],
          'fat_g': u['fat_g'],
          'carbs_g': u['carbs_g'],
          'sugar_g': u['sugar_g'],
          'sodium_mg': u['sodium_mg'],
          'fiber_g': u['fiber_g'],
        },
        where: 'name = ?',
        whereArgs: [u['name']],
      );
    }
  }

  // ── Meal CRUD ─────────────────────────────────────────────────────────────

  static Future<List<Meal>> getMeals() async {
    final db = await database;
    final rows = await db.query('meals');
    return rows.map(Meal.fromMap).toList();
  }

  static Future<int> insertMeal(Meal meal) async {
    final db = await database;
    return db.insert('meals', meal.toMap());
  }

  static Future<int> updateMeal(Meal meal) async {
    final db = await database;
    return db.update('meals', meal.toMap(), where: 'id = ?', whereArgs: [meal.id]);
  }

  static Future<int> deleteMeal(int id) async {
    final db = await database;
    return db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  // ── Food cache CRUD ───────────────────────────────────────────────────────

  /// Cache TTL: 24 hours in milliseconds.
  static const int _cacheTtlMs = 24 * 60 * 60 * 1000;

  /// Inserts or replaces a [FoodItem] in the local cache.
  static Future<void> cacheFoodItem(FoodItem item) async {
    final db = await database;
    final map = item.toMap();
    map['cached_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'food_cache',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves a [FoodItem] from the cache by its ID.
  /// Returns null if not found or if the cached entry has expired (>24h).
  static Future<FoodItem?> getCachedFood(String id) async {
    final db = await database;
    final rows = await db.query(
      'food_cache',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final cachedAt = row['cached_at'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
    if (age > _cacheTtlMs) {
      // Expired — delete and return null
      await db.delete('food_cache', where: 'id = ?', whereArgs: [id]);
      return null;
    }
    return FoodItem.fromMap(row);
  }

  /// Bulk-caches a list of [FoodItem]s returned from a USDA API search.
  static Future<void> cacheFoodItems(List<FoodItem> items) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final item in items) {
      final map = item.toMap();
      map['cached_at'] = now;
      batch.insert('food_cache', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Searches the food_cache for items whose name contains [query].
  /// Only returns non-expired entries.
  static Future<List<FoodItem>> searchCachedFoods(String query) async {
    final db = await database;
    final cutoff = DateTime.now().millisecondsSinceEpoch - _cacheTtlMs;
    final rows = await db.query(
      'food_cache',
      where: 'name LIKE ? AND cached_at > ?',
      whereArgs: ['%$query%', cutoff],
      limit: 20,
    );
    return rows.map(FoodItem.fromMap).toList();
  }
}
