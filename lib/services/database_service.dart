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
    // Sample workout data - we'll expand this later
    List<Map<String, dynamic>> workouts = [
      // Week 1
      {'id': 1, 'name': 'Fit Test', 'day_number': 1, 'week_number': 1, 'workout_type': 'fit_test'},
      {'id': 2, 'name': 'Plyometric Cardio Circuit', 'day_number': 2, 'week_number': 1, 'workout_type': 'workout'},
      {'id': 3, 'name': 'Cardio Power & Resistance', 'day_number': 3, 'week_number': 1, 'workout_type': 'workout'},
      {'id': 4, 'name': 'Cardio Recovery', 'day_number': 4, 'week_number': 1, 'workout_type': 'workout'},
      {'id': 5, 'name': 'Pure Cardio', 'day_number': 5, 'week_number': 1, 'workout_type': 'workout'},
      {'id': 6, 'name': 'Plyometric Cardio Circuit', 'day_number': 6, 'week_number': 1, 'workout_type': 'workout'},
      {'id': 7, 'name': 'Rest Day', 'day_number': 7, 'week_number': 1, 'workout_type': 'rest'},
      // We'll add the full 60-day schedule later
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