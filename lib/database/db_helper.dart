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
///   v6 — sex column added to app_user
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
      version: 6,
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
        await _safeAddColumn(db, col);
      }
      await _backfillMealNutrition(db);
      await _createFoodCacheTable(db);
    }
    if (oldVersion < 3) {
      await _safeAddColumn(db, "ALTER TABLE meals ADD COLUMN meal_slot TEXT DEFAULT 'any'");
      await db.execute("UPDATE meals SET meal_slot = 'breakfast' WHERE name = 'Breakfast'");
      await db.execute("UPDATE meals SET meal_slot = 'lunch' WHERE name = 'Lunch'");
      await db.execute("UPDATE meals SET meal_slot = 'dinner' WHERE name = 'Dinner'");
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
        await _safeAddColumn(db, sql);
      }
    }
    if (oldVersion < 6) {
      await _safeAddColumn(db, 'ALTER TABLE app_user ADD COLUMN sex INTEGER DEFAULT 0');
    }
  }

  /// Executes an ALTER TABLE ADD COLUMN statement, ignoring errors if the
  /// column already exists. This handles cases where _createAppUserTable was
  /// called with the full schema during an earlier migration step.
  static Future<void> _safeAddColumn(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
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
        sex                 INTEGER NOT NULL DEFAULT 0,
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
        (id, name, daily_calorie_goal, protein_g_goal, fat_g_goal, carbs_g_goal,
         height_cm, weight_kg, age, activity_level, sex, weekly_loss_kg)
      VALUES (1, 'Alex', 2000, 160.0, 65.0, 220.0, 178, 78, 26, 2, 1, 0.5)
    ''');
  }

  /// Public entry-point for startup seeding — called from main.dart after
  /// migrations, so it works on both fresh installs and existing v4 DBs.
  static Future<void> seedPlaceholderFoodLogIfEmpty() async {
    final db = await database;
    await _seedFoodLog(db);
  }

  /// Seeds 21 days of realistic placeholder food log entries.
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
    // Days 7–0 are all within goal (≤2300 kcal) → 8-day streak.
    // Day 8 is over 2300 kcal → breaks the streak.
    final entries = <Map<String, Object?>>[
      // ── Day 20 (~1790 kcal) ─────────────────────────────────────────────
      _logRow('local_001', 'Porridge (Oats)',        'Breakfast Cereals', 300, 402, 15.0,  7.8, 68.0,  1.5,  21.0,  5.4, 'breakfast', date(20), now, -20, 0),
      _logRow('local_002', 'Chicken Breast',         'Poultry',           200, 330, 62.0,  7.2,  0.0,  0.0, 200.0,  0.0, 'lunch',     date(20), now, -20, 1),
      _logRow('local_003', 'Brown Rice (cooked)',    'Grains',            180, 236,  4.9,  2.0, 49.0,  0.4,   9.0,  2.2, 'lunch',     date(20), now, -20, 2),
      _logRow('local_004', 'Broccoli (steamed)',     'Vegetables',        150,  53,  4.2,  0.6,  9.0,  2.3,  60.0,  3.9, 'lunch',     date(20), now, -20, 3),
      _logRow('local_005', 'Beef Stir Fry',          'Red Meat',          230, 506, 46.0, 34.0,  0.0,  0.0, 196.0,  0.0, 'dinner',    date(20), now, -20, 4),
      _logRow('local_006', 'Banana',                 'Fruits',            120, 107,  1.3,  0.4, 27.0, 14.0,   1.0,  3.1, 'snack',     date(20), now, -20, 5),
      _logRow('local_007', 'Almonds',                'Nuts & Seeds',       25, 145,  5.3, 12.5,  4.8,  0.9,   1.0,  1.8, 'snack',     date(20), now, -20, 6),

      // ── Day 19 (~2090 kcal) ─────────────────────────────────────────────
      _logRow('local_008', 'Scrambled Eggs (3)',     'Eggs & Dairy',      180, 288, 21.0, 21.0,  1.8,  1.4, 450.0,  0.0, 'breakfast', date(19), now, -19, 0),
      _logRow('local_009', 'Wholegrain Toast (2)',   'Bread & Bakery',    100, 230,  9.0,  2.4, 44.0,  3.5, 400.0,  5.4, 'breakfast', date(19), now, -19, 1),
      _logRow('local_010', 'Chicken Caesar Salad',   'Salads',            300, 450, 35.0, 24.0, 18.0,  4.0, 780.0,  2.5, 'lunch',     date(19), now, -19, 2),
      _logRow('local_011', 'Pasta Carbonara',        'Meals',             360, 720, 30.0, 30.0, 78.0,  3.8, 550.0,  3.6, 'dinner',    date(19), now, -19, 3),
      _logRow('local_012', 'Steamed Broccoli',       'Vegetables',        120,  42,  3.4,  0.5,  7.2,  1.8,  48.0,  3.1, 'dinner',    date(19), now, -19, 4),
      _logRow('local_013', 'Mixed Berries',          'Fruits',            150,  86,  1.2,  0.8, 21.0, 13.5,   3.0,  3.0, 'snack',     date(19), now, -19, 5),
      _logRow('local_014', 'Protein Bar',            'Supplements',        60, 228, 20.0,  8.0, 26.0, 10.0, 120.0,  4.0, 'snack',     date(19), now, -19, 6),

      // ── Day 18 (~2680 kcal — weekend splurge) ───────────────────────────
      _logRow('local_015', 'Pancakes (3 large)',     'Bread & Bakery',    240, 549, 14.4, 21.0, 78.0, 18.0, 660.0,  2.4, 'breakfast', date(18), now, -18, 0),
      _logRow('local_016', 'Maple Syrup',            'Condiments',         40, 104,  0.0,  0.0, 26.0, 26.0,   2.0,  0.0, 'breakfast', date(18), now, -18, 1),
      _logRow('local_017', 'Bacon (3 rashers)',      'Processed Meat',     90, 279, 18.0, 22.0,  0.0,  0.0, 990.0,  0.0, 'breakfast', date(18), now, -18, 2),
      _logRow('local_018', 'Fish & Chips',           'Fast Food',         450, 810, 29.0, 38.0, 88.0,  2.7,1080.0,  4.1, 'lunch',     date(18), now, -18, 3),
      _logRow('local_019', 'Cola (can)',             'Beverages',         330, 139,  0.0,  0.0, 35.0, 35.0,  33.0,  0.0, 'lunch',     date(18), now, -18, 4),
      _logRow('local_020', 'Beef Burger',            'Fast Food',         230, 506, 26.0, 28.0, 37.0,  7.4, 820.0,  2.3, 'dinner',    date(18), now, -18, 5),
      _logRow('local_021', 'Sweet Potato Fries',     'Fast Food',         150, 240,  3.0, 10.5, 37.0,  5.0, 425.0,  3.8, 'dinner',    date(18), now, -18, 6),
      _logRow('local_022', 'Ice Cream (2 scoops)',   'Desserts',          150, 270,  4.5, 14.0, 34.0, 28.0,  90.0,  0.0, 'snack',     date(18), now, -18, 7),

      // ── Day 17 (~2260 kcal) ─────────────────────────────────────────────
      _logRow('local_023', 'Avocado Toast',          'Bread & Bakery',    180, 368,  7.8, 22.0, 33.0,  2.4, 340.0,  7.2, 'breakfast', date(17), now, -17, 0),
      _logRow('local_024', 'Poached Eggs (2)',       'Eggs & Dairy',      100, 155, 13.0, 11.0,  0.8,  0.7, 250.0,  0.0, 'breakfast', date(17), now, -17, 1),
      _logRow('local_025', 'Chicken Curry',          'Meals',             350, 490, 33.0, 21.0, 28.0,  7.0, 840.0,  3.5, 'lunch',     date(17), now, -17, 2),
      _logRow('local_026', 'Basmati Rice (cooked)',  'Grains',            200, 260,  5.6,  0.5, 58.0,  0.2,   4.0,  0.5, 'lunch',     date(17), now, -17, 3),
      _logRow('local_027', 'Lamb Chops',             'Red Meat',          180, 432, 36.0, 30.6,  0.0,  0.0, 270.0,  0.0, 'dinner',    date(17), now, -17, 4),
      _logRow('local_028', 'Roasted Potatoes',       'Vegetables',        180, 268,  3.6,  9.0, 41.0,  1.8, 360.0,  4.1, 'dinner',    date(17), now, -17, 5),
      _logRow('local_029', 'Dark Chocolate (70%)',   'Desserts',           35, 187,  2.5, 14.0, 18.0, 14.0,   7.0,  3.2, 'snack',     date(17), now, -17, 6),

      // ── Day 16 (~1940 kcal) ─────────────────────────────────────────────
      _logRow('local_030', 'Porridge (Oats)',        'Breakfast Cereals', 250, 335, 11.0,  6.5, 57.0,  1.3,  18.0,  4.5, 'breakfast', date(16), now, -16, 0),
      _logRow('local_031', 'Orange Juice',           'Beverages',         200,  86,  1.4,  0.2, 20.0, 18.0,   4.0,  0.4, 'breakfast', date(16), now, -16, 1),
      _logRow('local_032', 'Tuna Salad Wrap',        'Fish & Seafood',    280, 448, 38.0, 12.0, 38.0,  4.0, 680.0,  4.5, 'lunch',     date(16), now, -16, 2),
      _logRow('local_033', 'Grilled Salmon',         'Fish & Seafood',    180, 371, 39.6, 23.4,  0.0,  0.0, 121.0,  0.0, 'dinner',    date(16), now, -16, 3),
      _logRow('local_034', 'Quinoa (cooked)',        'Grains',            180, 234,  8.5,  3.7, 41.0,  1.7, 180.0,  5.0, 'dinner',    date(16), now, -16, 4),
      _logRow('local_035', 'Asparagus (grilled)',    'Vegetables',        150,  33,  3.6,  0.3,  6.3,  2.5,   5.0,  3.0, 'dinner',    date(16), now, -16, 5),
      _logRow('local_036', 'Greek Yogurt (plain)',   'Eggs & Dairy',      200, 116, 10.0,  5.0,  3.8,  3.8,  80.0,  0.0, 'snack',     date(16), now, -16, 6),
      _logRow('local_037', 'Protein Bar',            'Supplements',        60, 228, 20.0,  8.0, 26.0, 10.0, 120.0,  4.0, 'snack',     date(16), now, -16, 7),

      // ── Day 15 (~1750 kcal) ─────────────────────────────────────────────
      _logRow('local_038', 'Greek Yogurt (plain)',   'Eggs & Dairy',      200, 116, 10.0,  5.0,  3.8,  3.8,  80.0,  0.0, 'breakfast', date(15), now, -15, 0),
      _logRow('local_039', 'Granola',                'Breakfast Cereals',  80, 372, 10.0, 16.0, 48.0, 16.0,  80.0,  4.8, 'breakfast', date(15), now, -15, 1),
      _logRow('local_040', 'Blueberries',            'Fruits',            100,  57,  0.7,  0.3, 14.0,  9.7,   1.0,  2.4, 'breakfast', date(15), now, -15, 2),
      _logRow('local_041', 'Lentil Soup',            'Legumes',           400, 320, 20.0,  4.0, 52.0,  7.0, 548.0, 10.8, 'lunch',     date(15), now, -15, 3),
      _logRow('local_042', 'Wholegrain Bread',       'Bread & Bakery',     80, 184,  7.2,  2.0, 34.0,  3.0, 320.0,  4.8, 'lunch',     date(15), now, -15, 4),
      _logRow('local_043', 'Turkey Breast (grilled)','Poultry',           200, 270, 60.0,  3.0,  0.0,  0.0, 100.0,  0.0, 'dinner',    date(15), now, -15, 5),
      _logRow('local_044', 'Steamed Vegetables',     'Vegetables',        200,  70,  4.0,  0.6, 14.0,  7.0,  60.0,  5.0, 'dinner',    date(15), now, -15, 6),
      _logRow('local_045', 'Brown Rice (cooked)',    'Grains',            150, 197,  4.1,  1.7, 41.0,  0.3,   8.0,  1.9, 'dinner',    date(15), now, -15, 7),
      _logRow('local_046', 'Almonds',                'Nuts & Seeds',       25, 145,  5.3, 12.5,  4.8,  0.9,   1.0,  1.8, 'snack',     date(15), now, -15, 8),

      // ── Day 14 (~2750 kcal — weekend splurge) ───────────────────────────
      _logRow('local_047', 'Full English Breakfast', 'Meals',             450, 810, 45.0, 52.0, 36.0,  6.0,1800.0,  3.6, 'breakfast', date(14), now, -14, 0),
      _logRow('local_048', 'Orange Juice',           'Beverages',         250, 108,  1.7,  0.2, 25.0, 22.5,   5.0,  0.5, 'breakfast', date(14), now, -14, 1),
      _logRow('local_049', 'Cheeseburger (large)',   'Fast Food',         280, 700, 37.0, 39.0, 45.0,  8.4,1120.0,  2.3, 'lunch',     date(14), now, -14, 2),
      _logRow('local_050', 'French Fries',           'Fast Food',         180, 502,  5.4, 23.4, 66.6,  0.9, 396.0,  5.0, 'lunch',     date(14), now, -14, 3),
      _logRow('local_051', 'Beer (pint)',             'Beverages',         568, 227,  1.7,  0.0, 17.0,  0.0,  30.0,  0.0, 'dinner',    date(14), now, -14, 4),
      _logRow('local_052', 'Pizza Margherita (3sl)', 'Fast Food',         330, 758, 30.8, 26.4, 96.3,  9.9,1386.0,  5.0, 'dinner',    date(14), now, -14, 5),
      _logRow('local_053', 'Ice Cream',              'Desserts',          120, 216,  3.6, 11.2, 27.2, 22.4,  72.0,  0.0, 'snack',     date(14), now, -14, 6),

      // ── Day 13 (~1860 kcal) ─────────────────────────────────────────────
      _logRow('local_054', 'Porridge (Oats)',        'Breakfast Cereals', 300, 402, 15.0,  7.8, 68.0,  1.5,  21.0,  5.4, 'breakfast', date(13), now, -13, 0),
      _logRow('local_055', 'Banana',                 'Fruits',            120, 107,  1.3,  0.4, 27.0, 14.0,   1.0,  3.1, 'breakfast', date(13), now, -13, 1),
      _logRow('local_056', 'Tuna Salad',             'Fish & Seafood',    250, 310, 36.0, 10.0, 14.0,  3.0, 420.0,  3.2, 'lunch',     date(13), now, -13, 2),
      _logRow('local_057', 'Wholegrain Toast',       'Bread & Bakery',     80, 184,  7.2,  1.9, 35.0,  2.8, 320.0,  4.3, 'lunch',     date(13), now, -13, 3),
      _logRow('local_058', 'Chicken Breast',         'Poultry',           200, 330, 62.0,  7.2,  0.0,  0.0, 200.0,  0.0, 'dinner',    date(13), now, -13, 4),
      _logRow('local_059', 'Sweet Potato (baked)',   'Vegetables',        200, 172,  3.2,  0.3, 40.0,  8.0,  74.0,  5.0, 'dinner',    date(13), now, -13, 5),
      _logRow('local_060', 'Steamed Broccoli',       'Vegetables',        150,  53,  4.2,  0.6,  9.0,  2.3,  60.0,  3.9, 'dinner',    date(13), now, -13, 6),
      _logRow('local_061', 'Apple',                  'Fruits',            150,  78,  0.5,  0.3, 21.0, 15.0,   2.0,  3.6, 'snack',     date(13), now, -13, 7),

      // ── Day 12 (~1920 kcal) ─────────────────────────────────────────────
      _logRow('local_062', 'Scrambled Eggs (2)',     'Eggs & Dairy',      120, 192, 14.0, 14.0,  1.2,  1.0, 300.0,  0.0, 'breakfast', date(12), now, -12, 0),
      _logRow('local_063', 'Wholegrain Toast (2)',   'Bread & Bakery',    100, 230,  9.0,  2.4, 44.0,  3.5, 400.0,  5.4, 'breakfast', date(12), now, -12, 1),
      _logRow('local_064', 'Salmon Fillet',          'Fish & Seafood',    200, 412, 44.0, 26.0,  0.0,  0.0, 134.0,  0.0, 'lunch',     date(12), now, -12, 2),
      _logRow('local_065', 'Cucumber & Tomato Salad','Salads',            200,  30,  1.2,  0.2,  6.4,  3.6,  16.0,  1.6, 'lunch',     date(12), now, -12, 3),
      _logRow('local_066', 'Turkey Breast (grilled)','Poultry',           200, 270, 60.0,  3.0,  0.0,  0.0, 100.0,  0.0, 'dinner',    date(12), now, -12, 4),
      _logRow('local_067', 'Quinoa (cooked)',        'Grains',            200, 260,  9.4,  4.1, 46.0,  1.9, 200.0,  5.5, 'dinner',    date(12), now, -12, 5),
      _logRow('local_068', 'Roasted Broccoli',       'Vegetables',        150,  60,  4.5,  0.8,  9.0,  2.3,  65.0,  4.0, 'dinner',    date(12), now, -12, 6),
      _logRow('local_069', 'Mixed Nuts',             'Nuts & Seeds',       35, 213,  4.9, 18.9,  7.4,  1.4,   2.5,  2.1, 'snack',     date(12), now, -12, 7),
      _logRow('local_070', 'Mixed Berries',          'Fruits',            100,  57,  0.8,  0.5, 14.0,  9.0,   2.0,  2.0, 'snack',     date(12), now, -12, 8),

      // ── Day 11 (~1730 kcal) ─────────────────────────────────────────────
      _logRow('local_071', 'Porridge (Oats)',        'Breakfast Cereals', 300, 402, 15.0,  7.8, 68.0,  1.5,  21.0,  5.4, 'breakfast', date(11), now, -11, 0),
      _logRow('local_072', 'Blueberries',            'Fruits',            100,  57,  0.7,  0.3, 14.0,  9.7,   1.0,  2.4, 'breakfast', date(11), now, -11, 1),
      _logRow('local_073', 'Lentil Soup',            'Legumes',           350, 280, 17.5,  3.5, 45.5,  6.1, 479.5,  9.5, 'lunch',     date(11), now, -11, 2),
      _logRow('local_074', 'Wholegrain Bread',       'Bread & Bakery',     80, 184,  7.2,  2.0, 34.0,  3.0, 320.0,  4.8, 'lunch',     date(11), now, -11, 3),
      _logRow('local_075', 'Pork Tenderloin',        'Red Meat',          200, 280, 50.0,  7.0,  0.0,  0.0, 140.0,  0.0, 'dinner',    date(11), now, -11, 4),
      _logRow('local_076', 'Roasted Sweet Potato',   'Vegetables',        180, 155,  2.9,  0.3, 36.0,  7.2,  67.0,  4.5, 'dinner',    date(11), now, -11, 5),
      _logRow('local_077', 'Steamed Green Beans',    'Vegetables',        150,  48,  2.3,  0.2,  9.5,  4.5,   8.0,  3.2, 'dinner',    date(11), now, -11, 6),
      _logRow('local_078', 'Greek Yogurt (plain)',   'Eggs & Dairy',      200, 116, 10.0,  5.0,  3.8,  3.8,  80.0,  0.0, 'snack',     date(11), now, -11, 7),

      // ── Day 10 (~2560 kcal — over goal, breaks streak) ──────────────────
      _logRow('local_079', 'Eggs Benedict',          'Meals',             280, 560, 26.0, 38.0, 28.0,  4.0, 980.0,  1.5, 'breakfast', date(10), now, -10, 0),
      _logRow('local_080', 'Orange Juice',           'Beverages',         250, 108,  1.7,  0.2, 25.0, 22.5,   5.0,  0.5, 'breakfast', date(10), now, -10, 1),
      _logRow('local_081', 'BLT Sandwich',           'Bread & Bakery',    280, 480, 24.0, 22.0, 46.0,  6.0, 920.0,  3.5, 'lunch',     date(10), now, -10, 2),
      _logRow('local_082', 'Packet Crisps',          'Snacks',             50, 265,  3.5, 17.5, 26.0,  0.8, 630.0,  1.5, 'snack',     date(10), now, -10, 3),
      _logRow('local_083', 'Beef Steak',             'Red Meat',          280, 608, 64.4, 39.2,  0.0,  0.0, 238.0,  0.0, 'dinner',    date(10), now, -10, 4),
      _logRow('local_084', 'Peppercorn Sauce',       'Condiments',         80, 200,  2.5, 18.0,  8.0,  4.0, 400.0,  0.0, 'dinner',    date(10), now, -10, 5),
      _logRow('local_085', 'Roasted Potatoes',       'Vegetables',        180, 268,  3.6,  9.0, 41.4,  1.8, 360.0,  4.1, 'dinner',    date(10), now, -10, 6),

      // ── Day 9 (~1660 kcal — good day) ───────────────────────────────────
      _logRow('local_086', 'Porridge (Oats)',        'Breakfast Cereals', 250, 335, 11.0,  6.5, 57.0,  1.3,  18.0,  4.5, 'breakfast', date(9), now, -9, 0),
      _logRow('local_087', 'Banana',                 'Fruits',            100,  89,  1.1,  0.3, 23.0, 12.0,   1.0,  2.6, 'breakfast', date(9), now, -9, 1),
      _logRow('local_088', 'Tuna (in water)',        'Fish & Seafood',    160, 160, 35.7,  1.3,  0.0,  0.0, 406.0,  0.0, 'lunch',     date(9), now, -9, 2),
      _logRow('local_089', 'Mixed Salad',            'Salads',            200,  36,  2.4,  0.4,  6.4,  2.0,  40.0,  2.8, 'lunch',     date(9), now, -9, 3),
      _logRow('local_090', 'Wholegrain Crackers',    'Bread & Bakery',     40, 168,  4.0,  4.8, 28.0,  2.0, 280.0,  2.8, 'lunch',     date(9), now, -9, 4),
      _logRow('local_091', 'Grilled Chicken',        'Poultry',           200, 330, 62.0,  7.2,  0.0,  0.0, 200.0,  0.0, 'dinner',    date(9), now, -9, 5),
      _logRow('local_092', 'Pasta (cooked)',         'Grains',            180, 234,  8.6,  1.1, 48.6,  1.4,   3.6,  2.3, 'dinner',    date(9), now, -9, 6),
      _logRow('local_093', 'Tomato Sauce',           'Condiments',        100,  65,  2.5,  0.5, 12.0,  8.0, 380.0,  2.0, 'dinner',    date(9), now, -9, 7),
      _logRow('local_094', 'Apple',                  'Fruits',            150,  78,  0.5,  0.3, 21.0, 15.0,   2.0,  3.6, 'snack',     date(9), now, -9, 8),

      // ── Day 8 (~2490 kcal — over goal, breaks streak) ────────────────────
      _logRow('local_095', 'Avocado Toast',          'Bread & Bakery',    180, 368,  7.8, 22.0, 33.0,  2.4, 340.0,  7.2, 'breakfast', date(8), now, -8, 0),
      _logRow('local_096', 'Poached Eggs (2)',       'Eggs & Dairy',      100, 155, 13.0, 11.0,  0.8,  0.7, 250.0,  0.0, 'breakfast', date(8), now, -8, 1),
      _logRow('local_097', 'Flat White Coffee',      'Beverages',         240, 130,  7.2,  6.5, 13.0, 13.0,  90.0,  0.0, 'breakfast', date(8), now, -8, 2),
      _logRow('local_098', 'Margherita Pizza (3sl)', 'Fast Food',         390, 898, 31.2, 31.2,113.1, 11.7,1638.0,  5.9, 'lunch',     date(8), now, -8, 3),
      _logRow('local_099', 'Garlic Bread',           'Bread & Bakery',     80, 248,  5.6, 10.4, 34.0,  2.0, 480.0,  2.0, 'lunch',     date(8), now, -8, 4),
      _logRow('local_100', 'Grilled Salmon',         'Fish & Seafood',    180, 371, 39.6, 23.4,  0.0,  0.0, 121.0,  0.0, 'dinner',    date(8), now, -8, 5),
      _logRow('local_101', 'Roasted Asparagus',      'Vegetables',        150,  40,  4.4,  0.4,  7.5,  3.0,   6.0,  3.8, 'dinner',    date(8), now, -8, 6),
      _logRow('local_102', 'Quinoa (cooked)',        'Grains',            150, 195,  7.1,  3.1, 34.5,  1.4, 150.0,  4.1, 'dinner',    date(8), now, -8, 7),
      _logRow('local_103', 'Dark Chocolate',         'Desserts',           35, 187,  2.5, 14.0, 18.0, 14.0,   7.0,  3.2, 'snack',     date(8), now, -8, 8),

      // ── Day 7 (~1865 kcal — STREAK DAY 1) ───────────────────────────────
      _logRow('local_104', 'Porridge (Oats)',        'Breakfast Cereals', 300, 402, 15.0,  7.8, 68.0,  1.5,  21.0,  5.4, 'breakfast', date(7), now, -7, 0),
      _logRow('local_105', 'Banana',                 'Fruits',            120, 107,  1.3,  0.4, 27.0, 14.0,   1.0,  3.1, 'breakfast', date(7), now, -7, 1),
      _logRow('local_106', 'Chicken Breast',         'Poultry',           200, 330, 62.0,  7.2,  0.0,  0.0, 200.0,  0.0, 'lunch',     date(7), now, -7, 2),
      _logRow('local_107', 'Brown Rice (cooked)',    'Grains',            180, 236,  4.9,  2.0, 49.0,  0.4,   9.0,  2.2, 'lunch',     date(7), now, -7, 3),
      _logRow('local_108', 'Broccoli (steamed)',     'Vegetables',        150,  53,  4.2,  0.6,  9.0,  2.3,  60.0,  3.9, 'lunch',     date(7), now, -7, 4),
      _logRow('local_109', 'Salmon Fillet',          'Fish & Seafood',    180, 371, 39.6, 23.4,  0.0,  0.0, 121.0,  0.0, 'dinner',    date(7), now, -7, 5),
      _logRow('local_110', 'Sweet Potato (baked)',   'Vegetables',        150, 129,  2.4,  0.2, 30.0,  6.0,  56.0,  3.8, 'dinner',    date(7), now, -7, 6),
      _logRow('local_111', 'Mixed Salad Leaves',     'Salads',            100,  14,  1.2,  0.2,  2.4,  0.8,  28.0,  1.4, 'dinner',    date(7), now, -7, 7),
      _logRow('local_112', 'Almonds',                'Nuts & Seeds',       25, 145,  5.3, 12.5,  4.8,  0.9,   1.0,  1.8, 'snack',     date(7), now, -7, 8),
      _logRow('local_113', 'Apple',                  'Fruits',            150,  78,  0.5,  0.3, 21.0, 15.0,   2.0,  3.6, 'snack',     date(7), now, -7, 9),

      // ── Day 6 (~1980 kcal — STREAK DAY 2) ───────────────────────────────
      _logRow('local_114', 'Scrambled Eggs (2)',     'Eggs & Dairy',      120, 192, 14.0, 14.0,  1.2,  1.0, 300.0,  0.0, 'breakfast', date(6), now, -6, 0),
      _logRow('local_115', 'Wholegrain Toast (2)',   'Bread & Bakery',    100, 230,  9.0,  2.4, 44.0,  3.5, 400.0,  5.4, 'breakfast', date(6), now, -6, 1),
      _logRow('local_116', 'Orange Juice',           'Beverages',         200,  86,  1.4,  0.2, 20.0, 18.0,   4.0,  0.4, 'breakfast', date(6), now, -6, 2),
      _logRow('local_117', 'Chicken Breast',         'Poultry',           200, 330, 62.0,  7.2,  0.0,  0.0, 200.0,  0.0, 'lunch',     date(6), now, -6, 3),
      _logRow('local_118', 'Mixed Salad',            'Salads',            200,  36,  2.4,  0.4,  6.4,  2.0,  40.0,  2.8, 'lunch',     date(6), now, -6, 4),
      _logRow('local_119', 'Wholegrain Bread',       'Bread & Bakery',     60, 138,  5.4,  1.4, 26.0,  2.3, 240.0,  3.6, 'lunch',     date(6), now, -6, 5),
      _logRow('local_120', 'Beef Stir Fry',          'Red Meat',          200, 380, 32.0, 22.0,  8.0,  4.0, 640.0,  2.0, 'dinner',    date(6), now, -6, 6),
      _logRow('local_121', 'Egg Noodles (cooked)',   'Grains',            150, 206,  7.2,  2.3, 40.0,  1.5,  18.0,  1.5, 'dinner',    date(6), now, -6, 7),
      _logRow('local_122', 'Steamed Broccoli',       'Vegetables',        150,  53,  4.2,  0.6,  9.0,  2.3,  60.0,  3.9, 'dinner',    date(6), now, -6, 8),
      _logRow('local_123', 'Protein Bar',            'Supplements',        60, 228, 20.0,  8.0, 26.0, 10.0, 120.0,  4.0, 'snack',     date(6), now, -6, 9),
      _logRow('local_124', 'Mixed Berries',          'Fruits',            100,  57,  0.8,  0.5, 14.0,  9.0,   2.0,  2.0, 'snack',     date(6), now, -6, 10),

      // ── Day 5 (~1835 kcal — STREAK DAY 3) ───────────────────────────────
      _logRow('local_125', 'Greek Yogurt (plain)',   'Eggs & Dairy',      200, 116, 10.0,  5.0,  3.8,  3.8,  80.0,  0.0, 'breakfast', date(5), now, -5, 0),
      _logRow('local_126', 'Granola',                'Breakfast Cereals',  60, 279,  7.5, 12.0, 36.0, 12.0,  60.0,  3.6, 'breakfast', date(5), now, -5, 1),
      _logRow('local_127', 'Banana',                 'Fruits',            120, 107,  1.3,  0.4, 27.0, 14.0,   1.0,  3.1, 'breakfast', date(5), now, -5, 2),
      _logRow('local_128', 'Chicken Breast',         'Poultry',           200, 330, 62.0,  7.2,  0.0,  0.0, 200.0,  0.0, 'lunch',     date(5), now, -5, 3),
      _logRow('local_129', 'Quinoa (cooked)',        'Grains',            180, 234,  8.5,  3.7, 41.0,  1.7, 180.0,  5.0, 'lunch',     date(5), now, -5, 4),
      _logRow('local_130', 'Cucumber & Peppers',     'Vegetables',        150,  38,  1.5,  0.3,  7.5,  4.5,   8.0,  2.0, 'lunch',     date(5), now, -5, 5),
      _logRow('local_131', 'Turkey Breast (grilled)','Poultry',           200, 270, 60.0,  3.0,  0.0,  0.0, 100.0,  0.0, 'dinner',    date(5), now, -5, 6),
      _logRow('local_132', 'Roasted Sweet Potato',   'Vegetables',        180, 155,  2.9,  0.3, 36.0,  7.2,  67.0,  4.5, 'dinner',    date(5), now, -5, 7),
      _logRow('local_133', 'Steamed Broccoli',       'Vegetables',        150,  53,  4.2,  0.6,  9.0,  2.3,  60.0,  3.9, 'dinner',    date(5), now, -5, 8),
      _logRow('local_134', 'Almonds',                'Nuts & Seeds',       30, 174,  6.3, 15.0,  5.8,  1.1,   1.0,  2.1, 'snack',     date(5), now, -5, 9),

      // ── Day 4 (~1880 kcal — STREAK DAY 4) ───────────────────────────────
      _logRow('local_135', 'Porridge (Oats)',        'Breakfast Cereals', 300, 402, 15.0,  7.8, 68.0,  1.5,  21.0,  5.4, 'breakfast', date(4), now, -4, 0),
      _logRow('local_136', 'Mixed Berries',          'Fruits',            100,  57,  0.8,  0.5, 14.0,  9.0,   2.0,  2.0, 'breakfast', date(4), now, -4, 1),
      _logRow('local_137', 'Lentil Soup',            'Legumes',           400, 320, 20.0,  4.0, 52.0,  7.0, 548.0, 10.8, 'lunch',     date(4), now, -4, 2),
      _logRow('local_138', 'Wholegrain Bread',       'Bread & Bakery',     80, 184,  7.2,  2.0, 34.0,  3.0, 320.0,  4.8, 'lunch',     date(4), now, -4, 3),
      _logRow('local_139', 'Salmon Fillet',          'Fish & Seafood',    200, 412, 44.0, 26.0,  0.0,  0.0, 134.0,  0.0, 'dinner',    date(4), now, -4, 4),
      _logRow('local_140', 'Asparagus (steamed)',    'Vegetables',        150,  33,  3.6,  0.3,  6.3,  2.5,   5.0,  3.0, 'dinner',    date(4), now, -4, 5),
      _logRow('local_141', 'Brown Rice (cooked)',    'Grains',            160, 210,  4.4,  1.8, 44.0,  0.4,   8.0,  1.8, 'dinner',    date(4), now, -4, 6),
      _logRow('local_142', 'Greek Yogurt (plain)',   'Eggs & Dairy',      200, 116, 10.0,  5.0,  3.8,  3.8,  80.0,  0.0, 'snack',     date(4), now, -4, 7),
      _logRow('local_143', 'Almonds',                'Nuts & Seeds',       25, 145,  5.3, 12.5,  4.8,  0.9,   1.0,  1.8, 'snack',     date(4), now, -4, 8),

      // ── Day 3 (~1875 kcal — STREAK DAY 5) ───────────────────────────────
      _logRow('local_144', 'Scrambled Eggs (2)',     'Eggs & Dairy',      120, 192, 14.0, 14.0,  1.2,  1.0, 300.0,  0.0, 'breakfast', date(3), now, -3, 0),
      _logRow('local_145', 'Smoked Salmon',          'Fish & Seafood',     80, 141, 18.8,  7.2,  0.0,  0.0, 800.0,  0.0, 'breakfast', date(3), now, -3, 1),
      _logRow('local_146', 'Wholegrain Toast',       'Bread & Bakery',     80, 184,  7.2,  1.9, 35.0,  2.8, 320.0,  4.3, 'breakfast', date(3), now, -3, 2),
      _logRow('local_147', 'Turkey Breast (grilled)','Poultry',           220, 297, 66.0,  3.3,  0.0,  0.0, 110.0,  0.0, 'lunch',     date(3), now, -3, 3),
      _logRow('local_148', 'Quinoa (cooked)',        'Grains',            180, 234,  8.5,  3.7, 41.0,  1.7, 180.0,  5.0, 'lunch',     date(3), now, -3, 4),
      _logRow('local_149', 'Mixed Salad',            'Salads',            150,  27,  1.8,  0.3,  4.8,  1.5,  30.0,  2.1, 'lunch',     date(3), now, -3, 5),
      _logRow('local_150', 'Chicken Breast',         'Poultry',           180, 297, 55.8,  6.5,  0.0,  0.0, 180.0,  0.0, 'dinner',    date(3), now, -3, 6),
      _logRow('local_151', 'Roasted Broccoli',       'Vegetables',        200,  80,  6.0,  1.1, 12.0,  3.1,  87.0,  5.3, 'dinner',    date(3), now, -3, 7),
      _logRow('local_152', 'Sweet Potato (baked)',   'Vegetables',        180, 155,  2.9,  0.3, 36.0,  7.2,  67.0,  4.5, 'dinner',    date(3), now, -3, 8),
      _logRow('local_153', 'Apple',                  'Fruits',            150,  78,  0.5,  0.3, 21.0, 15.0,   2.0,  3.6, 'snack',     date(3), now, -3, 9),

      // ── Day 2 (~2135 kcal — STREAK DAY 6) ───────────────────────────────
      _logRow('local_154', 'Porridge (Oats)',        'Breakfast Cereals', 300, 402, 15.0,  7.8, 68.0,  1.5,  21.0,  5.4, 'breakfast', date(2), now, -2, 0),
      _logRow('local_155', 'Banana',                 'Fruits',            120, 107,  1.3,  0.4, 27.0, 14.0,   1.0,  3.1, 'breakfast', date(2), now, -2, 1),
      _logRow('local_156', 'Protein Shake',          'Supplements',       300, 150, 30.0,  2.5, 10.0,  6.0, 200.0,  0.0, 'breakfast', date(2), now, -2, 2),
      _logRow('local_157', 'Chicken Curry',          'Meals',             320, 448, 30.2, 19.2, 25.6,  6.4, 768.0,  3.2, 'lunch',     date(2), now, -2, 3),
      _logRow('local_158', 'Basmati Rice (cooked)',  'Grains',            200, 260,  5.6,  0.5, 58.0,  0.2,   4.0,  0.5, 'lunch',     date(2), now, -2, 4),
      _logRow('local_159', 'Salmon Fillet',          'Fish & Seafood',    180, 371, 39.6, 23.4,  0.0,  0.0, 121.0,  0.0, 'dinner',    date(2), now, -2, 5),
      _logRow('local_160', 'Steamed Broccoli',       'Vegetables',        150,  53,  4.2,  0.6,  9.0,  2.3,  60.0,  3.9, 'dinner',    date(2), now, -2, 6),
      _logRow('local_161', 'Roasted Sweet Potato',   'Vegetables',        150, 129,  2.4,  0.2, 30.0,  6.0,  56.0,  3.8, 'dinner',    date(2), now, -2, 7),
      _logRow('local_162', 'Greek Yogurt (plain)',   'Eggs & Dairy',      200, 116, 10.0,  5.0,  3.8,  3.8,  80.0,  0.0, 'snack',     date(2), now, -2, 8),
      _logRow('local_163', 'Mixed Berries',          'Fruits',            100,  57,  0.8,  0.5, 14.0,  9.0,   2.0,  2.0, 'snack',     date(2), now, -2, 9),

      // ── Day 1 (~1918 kcal — STREAK DAY 7) ───────────────────────────────
      _logRow('local_164', 'Scrambled Eggs (2)',     'Eggs & Dairy',      120, 192, 14.0, 14.0,  1.2,  1.0, 300.0,  0.0, 'breakfast', date(1), now, -1, 0),
      _logRow('local_165', 'Wholegrain Toast (2)',   'Bread & Bakery',    100, 230,  9.0,  2.4, 44.0,  3.5, 400.0,  5.4, 'breakfast', date(1), now, -1, 1),
      _logRow('local_166', 'Orange Juice',           'Beverages',         200,  86,  1.4,  0.2, 20.0, 18.0,   4.0,  0.4, 'breakfast', date(1), now, -1, 2),
      _logRow('local_167', 'Tuna Salad',             'Fish & Seafood',    250, 310, 36.0, 10.0, 14.0,  3.0, 420.0,  3.2, 'lunch',     date(1), now, -1, 3),
      _logRow('local_168', 'Wholegrain Bread',       'Bread & Bakery',     60, 138,  5.4,  1.4, 26.0,  2.3, 240.0,  3.6, 'lunch',     date(1), now, -1, 4),
      _logRow('local_169', 'Chicken Breast',         'Poultry',           200, 330, 62.0,  7.2,  0.0,  0.0, 200.0,  0.0, 'dinner',    date(1), now, -1, 5),
      _logRow('local_170', 'Brown Rice (cooked)',    'Grains',            180, 236,  4.9,  2.0, 49.0,  0.4,   9.0,  2.2, 'dinner',    date(1), now, -1, 6),
      _logRow('local_171', 'Stir Fried Vegetables',  'Vegetables',        200,  90,  4.0,  3.0, 12.0,  5.0,  60.0,  4.0, 'dinner',    date(1), now, -1, 7),
      _logRow('local_172', 'Protein Bar',            'Supplements',        60, 228, 20.0,  8.0, 26.0, 10.0, 120.0,  4.0, 'snack',     date(1), now, -1, 8),
      _logRow('local_173', 'Apple',                  'Fruits',            150,  78,  0.5,  0.3, 21.0, 15.0,   2.0,  3.6, 'snack',     date(1), now, -1, 9),

      // ── Today / Day 0 (~1409 kcal partial — STREAK DAY 8) ────────────────
      _logRow('local_174', 'Porridge (Oats)',        'Breakfast Cereals', 300, 402, 15.0,  7.8, 68.0,  1.5,  21.0,  5.4, 'breakfast', date(0), now, 0, 0),
      _logRow('local_175', 'Blueberries',            'Fruits',            100,  57,  0.7,  0.3, 14.0,  9.7,   1.0,  2.4, 'breakfast', date(0), now, 0, 1),
      _logRow('local_176', 'Protein Shake',          'Supplements',       300, 150, 30.0,  2.5, 10.0,  6.0, 200.0,  0.0, 'breakfast', date(0), now, 0, 2),
      _logRow('local_177', 'Grilled Chicken',        'Poultry',           200, 330, 62.0,  7.2,  0.0,  0.0, 200.0,  0.0, 'lunch',     date(0), now, 0, 3),
      _logRow('local_178', 'Quinoa Salad',           'Salads',            250, 325, 11.9,  5.1, 57.0,  2.4, 250.0,  6.9, 'lunch',     date(0), now, 0, 4),
      _logRow('local_179', 'Almonds',                'Nuts & Seeds',       25, 145,  5.3, 12.5,  4.8,  0.9,   1.0,  1.8, 'snack',     date(0), now, 0, 5),
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

  // ── Nutrition rolling averages ─────────────────────────────────────────────

  /// Returns daily nutrition averages over the last [days] calendar days
  /// that have at least one food log entry.
  ///
  /// Keys: 'calories', 'protein', 'fat', 'carbs', 'sugar', 'fiber', 'days'
  /// 'days' is the number of days with data in the window.
  static Future<Map<String, double>> getRollingAverages(int days) async {
    final db = await database;
    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: days - 1));
    final startStr =
        '${startDate.year}-'
        '${startDate.month.toString().padLeft(2, '0')}-'
        '${startDate.day.toString().padLeft(2, '0')}';

    final result = await db.rawQuery('''
      SELECT
        AVG(dc) AS avg_cal,
        AVG(dp) AS avg_pro,
        AVG(df) AS avg_fat,
        AVG(dcarbs) AS avg_carbs,
        AVG(ds) AS avg_sug,
        AVG(dfi) AS avg_fib,
        COUNT(*) AS days_with_data
      FROM (
        SELECT
          logged_date,
          SUM(calories)   AS dc,
          SUM(protein_g)  AS dp,
          SUM(fat_g)      AS df,
          SUM(carbs_g)    AS dcarbs,
          SUM(sugar_g)    AS ds,
          SUM(fiber_g)    AS dfi
        FROM food_log
        WHERE logged_date >= ?
        GROUP BY logged_date
      )
    ''', [startStr]);

    if (result.isEmpty || result.first['avg_cal'] == null) {
      return {
        'calories': 0, 'protein': 0, 'fat': 0,
        'carbs': 0, 'sugar': 0, 'fiber': 0, 'days': 0,
      };
    }
    final row = result.first;
    return {
      'calories': (row['avg_cal'] as num).toDouble(),
      'protein':  (row['avg_pro'] as num).toDouble(),
      'fat':      (row['avg_fat'] as num).toDouble(),
      'carbs':    (row['avg_carbs'] as num).toDouble(),
      'sugar':    (row['avg_sug'] as num).toDouble(),
      'fiber':    (row['avg_fib'] as num).toDouble(),
      'days':     (row['days_with_data'] as num).toDouble(),
    };
  }

  /// Returns food log entries between [startDate] and [endDate] inclusive
  /// (format 'YYYY-MM-DD'), ordered by date ascending then logged_at.
  static Future<List<FoodLogEntry>> getFoodLogForDateRange(
      String startDate, String endDate) async {
    final db = await database;
    final rows = await db.query(
      'food_log',
      where: 'logged_date >= ? AND logged_date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'logged_date ASC, logged_at ASC',
    );
    return rows.map(FoodLogEntry.fromMap).toList();
  }
}
