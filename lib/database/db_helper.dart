import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'meal.dart';

class DbHelper {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'diet_plan.db');
return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        calories INTEGER NOT NULL
      )
    ''');

    await db.insert('meals', const Meal(
      name: 'Breakfast',
      description: 'Oats, banana, eggs',
      calories: 520,
    ).toMap());

    await db.insert('meals', const Meal(
      name: 'Lunch',
      description: 'Chicken, rice, broccoli',
      calories: 680,
    ).toMap());

    await db.insert('meals', const Meal(
      name: 'Dinner',
      description: 'Salmon, sweet potato, salad',
      calories: 600,
    ).toMap());
  }

  static Future<List<Meal>> getMeals() async {
    final db = await database;
    final rows = await db.query('meals');
    return rows.map(Meal.fromMap).toList();
  }
}
