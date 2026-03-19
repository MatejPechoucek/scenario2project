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
///   v5 — calculator inputs + weeklyLossKg added to app_user
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
      version: 5,
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
    await _seedFoodLog(db);
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
      await _seedFoodLog(db);
    }
    if (oldVersion < 5) {
      for (final sql in [
        'ALTER TABLE app_user ADD COLUMN height_cm INTEGER DEFAULT 0',
        'ALTER TABLE app_user ADD COLUMN weight_kg INTEGER DEFAULT 0',
        'ALTER TABLE app_user ADD COLUMN age INTEGER DEFAULT 0',
        'ALTER TABLE app_user ADD COLUMN activity_level INTEGER DEFAULT 0',
        'ALTER TABLE app_user ADD COLUMN weekly_loss_kg REAL DEFAULT 0',
      ]) {
        await db.execute(sql);
      }
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
        carbs_g_goal        REAL NOT NULL DEFAULT 250,
        height_cm           INTEGER NOT NULL DEFAULT 0,
        weight_kg           INTEGER NOT NULL DEFAULT 0,
        age                 INTEGER NOT NULL DEFAULT 0,
        activity_level      INTEGER NOT NULL DEFAULT 0,
        weekly_loss_kg      REAL NOT NULL DEFAULT 0
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

  /// Public entry-point for startup seeding — called from main.dart after
  /// migrations, so it works on both fresh installs and existing v4 DBs.
  static Future<void> seedPlaceholderFoodLogIfEmpty() async {
    final db = await database;
    await _seedFoodLog(db);
  }

  /// Seeds 7 days of realistic placeholder food log entries.
  /// Only runs if the food_log table is completely empty.
  static Future<void> _seedFoodLog(Database db) async {
    final existing = await db.rawQuery('SELECT COUNT(*) as c FROM food_log');
    if ((existing.first['c'] as int) > 0) return;

    final now = DateTime.now();

    // Helper to build a date string N days ago.
    String date(int daysAgo) {
      final d = now.subtract(Duration(days: daysAgo));
      return '${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    // Each entry: (food_item_id, food_name, category, serving_g,
    //              calories, protein_g, fat_g, carbs_g, sugar_g,
    //              sodium_mg, fiber_g, meal_slot, logged_date, logged_at)
    final entries = <Map<String, Object?>>[
      // ── 6 days ago ──────────────────────────────────────────────────────
      _logRow('local_001', 'Porridge (Oats)',      'Breakfast Cereals', 250, 335, 11, 6.5, 59, 1.0, 18, 4.0, 'breakfast', date(6), now, -6, 0),
      _logRow('local_002', 'Chicken Breast',       'Poultry',           180, 297, 55, 4.0, 0,  0.0, 180, 0.0,'lunch',     date(6), now, -6, 1),
      _logRow('local_003', 'Brown Rice (cooked)',  'Grains',            160, 210, 4.4, 1.8, 44, 0.4, 8, 1.8, 'lunch',     date(6), now, -6, 2),
      _logRow('local_004', 'Broccoli (steamed)',   'Vegetables',        100, 35,  2.8, 0.4, 6,  1.5, 40, 2.6,'lunch',     date(6), now, -6, 3),
      _logRow('local_005', 'Salmon Fillet',        'Fish & Seafood',    200, 412, 40,  26,  0,  0.0, 120, 0.0,'dinner',    date(6), now, -6, 4),
      _logRow('local_006', 'Sweet Potato (baked)', 'Vegetables',        150, 129, 2.3, 0.2, 30, 6.0, 56, 3.8,'dinner',    date(6), now, -6, 5),

      // ── 5 days ago ──────────────────────────────────────────────────────
      _logRow('local_007', 'Scrambled Eggs',       'Eggs & Dairy',      120, 192, 14,  14,  1.2,  1.0, 300, 0.0,'breakfast', date(5), now, -5, 0),
      _logRow('local_008', 'Wholegrain Toast',     'Bread & Bakery',    60,  138, 5.0, 1.4, 27,  2.0, 200, 3.2,'breakfast', date(5), now, -5, 1),
      _logRow('local_009', 'Tuna (in water)',      'Fish & Seafood',    130, 130, 29,  1.0, 0,   0.0, 330, 0.0,'lunch',     date(5), now, -5, 2),
      _logRow('local_010', 'Mixed Salad Leaves',  'Salads',            80,  14,  1.2, 0.2, 2.4, 0.8, 28, 1.4, 'lunch',     date(5), now, -5, 3),
      _logRow('local_011', 'Beef Stir Fry',        'Red Meat',          200, 380, 32,  22,  8,   4.0, 640, 2.0,'dinner',    date(5), now, -5, 4),
      _logRow('local_012', 'Egg Noodles (cooked)', 'Grains',            150, 206, 7.2, 2.3, 40,  1.5, 18, 1.5, 'dinner',    date(5), now, -5, 5),
      _logRow('local_013', 'Apple',                'Fruits',            150, 78,  0.4, 0.2, 20,  14,  1.5, 2.6,'snack',     date(5), now, -5, 6),

      // ── 4 days ago ──────────────────────────────────────────────────────
      _logRow('local_014', 'Greek Yogurt (plain)', 'Eggs & Dairy',      200, 116, 10,  5.0, 3.8, 3.8, 80, 0.0,'breakfast', date(4), now, -4, 0),
      _logRow('local_015', 'Mixed Berries',        'Fruits',            100, 57,  0.8, 0.5, 14,  9.0, 2.0, 2.0,'breakfast', date(4), now, -4, 1),
      _logRow('local_016', 'Lentil Soup',          'Legumes',           350, 280, 18,  3.5, 45,  6.0, 480, 9.5,'lunch',     date(4), now, -4, 2),
      _logRow('local_017', 'Wholegrain Bread',     'Bread & Bakery',    60,  145, 5.5, 1.8, 27,  2.0, 240, 3.5,'lunch',     date(4), now, -4, 3),
      _logRow('local_018', 'Grilled Salmon',       'Fish & Seafood',    180, 371, 36,  24,  0,   0.0, 108, 0.0,'dinner',    date(4), now, -4, 4),
      _logRow('local_019', 'Asparagus (grilled)',  'Vegetables',        120, 26,  2.9, 0.2, 5,   2.0, 4,  2.4, 'dinner',    date(4), now, -4, 5),
      _logRow('local_020', 'Almonds',              'Nuts & Seeds',      30,  174, 6.3, 15,  5.8, 1.0, 1.2, 2.1,'snack',     date(4), now, -4, 6),

      // ── 3 days ago ──────────────────────────────────────────────────────
      _logRow('local_021', 'Banana Smoothie',      'Beverages',         350, 263, 4.2, 1.4, 62,  42,  56, 2.4,'breakfast', date(3), now, -3, 0),
      _logRow('local_022', 'Caesar Salad',         'Salads',            280, 364, 12,  28,  14,  4.0, 680, 2.0,'lunch',     date(3), now, -3, 1),
      _logRow('local_023', 'Chicken Curry',        'Meals',             300, 420, 28,  18,  24,  6.0, 720, 3.0,'dinner',    date(3), now, -3, 2),
      _logRow('local_024', 'Basmati Rice (cooked)','Grains',            180, 234, 5.0, 0.5, 52,  0.2, 4,  0.5, 'dinner',    date(3), now, -3, 3),
      _logRow('local_025', 'Dark Chocolate (70%)', 'Desserts',          30,  161, 2.1, 12,  16,  12,  6.0, 2.7,'snack',     date(3), now, -3, 4),

      // ── 2 days ago ──────────────────────────────────────────────────────
      _logRow('local_026', 'Avocado Toast',        'Bread & Bakery',    180, 368, 7.8, 22,  33,  2.4, 340, 7.2,'breakfast', date(2), now, -2, 0),
      _logRow('local_027', 'Turkey Wrap',          'Processed Meat',    220, 420, 30,  12,  42,  4.0, 820, 3.5,'lunch',     date(2), now, -2, 1),
      _logRow('local_028', 'Margherita Pizza',     'Fast Food',         300, 690, 24,  24,  87,  9.0, 1260,4.5,'dinner',    date(2), now, -2, 2),
      _logRow('local_029', 'Protein Bar',          'Supplements',       60,  228, 20,  8.0, 26,  10,  120, 4.0,'snack',     date(2), now, -2, 3),

      // ── Yesterday ────────────────────────────────────────────────────────
      _logRow('local_030', 'Pancakes (2 medium)',  'Bread & Bakery',    160, 366, 9.6, 14,  52,  12,  440, 1.6,'breakfast', date(1), now, -1, 0),
      _logRow('local_031', 'Maple Syrup',          'Condiments',        20,  52,  0.0, 0.0, 13,  13,  0.8, 0.0,'breakfast', date(1), now, -1, 1),
      _logRow('local_032', 'Cheeseburger',         'Fast Food',         220, 550, 28,  30,  40,  6.0, 890, 2.0,'lunch',     date(1), now, -1, 2),
      _logRow('local_033', 'Sweet Potato Fries',   'Fast Food',         120, 192, 2.4, 8.4, 30,  4.0, 340, 3.0,'lunch',     date(1), now, -1, 3),
      _logRow('local_034', 'Grilled Chicken',      'Poultry',           200, 330, 62,  8.0, 0,   0.0, 200, 0.0,'dinner',    date(1), now, -1, 4),
      _logRow('local_035', 'Steamed Vegetables',   'Vegetables',        180, 63,  3.6, 0.5, 13,  5.0, 36, 4.2, 'dinner',    date(1), now, -1, 5),

      // ── Today ────────────────────────────────────────────────────────────
      _logRow('local_036', 'Oats with Honey',      'Breakfast Cereals', 200, 340, 9.0, 5.5, 62,  14,  20, 4.8,'breakfast', date(0), now, 0,  0),
      _logRow('local_037', 'Orange Juice',         'Beverages',         200, 86,  1.4, 0.2, 20,  18,  4.0, 0.4,'breakfast', date(0), now, 0,  1),
      _logRow('local_038', 'Tuna Salad',           'Fish & Seafood',    250, 310, 36,  10,  14,  3.0, 420, 3.2,'lunch',     date(0), now, 0,  2),
    ];

    final batch = db.batch();
    for (final e in entries) {
      batch.insert('food_log', e);
    }
    await batch.commit(noResult: true);
  }

  /// Builds a food_log row map from individual fields.
  static Map<String, Object?> _logRow(
    String id,
    String name,
    String category,
    double servingG,
    double calories,
    double proteinG,
    double fatG,
    double carbsG,
    double sugarG,
    double sodiumMg,
    double fiberG,
    String mealSlot,
    String loggedDate,
    DateTime baseTime,
    int dayOffset,
    int sequence,
  ) {
    // Spread entries across the day: breakfast ~7am, lunch ~12pm, dinner ~7pm, snack ~3pm.
    const slotHours = {'breakfast': 7, 'lunch': 12, 'dinner': 19, 'snack': 15};
    final hour = slotHours[mealSlot] ?? 12;
    final ts = DateTime(
      baseTime.year, baseTime.month, baseTime.day,
      hour, sequence * 3, // offset by minutes so ordering is stable
    ).subtract(Duration(days: -dayOffset)).millisecondsSinceEpoch;

    return {
      'food_item_id': id,
      'food_name': name,
      'category': category,
      'serving_g': servingG,
      'calories': calories,
      'protein_g': proteinG,
      'fat_g': fatG,
      'carbs_g': carbsG,
      'sugar_g': sugarG,
      'sodium_mg': sodiumMg,
      'fiber_g': fiberG,
      'meal_slot': mealSlot,
      'logged_date': loggedDate,
      'logged_at': ts,
    };
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
