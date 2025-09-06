import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/fit_test.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'insanity_tracker.db';
  static const int _databaseVersion = 1;

  // Singleton pattern - only one instance of DatabaseService
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  // Get database instance
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  // Create tables
  Future _onCreate(Database db, int version) async {
    // Workouts table (static data)
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        day_number INTEGER NOT NULL,
        week_number INTEGER NOT NULL,
        workout_type TEXT NOT NULL CHECK(workout_type IN ('workout', 'fit_test', 'rest'))
      )
    ''');

    // Workout sessions table (user data)
    await db.execute('''
      CREATE TABLE workout_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (workout_id) REFERENCES workouts (id)
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

    // Populate with Insanity workout schedule
    await _populateWorkouts(db);
  }

  // Populate the workouts table with Insanity schedule
  Future _populateWorkouts(Database db) async {
    // Complete Insanity 60-day workout schedule
    List<Map<String, dynamic>> workouts = [
      // Week 1
      {'id': 1, 'name': 'Fit Test', 'day_number': 1, 'week_number': 1, 'workout_type': 'fit_test'},
      {'id': 2, 'name': 'Plyometric Cardio Circuit', 'day_number': 2, 'week_number': 1, 'workout_type': 'workout'},
      {'id': 3, 'name': 'Cardio Power & Resistance', 'day_number': 3, 'week_number': 1, 'workout_type': 'workout'},
      {'id': 4, 'name': 'Cardio Recovery', 'day_number': 4, 'week_number': 1, 'workout_type': 'workout'},
      {'id': 5, 'name': 'Pure Cardio', 'day_number': 5, 'week_number': 1, 'workout_type': 'workout'},
      {'id': 6, 'name': 'Plyometric Cardio Circuit', 'day_number': 6, 'week_number': 1, 'workout_type': 'workout'},
      {'id': 7, 'name': 'Rest Day', 'day_number': 7, 'week_number': 1, 'workout_type': 'rest'},

      // Week 2
      {'id': 8, 'name': 'Cardio Power & Resistance', 'day_number': 8, 'week_number': 2, 'workout_type': 'workout'},
      {'id': 9, 'name': 'Plyometric Cardio Circuit', 'day_number': 9, 'week_number': 2, 'workout_type': 'workout'},
      {'id': 10, 'name': 'Cardio Recovery', 'day_number': 10, 'week_number': 2, 'workout_type': 'workout'},
      {'id': 11, 'name': 'Pure Cardio', 'day_number': 11, 'week_number': 2, 'workout_type': 'workout'},
      {'id': 12, 'name': 'Cardio Power & Resistance', 'day_number': 12, 'week_number': 2, 'workout_type': 'workout'},
      {'id': 13, 'name': 'Pure Cardio', 'day_number': 13, 'week_number': 2, 'workout_type': 'workout'},
      {'id': 14, 'name': 'Rest Day', 'day_number': 14, 'week_number': 2, 'workout_type': 'rest'},

      // Week 3
      {'id': 15, 'name': 'Plyometric Cardio Circuit', 'day_number': 15, 'week_number': 3, 'workout_type': 'workout'},
      {'id': 16, 'name': 'Cardio Power & Resistance', 'day_number': 16, 'week_number': 3, 'workout_type': 'workout'},
      {'id': 17, 'name': 'Cardio Recovery', 'day_number': 17, 'week_number': 3, 'workout_type': 'workout'},
      {'id': 18, 'name': 'Pure Cardio', 'day_number': 18, 'week_number': 3, 'workout_type': 'workout'},
      {'id': 19, 'name': 'Plyometric Cardio Circuit', 'day_number': 19, 'week_number': 3, 'workout_type': 'workout'},
      {'id': 20, 'name': 'Cardio Power & Resistance', 'day_number': 20, 'week_number': 3, 'workout_type': 'workout'},
      {'id': 21, 'name': 'Rest Day', 'day_number': 21, 'week_number': 3, 'workout_type': 'rest'},

      // Week 4
      {'id': 22, 'name': 'Pure Cardio', 'day_number': 22, 'week_number': 4, 'workout_type': 'workout'},
      {'id': 23, 'name': 'Plyometric Cardio Circuit', 'day_number': 23, 'week_number': 4, 'workout_type': 'workout'},
      {'id': 24, 'name': 'Cardio Recovery', 'day_number': 24, 'week_number': 4, 'workout_type': 'workout'},
      {'id': 25, 'name': 'Cardio Power & Resistance', 'day_number': 25, 'week_number': 4, 'workout_type': 'workout'},
      {'id': 26, 'name': 'Pure Cardio', 'day_number': 26, 'week_number': 4, 'workout_type': 'workout'},
      {'id': 27, 'name': 'Plyometric Cardio Circuit', 'day_number': 27, 'week_number': 4, 'workout_type': 'workout'},
      {'id': 28, 'name': 'Rest Day', 'day_number': 28, 'week_number': 4, 'workout_type': 'rest'},

      // Week 5 - Recovery Week
      {'id': 29, 'name': 'Core Cardio & Balance', 'day_number': 29, 'week_number': 5, 'workout_type': 'workout'},
      {'id': 30, 'name': 'Core Cardio & Balance', 'day_number': 30, 'week_number': 5, 'workout_type': 'fit_test'},
      {'id': 31, 'name': 'Core Cardio & Balance', 'day_number': 31, 'week_number': 5, 'workout_type': 'workout'},
      {'id': 32, 'name': 'Core Cardio & Balance', 'day_number': 32, 'week_number': 5, 'workout_type': 'workout'},
      {'id': 33, 'name': 'Core Cardio & Balance', 'day_number': 33, 'week_number': 5, 'workout_type': 'workout'},
      {'id': 34, 'name': 'Core Cardio & Balance', 'day_number': 34, 'week_number': 5, 'workout_type': 'workout'},
      {'id': 35, 'name': 'Rest Day', 'day_number': 35, 'week_number': 5, 'workout_type': 'rest'},

      // Week 6 - Month 2 begins
      {'id': 36, 'name': 'Max Interval Circuit', 'day_number': 36, 'week_number': 6, 'workout_type': 'workout'},
      {'id': 37, 'name': 'Max Interval Plyo', 'day_number': 37, 'week_number': 6, 'workout_type': 'workout'},
      {'id': 38, 'name': 'Max Cardio Conditioning', 'day_number': 38, 'week_number': 6, 'workout_type': 'workout'},
      {'id': 39, 'name': 'Max Recovery', 'day_number': 39, 'week_number': 6, 'workout_type': 'workout'},
      {'id': 40, 'name': 'Max Interval Circuit', 'day_number': 40, 'week_number': 6, 'workout_type': 'workout'},
      {'id': 41, 'name': 'Max Interval Plyo', 'day_number': 41, 'week_number': 6, 'workout_type': 'workout'},
      {'id': 42, 'name': 'Rest Day', 'day_number': 42, 'week_number': 6, 'workout_type': 'rest'},

      // Week 7
      {'id': 43, 'name': 'Max Cardio Conditioning', 'day_number': 43, 'week_number': 7, 'workout_type': 'workout'},
      {'id': 44, 'name': 'Insane Abs', 'day_number': 44, 'week_number': 7, 'workout_type': 'workout'},
      {'id': 45, 'name': 'Max Recovery', 'day_number': 45, 'week_number': 7, 'workout_type': 'workout'},
      {'id': 46, 'name': 'Max Interval Circuit', 'day_number': 46, 'week_number': 7, 'workout_type': 'workout'},
      {'id': 47, 'name': 'Max Cardio Conditioning', 'day_number': 47, 'week_number': 7, 'workout_type': 'workout'},
      {'id': 48, 'name': 'Insane Abs', 'day_number': 48, 'week_number': 7, 'workout_type': 'workout'},
      {'id': 49, 'name': 'Rest Day', 'day_number': 49, 'week_number': 7, 'workout_type': 'rest'},

      // Week 8
      {'id': 50, 'name': 'Max Interval Plyo', 'day_number': 50, 'week_number': 8, 'workout_type': 'workout'},
      {'id': 51, 'name': 'Max Cardio Conditioning', 'day_number': 51, 'week_number': 8, 'workout_type': 'workout'},
      {'id': 52, 'name': 'Max Recovery', 'day_number': 52, 'week_number': 8, 'workout_type': 'workout'},
      {'id': 53, 'name': 'Max Interval Circuit', 'day_number': 53, 'week_number': 8, 'workout_type': 'workout'},
      {'id': 54, 'name': 'Max Interval Plyo', 'day_number': 54, 'week_number': 8, 'workout_type': 'workout'},
      {'id': 55, 'name': 'Insane Abs', 'day_number': 55, 'week_number': 8, 'workout_type': 'workout'},
      {'id': 56, 'name': 'Rest Day', 'day_number': 56, 'week_number': 8, 'workout_type': 'rest'},

      // Week 9 - Final Week
      {'id': 57, 'name': 'Max Cardio Conditioning', 'day_number': 57, 'week_number': 9, 'workout_type': 'workout'},
      {'id': 58, 'name': 'Max Recovery', 'day_number': 58, 'week_number': 9, 'workout_type': 'workout'},
      {'id': 59, 'name': 'Insane Abs', 'day_number': 59, 'week_number': 9, 'workout_type': 'workout'},
      {'id': 60, 'name': 'Final Fit Test', 'day_number': 60, 'week_number': 9, 'workout_type': 'fit_test'},
    ];

    for (var workout in workouts) {
      await db.insert('workouts', workout);
    }
  }

  // WORKOUT CRUD OPERATIONS
  Future<List<Workout>> getAllWorkouts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('workouts');
    return List.generate(maps.length, (i) => Workout.fromMap(maps[i]));
  }

  Future<Workout?> getWorkout(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workouts',
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
    final db = await database;
    db.close();
  }
}