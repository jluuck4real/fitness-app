import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/user_model.dart';
import '../models/workout_history_model.dart';
import '../models/weight_history_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  static Database? _database;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();

    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;

      return await databaseFactory.openDatabase(
        'fitness_pro_web.db',
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: _createDatabase,
          onUpgrade: _upgradeDatabase,
        ),
      );
    }

    final databasePath = await getDatabasesPath();

    final path = join(databasePath, 'fitness_pro.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        weight REAL NOT NULL,
        height REAL NOT NULL,
        goal TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutName TEXT NOT NULL,
        duration INTEGER NOT NULL,
        calories INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE weight_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weight REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS weight_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          weight REAL NOT NULL,
          date TEXT NOT NULL
        )
      ''');
    }
  }

  Future<int> insertUser(UserModel user) async {
    final db = await database;

    return await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserModel?> getUser() async {
    final db = await database;

    final result = await db.query('users', limit: 1);

    if (result.isEmpty) {
      return null;
    }

    return UserModel.fromMap(result.first);
  }

  Future<int> updateUser(UserModel user) async {
    final db = await database;

    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> insertWorkout(WorkoutHistoryModel workout) async {
    final db = await database;

    return await db.insert('workout_history', workout.toMap());
  }

  Future<List<WorkoutHistoryModel>> getWorkoutHistory() async {
    final db = await database;

    final result = await db.query('workout_history', orderBy: 'id DESC');

    return result.map((map) => WorkoutHistoryModel.fromMap(map)).toList();
  }

  Future<int> getTotalCalories() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT SUM(calories) as total FROM workout_history',
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> getTotalWorkouts() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM workout_history',
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> getTotalDuration() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT SUM(duration) as total FROM workout_history',
    );

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> insertWeight(WeightHistoryModel weight) async {
    final db = await database;

    return await db.insert('weight_history', weight.toMap());
  }

  Future<List<WeightHistoryModel>> getWeightHistory() async {
    final db = await database;

    final result = await db.query('weight_history', orderBy: 'id ASC');

    return result.map((map) => WeightHistoryModel.fromMap(map)).toList();
  }

  Future<WeightHistoryModel?> getLatestWeight() async {
    final db = await database;

    final result = await db.query(
      'weight_history',
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return WeightHistoryModel.fromMap(result.first);
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
