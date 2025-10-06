import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/fit_test.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'insanity_tracker.db';
  static const int _databaseVersion = 2; // Updated version

  // Singleton pattern - only one instance of DatabaseService
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  // Get database instance
  Future<Database> get database async {
    if (_database == null || !_database!.isOpen) {
      debugPrint("Database is null or closed, re-initializing...");
      _database = await _initDatabase();
    }
    return _database!;
  }

  // --- NEW: Method to get the database path ---
  Future<String> getDatabasePath() async {
    return join(await getDatabasesPath(), _databaseName);
  }

  // --- NEW: Method to re-initialize the database ---
  Future<void> reinitializeDatabase() async {
    _database = await _initDatabase();
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Handle database upgrades
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration from version 1 to 2
      await db.execute('DROP TABLE IF EXISTS workouts');
      await _createNewSchema(db);
      await _populateWorkoutData(db);
    }
  }

  // Create tables
  Future _onCreate(Database db, int version) async {
    await _createNewSchema(db);
    await _populateWorkoutData(db);
  }

  // Create the new normalized schema
  Future _createNewSchema(Database db) async {
    // Workout info table (reference data)
    await db.execute('''
      CREATE TABLE workout_info (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL
      )
    ''');

    // Workouts schedule table (70-day program)
    await db.execute('''
      CREATE TABLE workouts (
        day_number INTEGER PRIMARY KEY,
        week_number INTEGER NOT NULL,
        workout_id INTEGER NOT NULL,
        workout_type TEXT NOT NULL CHECK(workout_type IN ('workout', 'fit_test', 'rest')),
        FOREIGN KEY (workout_id) REFERENCES workout_info (id)
      )
    ''');

    // Create view for easy querying (combines both tables)
    await db.execute('''
      CREATE VIEW workouts_view AS
      SELECT 
        w.day_number as id,
        wi.name,
        w.day_number,
        w.week_number,
        w.workout_type,
        wi.duration_minutes
      FROM workouts w
      JOIN workout_info wi ON w.workout_id = wi.id
    ''');

    // Workout sessions table (user data)
    await db.execute('''
      CREATE TABLE workout_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (workout_id) REFERENCES workouts (day_number)
      )
    ''');

    // Fit test results table
    await db.execute('''
      CREATE TABLE fit_test_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        test_date TEXT NOT NULL,
        test_number INTEGER NOT NULL,
        switch_kicks INTEGER NOT NULL,
        power_jacks INTEGER NOT NULL,
        power_knees INTEGER NOT NULL,
        power_jumps INTEGER NOT NULL,
        globe_jumps INTEGER NOT NULL,
        suicide_jumps INTEGER NOT NULL,
        pushup_jacks INTEGER NOT NULL,
        low_plank_oblique INTEGER NOT NULL,
        notes TEXT
      )
    ''');
  }

  // Populate workout data
  Future _populateWorkoutData(Database db) async {
    // Insert workout reference data
    await _populateWorkoutInfo(db);
    // Insert 70-day schedule
    await _populateWorkouts(db);
  }

  // Populate workout_info table
  Future _populateWorkoutInfo(Database db) async {
    List<Map<String, dynamic>> workoutInfo = [
      {'id': 1, 'name': 'Fit Test', 'duration_minutes': 26},
      {'id': 2, 'name': 'Plyometric Cardio Circuit', 'duration_minutes': 42},
      {'id': 3, 'name': 'Cardio Power & Resistance', 'duration_minutes': 40},
      {'id': 4, 'name': 'Cardio Recovery', 'duration_minutes': 33},
      {'id': 5, 'name': 'Pure Cardio', 'duration_minutes': 39},
      {'id': 6, 'name': 'Pure Cardio & Cardio Abs', 'duration_minutes': 56},
      {'id': 7, 'name': 'Core Cardio & Balance', 'duration_minutes': 38},
      {'id': 8, 'name': 'Fit Test & Max Interval Circuit', 'duration_minutes': 86},
      {'id': 9, 'name': 'Max Interval Circuit', 'duration_minutes': 60},
      {'id': 10, 'name': 'Max Interval Plyo', 'duration_minutes': 56},
      {'id': 11, 'name': 'Max Cardio Conditioning', 'duration_minutes': 48},
      {'id': 12, 'name': 'Max Recovery', 'duration_minutes': 48},
      {'id': 13, 'name': 'Max Cardio Conditioning & Cardio Abs', 'duration_minutes': 65},
      {'id': 14, 'name': 'Rest Day', 'duration_minutes': 0},
    ];

    for (var workout in workoutInfo) {
      await db.insert('workout_info', workout);
    }
  }

  // Populate workouts table with 70-day schedule
  Future _populateWorkouts(Database db) async {
    List<Map<String, dynamic>> workouts = [
      // Week 1
      {'day_number': 1, 'week_number': 1, 'workout_id': 1, 'workout_type': 'fit_test'},
      {'day_number': 2, 'week_number': 1, 'workout_id': 2, 'workout_type': 'workout'},
      {'day_number': 3, 'week_number': 1, 'workout_id': 3, 'workout_type': 'workout'},
      {'day_number': 4, 'week_number': 1, 'workout_id': 4, 'workout_type': 'workout'},
      {'day_number': 5, 'week_number': 1, 'workout_id': 5, 'workout_type': 'workout'},
      {'day_number': 6, 'week_number': 1, 'workout_id': 2, 'workout_type': 'workout'},
      {'day_number': 7, 'week_number': 1, 'workout_id': 14, 'workout_type': 'rest'},

      // Week 2
      {'day_number': 8, 'week_number': 2, 'workout_id': 3, 'workout_type': 'workout'},
      {'day_number': 9, 'week_number': 2, 'workout_id': 5, 'workout_type': 'workout'},
      {'day_number': 10, 'week_number': 2, 'workout_id': 2, 'workout_type': 'workout'},
      {'day_number': 11, 'week_number': 2, 'workout_id': 4, 'workout_type': 'workout'},
      {'day_number': 12, 'week_number': 2, 'workout_id': 3, 'workout_type': 'workout'},
      {'day_number': 13, 'week_number': 2, 'workout_id': 6, 'workout_type': 'workout'},
      {'day_number': 14, 'week_number': 2, 'workout_id': 14, 'workout_type': 'rest'},

      // Week 3
      {'day_number': 15, 'week_number': 3, 'workout_id': 1, 'workout_type': 'fit_test'},
      {'day_number': 16, 'week_number': 3, 'workout_id': 2, 'workout_type': 'workout'},
      {'day_number': 17, 'week_number': 3, 'workout_id': 6, 'workout_type': 'workout'},
      {'day_number': 18, 'week_number': 3, 'workout_id': 4, 'workout_type': 'workout'},
      {'day_number': 19, 'week_number': 3, 'workout_id': 3, 'workout_type': 'workout'},
      {'day_number': 20, 'week_number': 3, 'workout_id': 2, 'workout_type': 'workout'},
      {'day_number': 21, 'week_number': 3, 'workout_id': 14, 'workout_type': 'rest'},

      // Week 4
      {'day_number': 22, 'week_number': 4, 'workout_id': 6, 'workout_type': 'workout'},
      {'day_number': 23, 'week_number': 4, 'workout_id': 3, 'workout_type': 'workout'},
      {'day_number': 24, 'week_number': 4, 'workout_id': 2, 'workout_type': 'workout'},
      {'day_number': 25, 'week_number': 4, 'workout_id': 4, 'workout_type': 'workout'},
      {'day_number': 26, 'week_number': 4, 'workout_id': 6, 'workout_type': 'workout'},
      {'day_number': 27, 'week_number': 4, 'workout_id': 2, 'workout_type': 'workout'},
      {'day_number': 28, 'week_number': 4, 'workout_id': 14, 'workout_type': 'rest'},

      // Week 5 - Recovery Week
      {'day_number': 29, 'week_number': 5, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 30, 'week_number': 5, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 31, 'week_number': 5, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 32, 'week_number': 5, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 33, 'week_number': 5, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 34, 'week_number': 5, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 35, 'week_number': 5, 'workout_id': 14, 'workout_type': 'rest'},

      // Week 6 - Month 2 begins
      {'day_number': 36, 'week_number': 6, 'workout_id': 8, 'workout_type': 'fit_test'},
      {'day_number': 37, 'week_number': 6, 'workout_id': 10, 'workout_type': 'workout'},
      {'day_number': 38, 'week_number': 6, 'workout_id': 11, 'workout_type': 'workout'},
      {'day_number': 39, 'week_number': 6, 'workout_id': 12, 'workout_type': 'workout'},
      {'day_number': 40, 'week_number': 6, 'workout_id': 9, 'workout_type': 'workout'},
      {'day_number': 41, 'week_number': 6, 'workout_id': 10, 'workout_type': 'workout'},
      {'day_number': 42, 'week_number': 6, 'workout_id': 14, 'workout_type': 'rest'},

      // Week 7
      {'day_number': 43, 'week_number': 7, 'workout_id': 11, 'workout_type': 'workout'},
      {'day_number': 44, 'week_number': 7, 'workout_id': 9, 'workout_type': 'workout'},
      {'day_number': 45, 'week_number': 7, 'workout_id': 10, 'workout_type': 'workout'},
      {'day_number': 46, 'week_number': 7, 'workout_id': 12, 'workout_type': 'workout'},
      {'day_number': 47, 'week_number': 7, 'workout_id': 13, 'workout_type': 'workout'},
      {'day_number': 48, 'week_number': 7, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 49, 'week_number': 7, 'workout_id': 14, 'workout_type': 'rest'},

      // Week 8
      {'day_number': 50, 'week_number': 8, 'workout_id': 8, 'workout_type': 'fit_test'},
      {'day_number': 51, 'week_number': 8, 'workout_id': 10, 'workout_type': 'workout'},
      {'day_number': 52, 'week_number': 8, 'workout_id': 13, 'workout_type': 'workout'},
      {'day_number': 53, 'week_number': 8, 'workout_id': 12, 'workout_type': 'workout'},
      {'day_number': 54, 'week_number': 8, 'workout_id': 9, 'workout_type': 'workout'},
      {'day_number': 55, 'week_number': 8, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 56, 'week_number': 8, 'workout_id': 14, 'workout_type': 'rest'},

      // Week 9
      {'day_number': 57, 'week_number': 9, 'workout_id': 10, 'workout_type': 'workout'},
      {'day_number': 58, 'week_number': 9, 'workout_id': 13, 'workout_type': 'workout'},
      {'day_number': 59, 'week_number': 9, 'workout_id': 9, 'workout_type': 'workout'},
      {'day_number': 60, 'week_number': 9, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 61, 'week_number': 9, 'workout_id': 10, 'workout_type': 'workout'},
      {'day_number': 62, 'week_number': 9, 'workout_id': 13, 'workout_type': 'workout'},
      {'day_number': 63, 'week_number': 9, 'workout_id': 14, 'workout_type': 'rest'},

      // Week 10 - Additional Recovery Week
      {'day_number': 64, 'week_number': 10, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 65, 'week_number': 10, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 66, 'week_number': 10, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 67, 'week_number': 10, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 68, 'week_number': 10, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 69, 'week_number': 10, 'workout_id': 7, 'workout_type': 'workout'},
      {'day_number': 70, 'week_number': 10, 'workout_id': 14, 'workout_type': 'rest'},
    ];

    for (var workout in workouts) {
      await db.insert('workouts', workout);
    }
  }

  // WORKOUT CRUD OPERATIONS
  Future<List<Workout>> getAllWorkouts() async {
    final db = await database;
    // Query the view instead of the table
    final List<Map<String, dynamic>> maps = await db.query('workouts_view');
    return List.generate(maps.length, (i) => Workout.fromMap(maps[i]));
  }

  Future<Workout?> getWorkout(int id) async {
    final db = await database;
    // Query the view instead of the table
    final List<Map<String, dynamic>> maps = await db.query(
      'workouts_view',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Workout.fromMap(maps.first);
    }
    return null;
  }

  // WORKOUT SESSION CRUD OPERATIONS
  Future<int> insertWorkoutSession(WorkoutSession session) async {
    final db = await database;
    return await db.insert('workout_sessions', session.toMap());
  }

  Future<List<WorkoutSession>> getAllWorkoutSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('workout_sessions');
    return List.generate(maps.length, (i) => WorkoutSession.fromMap(maps[i]));
  }

  Future<WorkoutSession?> getWorkoutSessionByDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workout_sessions',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isNotEmpty) {
      return WorkoutSession.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateWorkoutSession(WorkoutSession session) async {
    final db = await database;
    return await db.update(
      'workout_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// Deletes all workout sessions from the database.
  Future<void> deleteAllWorkoutSessions() async {
    final db = await database;
    try {
      await db.delete('workout_sessions');
    } catch (e) {
      // Handle error
    }
  }

  // FIT TEST CRUD OPERATIONS
  Future<int> insertFitTest(FitTest fitTest) async {
    final db = await database;
    return await db.insert('fit_test_results', fitTest.toMap());
  }

  Future<List<FitTest>> getAllFitTests() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fit_test_results',
      orderBy: 'test_date ASC',
    );
    return List.generate(maps.length, (i) => FitTest.fromMap(maps[i]));
  }

  Future<int> deleteFitTest(int id) async {
    final db = await database;
    return await db.delete(
      'fit_test_results',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<FitTest?> getLatestFitTest() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fit_test_results',
      orderBy: 'test_date DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return FitTest.fromMap(maps.first);
    }
    return null;
  }

  // UTILITY METHODS
  Future<void> deleteDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}