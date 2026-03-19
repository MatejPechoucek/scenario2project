import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'app_user.dart';
import 'food_item.dart';
import 'food_log_entry.dart';
import 'meal.dart';

/// Manages all local SQLite persistence for CleanEater.
///
/// Database version history:
///   v1 — initial: meals(id, name, description, calories)
///   v2 — macro/micro columns added to meals; food_cache table added
///   v3 — meal_slot column added to meals
///   v4 — app_user table added; food_log table added
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
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Called on fresh install (no existing database).
  static Future<void> _onCreate(Database db, int version) async {
    await _createMealsTable(db);
    await _createFoodCacheTable(db);
    await _createAppUserTable(db);
    await _createFoodLogTable(db);
    await _seedMeals(db);
    await _seedUser(db);
  }

  /// Called when the existing database version < current version.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
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
      await _backfillMealNutrition(db);
      await _createFoodCacheTable(db);
    }
    if (oldVersion < 3) {
      await db.execute(
          "ALTER TABLE meals ADD COLUMN meal_slot TEXT DEFAULT 'any'");
      await db.execute(
          "UPDATE meals SET meal_slot = 'breakfast' WHERE name = 'Breakfast'");
      await db.execute(
          "UPDATE meals SET meal_slot = 'lunch' WHERE name = 'Lunch'");
      await db.execute(
          "UPDATE meals SET meal_slot = 'dinner' WHERE name = 'Dinner'");
    }
    if (oldVersion < 4) {
      await _createAppUserTable(db);
      await _createFoodLogTable(db);
      await _seedUser(db);
    }
  }

  // ── Schema helpers ────────────────────────────────────────────────────────

  static Future<void> _createMealsTable(Database db) async {
    await db.execute('''
      CREATE TABLE meals (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        description TEXT NOT NULL,
        calories    INTEGER NOT NULL,
        meal_slot   TEXT DEFAULT 'any',
        protein_g   REAL DEFAULT 0,
        fat_g       REAL DEFAULT 0,
        carbs_g     REAL DEFAULT 0,
        sugar_g     REAL DEFAULT 0,
        sodium_mg   REAL DEFAULT 0,
        fiber_g     REAL DEFAULT 0
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

  static Future<void> _createAppUserTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_user (
        id                  INTEGER PRIMARY KEY,
        name                TEXT NOT NULL DEFAULT 'User',
        daily_calorie_goal  INTEGER NOT NULL DEFAULT 2000,
        protein_g_goal      REAL NOT NULL DEFAULT 150,
        fat_g_goal          REAL NOT NULL DEFAULT 65,
        carbs_g_goal        REAL NOT NULL DEFAULT 250
      )
    ''');
  }

  static Future<void> _createFoodLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_log (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        food_item_id  TEXT NOT NULL,
        food_name     TEXT NOT NULL,
        category      TEXT NOT NULL DEFAULT 'General',
        serving_g     REAL NOT NULL,
        calories      REAL NOT NULL,
        protein_g     REAL NOT NULL DEFAULT 0,
        fat_g         REAL NOT NULL DEFAULT 0,
        carbs_g       REAL NOT NULL DEFAULT 0,
        sugar_g       REAL NOT NULL DEFAULT 0,
        sodium_mg     REAL NOT NULL DEFAULT 0,
        fiber_g       REAL NOT NULL DEFAULT 0,
        meal_slot     TEXT NOT NULL DEFAULT 'any',
        logged_date   TEXT NOT NULL,
        logged_at     INTEGER NOT NULL
      )
    ''');
  }

  // ── Seed data ─────────────────────────────────────────────────────────────

  static Future<void> _seedMeals(Database db) async {
    final meals = [
      const Meal(
        name: 'Breakfast',
        description: 'Oats, banana, eggs',
        calories: 520,
        mealSlot: 'breakfast',
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
        mealSlot: 'lunch',
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
        mealSlot: 'dinner',
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

  /// Inserts the single default user on fresh install or v3→v4 upgrade.
  /// Uses INSERT OR IGNORE so it is safe to call multiple times.
  static Future<void> _seedUser(Database db) async {
    await db.execute('''
      INSERT OR IGNORE INTO app_user
        (id, name, daily_calorie_goal, protein_g_goal, fat_g_goal, carbs_g_goal)
      VALUES (1, 'User', 2000, 150.0, 65.0, 250.0)
    ''');
  }

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

  // ── User CRUD ─────────────────────────────────────────────────────────────

  /// Returns the single app user (id=1). Creates default if missing.
  static Future<AppUser> getUser() async {
    final db = await database;
    final rows = await db.query('app_user', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) {
      await _seedUser(db);
      final fresh = await db.query('app_user', where: 'id = ?', whereArgs: [1]);
      return AppUser.fromMap(fresh.first);
    }
    return AppUser.fromMap(rows.first);
  }

  static Future<void> updateUser(AppUser user) async {
    final db = await database;
    await db.update('app_user', user.toMap(),
        where: 'id = ?', whereArgs: [user.id]);
  }

  // ── Food log CRUD ─────────────────────────────────────────────────────────

  /// Inserts a new food log entry. Returns the new row id.
  static Future<int> logFood(FoodLogEntry entry) async {
    final db = await database;
    return db.insert('food_log', entry.toMap());
  }

  /// Returns all entries logged on [date] (format 'YYYY-MM-DD'),
  /// ordered by logged_at ascending.
  static Future<List<FoodLogEntry>> getFoodLogForDate(String date) async {
    final db = await database;
    final rows = await db.query(
      'food_log',
      where: 'logged_date = ?',
      whereArgs: [date],
      orderBy: 'logged_at ASC',
    );
    return rows.map(FoodLogEntry.fromMap).toList();
  }

  /// Returns all food log entries across all dates, newest first.
  /// Useful for the history view.
  static Future<List<FoodLogEntry>> getAllFoodLog() async {
    final db = await database;
    final rows = await db.query('food_log', orderBy: 'logged_at DESC');
    return rows.map(FoodLogEntry.fromMap).toList();
  }

  /// Deletes a specific food log entry by its id.
  static Future<int> deleteFoodLogEntry(int id) async {
    final db = await database;
    return db.delete('food_log', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns the total calories logged for a given date.
  static Future<double> getTotalCaloriesForDate(String date) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(calories), 0) AS total FROM food_log WHERE logged_date = ?',
      [date],
    );
    return (result.first['total'] as num).toDouble();
  }

  // ── Food cache CRUD ───────────────────────────────────────────────────────

  static const int _cacheTtlMs = 24 * 60 * 60 * 1000;

  static Future<void> cacheFoodItem(FoodItem item) async {
    final db = await database;
    final map = item.toMap();
    map['cached_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.insert('food_cache', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<FoodItem?> getCachedFood(String id) async {
    final db = await database;
    final rows = await db.query('food_cache',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final age =
        DateTime.now().millisecondsSinceEpoch - (row['cached_at'] as int);
    if (age > _cacheTtlMs) {
      await db.delete('food_cache', where: 'id = ?', whereArgs: [id]);
      return null;
    }
    return FoodItem.fromMap(row);
  }

  static Future<void> cacheFoodItems(List<FoodItem> items) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final item in items) {
      final map = item.toMap();
      map['cached_at'] = now;
      batch.insert('food_cache', map,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<FoodItem>> searchCachedFoods(String query) async {
    final db = await database;
    final cutoff = DateTime.now().millisecondsSinceEpoch - _cacheTtlMs;
    final rows = await db.query('food_cache',
        where: 'name LIKE ? AND cached_at > ?',
        whereArgs: ['%$query%', cutoff],
        limit: 20);
    return rows.map(FoodItem.fromMap).toList();
  }
}
