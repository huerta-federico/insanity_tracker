import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/database_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  List<Workout> _workouts = [];
  List<WorkoutSession> _sessions = [];
  bool _isLoading = false;

  // Getters
  List<Workout> get workouts => _workouts;
  List<WorkoutSession> get sessions => _sessions;
  bool get isLoading => _isLoading;

  // Initialize - load all data
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadWorkouts();
      await _loadWorkoutSessions();
    } catch (e) {
      debugPrint('Error initializing WorkoutProvider: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load all workouts from database
  Future<void> _loadWorkouts() async {
    _workouts = await _databaseService.getAllWorkouts();
  }

  // Load all workout sessions from database
  Future<void> _loadWorkoutSessions() async {
    _sessions = await _databaseService.getAllWorkoutSessions();
  }

  // Get today's workout based on program start date
  Workout? getTodaysWorkout() {
    // For now, let's just return the first workout
    // We'll implement proper date calculation later
    if (_workouts.isNotEmpty) {
      return _workouts.first;
    }
    return null;
  }

  // Get workouts for a specific week
  List<Workout> getWeekWorkouts(int week) {
    return _workouts.where((workout) => workout.weekNumber == week).toList();
  }

  // Complete a workout
  Future<void> completeWorkout(int workoutId, {String? notes}) async {
    try {
      String today = DateTime.now().toIso8601String().split(
        'T',
      )[0]; // YYYY-MM-DD format

      // Check if session already exists for today
      WorkoutSession? existingSession = await _databaseService
          .getWorkoutSessionByDate(today);

      if (existingSession != null) {
        // Update existing session
        WorkoutSession updatedSession = existingSession.copyWith(
          completed: true,
          notes: notes,
        );
        await _databaseService.updateWorkoutSession(updatedSession);
      } else {
        // Create new session
        WorkoutSession newSession = WorkoutSession(
          workoutId: workoutId,
          date: today,
          completed: true,
          notes: notes,
        );
        await _databaseService.insertWorkoutSession(newSession);
      }

      // Reload sessions
      await _loadWorkoutSessions();
      notifyListeners();
    } catch (e) {
      debugPrint('Error completing workout: $e');
    }
  }

  // Skip a workout
  Future<void> skipWorkout(int workoutId, {String? reason}) async {
    try {
      String today = DateTime.now().toIso8601String().split('T')[0];

      WorkoutSession? existingSession = await _databaseService
          .getWorkoutSessionByDate(today);

      if (existingSession != null) {
        // Update existing session
        WorkoutSession updatedSession = existingSession.copyWith(
          completed: false,
          notes: reason,
        );
        await _databaseService.updateWorkoutSession(updatedSession);
      } else {
        // Create new session marked as skipped
        WorkoutSession newSession = WorkoutSession(
          workoutId: workoutId,
          date: today,
          completed: false,
          notes: reason,
        );
        await _databaseService.insertWorkoutSession(newSession);
      }

      // Reload sessions
      await _loadWorkoutSessions();
      notifyListeners();
    } catch (e) {
      debugPrint('Error skipping workout: $e');
    }
  }

  // Get completion status for a specific date
  WorkoutSession? getSessionForDate(String date) {
    try {
      return _sessions.firstWhere((session) => session.date == date);
    } catch (e) {
      return null; // No session found for this date
    }
  }

  // Get overall completion percentage
  double getOverallProgress() {
    if (_workouts.isEmpty) return 0.0;

    int completedWorkouts = _sessions
        .where((session) => session.completed)
        .length;
    int totalWorkouts = _workouts
        .where((workout) => workout.workoutType == 'workout')
        .length;

    if (totalWorkouts == 0) return 0.0;
    return (completedWorkouts / totalWorkouts) * 100;
  }

  // Get this week's completion
  List<WorkoutSession> getThisWeekSessions() {
    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));

    return _sessions.where((session) {
      DateTime sessionDate = DateTime.parse(session.date);
      return sessionDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          sessionDate.isBefore(weekStart.add(const Duration(days: 7)));
    }).toList();
  }

  // Inside class WorkoutProvider extends ChangeNotifier

  // ... existing methods ...

  // --- START: New method ---
  Future<void> bulkUpsertWorkoutSessions(List<WorkoutSession> sessions) async {
    if (sessions.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      for (final session in sessions) {
        // Check if a session for this date already exists
        WorkoutSession? existingSession = await _databaseService
            .getWorkoutSessionByDate(session.date);

        if (existingSession != null) {
          // Update existing session
          // Important: Preserve the existing ID
          WorkoutSession sessionToUpdate = session.copyWith(
            id: existingSession.id,
          );
          await _databaseService.updateWorkoutSession(sessionToUpdate);
        } else {
          // Insert new session
          await _databaseService.insertWorkoutSession(session);
        }
      }
      await _loadWorkoutSessions(); // Reload all sessions to reflect changes
    } catch (e) {
      debugPrint('Error in bulkUpsertWorkoutSessions: $e');
      // Rethrow to allow UI to catch and display specific error
      throw Exception('Failed to process workout sessions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- END: New method ---
}
