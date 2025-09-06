import 'package:flutter/foundation.dart';
// Assuming shared_preferences is added to pubspec.yaml
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/database_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  List<Workout> _workouts = [];
  List<WorkoutSession> _sessions = [];
  bool _isLoading = false;
  DateTime? _programStartDate;

  static const int programCycleLengthDays = 63;
  static const int programCycleLengthWeeks = 9;
  static const String _programStartDateKey =
      'programStartDate'; // Key for SharedPreferences

  // Getters
  List<Workout> get workouts => _workouts;
  List<WorkoutSession> get sessions => _sessions;
  bool get isLoading => _isLoading;
  DateTime? get programStartDate => _programStartDate;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners(); // Notify listeners that loading has started

    try {
      // --- START: Load programStartDate from SharedPreferences ---
      final prefs = await SharedPreferences.getInstance();
      final startDateString = prefs.getString(_programStartDateKey);
      if (startDateString != null) {
        _programStartDate = DateTime.tryParse(startDateString);
      }
      // --- END: Load programStartDate ---

      await _loadWorkouts();
      await _loadWorkoutSessions();
    } catch (e) {
      debugPrint('Error initializing WorkoutProvider: $e');
      _programStartDate = null; // Ensure it's null on error during load
    } finally {
      // Ensure isLoading is set to false and listeners are notified in finally
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setProgramStartDate(
    DateTime startDate, {
    bool shouldReloadData = true,
    bool autoPopulatePastWorkouts = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    _programStartDate = startDate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_programStartDateKey, startDate.toIso8601String());

    debugPrint('Program Start Date SET to: $_programStartDate');

    if (autoPopulatePastWorkouts && _programStartDate != null) {
      try {
        await _autoCompletePastWorkouts(_programStartDate!);
        debugPrint('Successfully auto-populated past workouts.');
      } catch (e) {
        debugPrint('Error auto-populating past workouts: $e');
        // Decide how to handle this error - maybe notify the user?
      }
    }
    if (shouldReloadData) {
      // Data like "today's workout" or "current week" depends on the start date.
      // You might not need to fully re-initialize everything, but for simplicity now:
      await _loadWorkouts(); // Ensure workouts are present
      await _loadWorkoutSessions(); // And sessions
    }

    _isLoading = false;
    notifyListeners(); // Notify that start date is set and data might be refreshed
  }

  Future<void> _autoCompletePastWorkouts(DateTime programStartDate) async {
    if (_workouts.isEmpty) {
      await _loadWorkouts(); // Ensure workouts are loaded
      if (_workouts.isEmpty) {
        debugPrint("Cannot auto-complete: Workouts list is empty.");
        return;
      }
    }

    final today = DateTime.now();
    final startDateNormalized = DateTime(
      programStartDate.year,
      programStartDate.month,
      programStartDate.day,
    );
    final todayNormalized = DateTime(today.year, today.month, today.day);

    // Iterate from the program start date up to today
    for (int dayOffset = 0; ; dayOffset++) {
      final currentDateToLog = startDateNormalized.add(
        Duration(days: dayOffset),
      );
      if (currentDateToLog.isAfter(todayNormalized)) {
        break; // Stop if we've passed today
      }

      // Determine the day number in the 63-day cycle for this currentDateToLog
      final daysSinceProgramStartForThisDate = currentDateToLog
          .difference(startDateNormalized)
          .inDays;
      final dayInCycle =
          (daysSinceProgramStartForThisDate % programCycleLengthDays) +
          1; // 1-63

      Workout? scheduledWorkout;
      try {
        scheduledWorkout = _workouts.firstWhere(
          (w) => w.dayNumber == dayInCycle,
        );
      } catch (e) {
        debugPrint(
          "WorkoutProvider: Could not find workout for day $dayInCycle in the schedule for auto-completion.",
        );
        continue; // Skip this day if no workout is defined
      }

      // Skip auto-completing 'rest' days as they don't typically have a "completed" session
      // Or, if you want to log them as 'completed' (which is unusual for rest), remove this check.
      if (scheduledWorkout.workoutType == 'rest') {
        debugPrint(
          "Skipping auto-completion for rest day: ${scheduledWorkout.name} on ${currentDateToLog.toIso8601String().split('T')[0]}",
        );
        continue;
      }

      final dateString = currentDateToLog.toIso8601String().split('T')[0];

      // Check if a session already exists for this date to avoid duplicates or overwriting
      WorkoutSession? existingSession = await _databaseService
          .getWorkoutSessionByDate(dateString);

      if (existingSession == null) {
        WorkoutSession newSession = WorkoutSession(
          workoutId: scheduledWorkout.id,
          date: dateString,
          completed: true, // Mark as completed
          notes: 'Auto-completed', // Optional note
        );
        await _databaseService.insertWorkoutSession(newSession);
        debugPrint('Auto-completed: ${scheduledWorkout.name} on $dateString');
      } else {
        // Optional: If a session exists, you might want to update it to completed if it wasn't.
        // For simplicity now, we only insert if it doesn't exist.
        // if (!existingSession.completed) {
        //   WorkoutSession updatedSession = existingSession.copyWith(completed: true, notes: existingSession.notes ?? 'Auto-completed (updated)');
        //   await _databaseService.updateWorkoutSession(updatedSession);
        //   debugPrint('Updated existing session to completed: ${scheduledWorkout.name} on $dateString');
        // } else {
        debugPrint(
          'Session already exists (or already completed) for ${scheduledWorkout.name} on $dateString. Skipping auto-completion for this day.',
        );
        // }
      }
    }
  }

  // --- Reset Program Start Date (Optional - for testing or if user makes a mistake) ---
  Future<void> clearProgramStartDate() async {
    _isLoading = true;
    notifyListeners();

    _programStartDate = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_programStartDateKey);

    debugPrint('Program Start Date CLEARED');

    // Potentially clear dependent data or just notify
    _isLoading = false;
    notifyListeners();
  }

  // Load all workouts from database
  Future<void> _loadWorkouts() async {
    _workouts = await _databaseService.getAllWorkouts();
    // Ensure workouts are sorted by day_number for reliable cyclical access
    _workouts.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
  }

  // Load all workout sessions from database
  Future<void> _loadWorkoutSessions() async {
    _sessions = await _databaseService.getAllWorkoutSessions();
  }

  // --- START: Revised Logic for Cyclical Schedule ---

  /// Calculates the current day number within the 63-day cycle (1-63).
  /// Returns null if programStartDate is not set.
  int? getCurrentProgramDayInCycle() {
    if (_programStartDate == null) return null;

    final now = DateTime.now();
    // Ensure 'now' is considered at the start of its day for accurate 'inDays'
    final today = DateTime(now.year, now.month, now.day);
    final startDateNormalized = DateTime(
      _programStartDate!.year,
      _programStartDate!.month,
      _programStartDate!.day,
    );

    if (today.isBefore(startDateNormalized)) {
      return null; // Program hasn't started yet relative to 'today'
    }

    final daysSinceProgramStart = today.difference(startDateNormalized).inDays;
    if (daysSinceProgramStart < 0) {
      return 1; // Should not happen if check above is correct
    }

    final currentDayInCycle =
        (daysSinceProgramStart % programCycleLengthDays) + 1;
    return currentDayInCycle;
  }

  /// Calculates the current week number within the 9-week cycle (1-9).
  /// Returns null if programStartDate is not set.
  int? getCurrentProgramWeekInCycle() {
    final currentDayInCycle = getCurrentProgramDayInCycle();
    if (currentDayInCycle == null) return null;
    return ((currentDayInCycle - 1) / 7).floor() + 1;
  }

  /// Calculates the current cycle number (1st cycle, 2nd cycle, etc.).
  /// Returns null if programStartDate is not set.
  int? getCurrentCycleNumber() {
    if (_programStartDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDateNormalized = DateTime(
      _programStartDate!.year,
      _programStartDate!.month,
      _programStartDate!.day,
    );

    if (today.isBefore(startDateNormalized)) return null;

    final daysSinceProgramStart = today.difference(startDateNormalized).inDays;
    if (daysSinceProgramStart < 0) return 1;

    return (daysSinceProgramStart / programCycleLengthDays).floor() + 1;
  }

  /// Gets today's workout based on the cyclical schedule.
  Workout? getTodaysWorkout() {
    if (_workouts.isEmpty) return null;
    final currentDayInCycle = getCurrentProgramDayInCycle();
    if (currentDayInCycle == null) return null;

    try {
      return _workouts.firstWhere((w) => w.dayNumber == currentDayInCycle);
    } catch (e) {
      debugPrint(
        "WorkoutProvider: Could not find workout for day $currentDayInCycle in the schedule.",
      );
      return null; // Should not happen if schedule is complete from 1-63
    }
  }

  /// Gets workouts for a specific week number *within the 9-week cycle*.
  List<Workout> getWeekWorkouts(int weekInCycle) {
    if (weekInCycle < 1 || weekInCycle > programCycleLengthWeeks) return [];
    return _workouts
        .where((workout) => workout.weekNumber == weekInCycle)
        .toList();
  }
  // --- END: Revised Logic for Cyclical Schedule ---

  // Complete a workout (logic largely remains the same, but date context is key)
  Future<void> completeWorkout(
    int workoutId, {
    String? notes,
    DateTime? dateOverride,
  }) async {
    try {
      final dateToLog = dateOverride ?? DateTime.now();
      String dateString = dateToLog.toIso8601String().split('T')[0];

      WorkoutSession? existingSession = await _databaseService
          .getWorkoutSessionByDate(dateString);

      if (existingSession != null) {
        WorkoutSession updatedSession = existingSession.copyWith(
          workoutId:
              workoutId, // Ensure workoutId is also updated if it changed for that day
          completed: true,
          notes: notes,
        );
        await _databaseService.updateWorkoutSession(updatedSession);
      } else {
        WorkoutSession newSession = WorkoutSession(
          workoutId: workoutId,
          date: dateString,
          completed: true,
          notes: notes,
        );
        await _databaseService.insertWorkoutSession(newSession);
      }
      await _loadWorkoutSessions();
      notifyListeners();
    } catch (e) {
      debugPrint('Error completing workout: $e');
    }
  }

  // Skip a workout (logic largely remains the same)
  Future<void> skipWorkout(
    int workoutId, {
    String? reason,
    DateTime? dateOverride,
  }) async {
    try {
      final dateToLog = dateOverride ?? DateTime.now();
      String dateString = dateToLog.toIso8601String().split('T')[0];
      // ... (similar logic to completeWorkout but completed: false) ...
      WorkoutSession? existingSession = await _databaseService
          .getWorkoutSessionByDate(dateString);

      if (existingSession != null) {
        WorkoutSession updatedSession = existingSession.copyWith(
          workoutId: workoutId, // Ensure workoutId is also updated
          completed: false,
          notes: reason,
        );
        await _databaseService.updateWorkoutSession(updatedSession);
      } else {
        WorkoutSession newSession = WorkoutSession(
          workoutId: workoutId,
          date: dateString,
          completed: false,
          notes: reason,
        );
        await _databaseService.insertWorkoutSession(newSession);
      }
      await _loadWorkoutSessions();
      notifyListeners();
    } catch (e) {
      debugPrint('Error skipping workout: $e');
    }
  }

  WorkoutSession? getSessionForDate(String dateString) {
    // Date string YYYY-MM-DD
    try {
      return _sessions.firstWhere((session) => session.date == dateString);
    } catch (e) {
      return null;
    }
  }

  // --- START: Revised Progress Calculation ---
  Map<String, double> getOverallProgress() {
    if (_programStartDate == null || _workouts.isEmpty) {
      return {'currentCycleProgress': 0.0, 'completedCycles': 0.0};
    }

    final int totalWorkoutDaysInOneCycle = _workouts
        .where((w) => w.workoutType == 'workout')
        .length;
    if (totalWorkoutDaysInOneCycle == 0) {
      return {'currentCycleProgress': 0.0, 'completedCycles': 0.0};
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDateNormalized = DateTime(
      _programStartDate!.year,
      _programStartDate!.month,
      _programStartDate!.day,
    );
    final daysSinceProgramStart = today.difference(startDateNormalized).inDays;

    if (daysSinceProgramStart < 0) {
      return {'currentCycleProgress': 0.0, 'completedCycles': 0.0};
    }

    final completedCycles = (daysSinceProgramStart / programCycleLengthDays)
        .floor();

    // Calculate progress for the current cycle
    // Start date of the current cycle
    final currentCycleStartDate = startDateNormalized.add(
      Duration(days: completedCycles * programCycleLengthDays),
    );

    int completedInCurrentCycle = 0;
    for (int i = 0; i < programCycleLengthDays; i++) {
      final dateInCycle = currentCycleStartDate.add(Duration(days: i));
      if (dateInCycle.isAfter(today)) break; // Don't count future days

      final dateString = dateInCycle.toIso8601String().split('T')[0];
      final session = getSessionForDate(dateString);

      if (session != null && session.completed) {
        // Ensure the session corresponds to a 'workout' type for progress calculation
        try {
          final workoutForSessionDay = _workouts.firstWhere(
            (w) => w.id == session.workoutId,
          );
          if (workoutForSessionDay.workoutType == 'workout') {
            completedInCurrentCycle++;
          }
        } catch (e) {
          // Workout not found for session.workoutId, shouldn't happen if data is consistent
        }
      }
    }

    double currentCycleProgress =
        (completedInCurrentCycle / totalWorkoutDaysInOneCycle) * 100;
    currentCycleProgress = currentCycleProgress.isNaN
        ? 0.0
        : currentCycleProgress.clamp(0.0, 100.0);

    return {
      'currentCycleProgress': currentCycleProgress,
      'completedCycles': completedCycles.toDouble(),
    };
  }
  // --- END: Revised Progress Calculation ---

  List<WorkoutSession> getThisWeekSessions() {
    if (_programStartDate == null) return [];

    final currentDayInCycle = getCurrentProgramDayInCycle();
    final currentWeekInCycle = getCurrentProgramWeekInCycle();
    if (currentDayInCycle == null || currentWeekInCycle == null) return [];

    // Calculate the start date of the current week in the current cycle
    final daysFromCycleStartToWeekStart = ((currentWeekInCycle - 1) * 7);

    final currentCycleNumber = getCurrentCycleNumber() ?? 1;
    final overallProgramStartDate = _programStartDate!;

    final absoluteStartDateOfCurrentCycle = overallProgramStartDate.add(
      Duration(days: (currentCycleNumber - 1) * programCycleLengthDays),
    );
    final startDateOfThisActualWeek = absoluteStartDateOfCurrentCycle.add(
      Duration(days: daysFromCycleStartToWeekStart),
    );

    List<WorkoutSession> weekSessions = [];
    for (int i = 0; i < 7; i++) {
      final date = startDateOfThisActualWeek.add(Duration(days: i));
      final session = getSessionForDate(date.toIso8601String().split('T')[0]);
      if (session != null) {
        weekSessions.add(session);
      }
    }
    return weekSessions;
  }

  Future<void> bulkUpsertWorkoutSessions(
    List<WorkoutSession> sessionsToProcess,
  ) async {
    // ... (existing bulkUpsertWorkoutSessions logic - should be fine) ...
    // Make sure it reloads sessions: await _loadWorkoutSessions(); and notifyListeners();
    if (sessionsToProcess.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      for (final session in sessionsToProcess) {
        WorkoutSession? existingSession = await _databaseService
            .getWorkoutSessionByDate(session.date);
        if (existingSession != null) {
          WorkoutSession sessionToUpdate = session.copyWith(
            id: existingSession.id,
          );
          await _databaseService.updateWorkoutSession(sessionToUpdate);
        } else {
          await _databaseService.insertWorkoutSession(session);
        }
      }
      await _loadWorkoutSessions();
    } catch (e) {
      debugPrint('Error in bulkUpsertWorkoutSessions: $e');
      throw Exception('Failed to process workout sessions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, int> getCurrentCycleSessionStats() {
    if (_programStartDate == null || _workouts.isEmpty) {
      return {'completed': 0, 'skipped': 0, 'remaining': 0, 'totalInCycle': 0};
    }

    final int totalWorkoutDaysInOneCycle = _workouts
        .where(
          (w) => w.workoutType == 'workout',
        ) // Count only actual 'workout' days for this stat
        .length;

    if (totalWorkoutDaysInOneCycle == 0) {
      return {
        'completed': 0,
        'skipped': 0,
        'remaining': totalWorkoutDaysInOneCycle,
        'totalInCycle': totalWorkoutDaysInOneCycle,
      };
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDateNormalized = DateTime(
      _programStartDate!.year,
      _programStartDate!.month,
      _programStartDate!.day,
    );

    if (today.isBefore(startDateNormalized)) {
      // Program hasn't started, or it's before the first day of the current view
      return {
        'completed': 0,
        'skipped': 0,
        'remaining': totalWorkoutDaysInOneCycle,
        'totalInCycle': totalWorkoutDaysInOneCycle,
      };
    }

    final daysSinceProgramStart = today.difference(startDateNormalized).inDays;
    final completedCycles = (daysSinceProgramStart / programCycleLengthDays)
        .floor();
    final currentCycleStartDate = startDateNormalized.add(
      Duration(days: completedCycles * programCycleLengthDays),
    );

    int completedInCurrentCycle = 0;
    int skippedInCurrentCycle = 0;

    for (int i = 0; i < programCycleLengthDays; i++) {
      final dateInCycle = currentCycleStartDate.add(Duration(days: i));
      final dateString = dateInCycle.toIso8601String().split('T')[0];

      // Find the scheduled workout for this day in the cycle
      // The dayNumber for workouts is 1-based.
      final dayInCycleForWorkoutLookup = (i % programCycleLengthDays) + 1;
      Workout? scheduledWorkout;
      try {
        scheduledWorkout = _workouts.firstWhere(
          (w) => w.dayNumber == dayInCycleForWorkoutLookup,
        );
      } catch (e) {
        // Should not happen if workouts list covers all days 1-63
        continue;
      }

      // We only care about 'workout' types for this specific chart's completed/skipped/remaining.
      // Fit tests and rest days are handled separately or implied.
      if (scheduledWorkout.workoutType != 'workout') {
        continue;
      }

      // Count as a day that has passed or is today within the actual workout days
      if (dateInCycle.isBefore(today) || dateInCycle.isAtSameMomentAs(today)) {
        final session = getSessionForDate(
          dateString,
        ); // getSessionForDate should be efficient

        if (session != null) {
          if (session.completed && session.workoutId == scheduledWorkout.id) {
            // Ensure session matches the scheduled workout
            completedInCurrentCycle++;
          } else if (!session.completed &&
              session.workoutId == scheduledWorkout.id) {
            skippedInCurrentCycle++;
          }
          // If session.workoutId doesn't match scheduledWorkout.id, it implies user logged a different workout
          // on this day. How to count that depends on exact requirements. For now, we assume direct match.
        } else {
          // No session logged for a past/today 'workout' day in the current cycle
          // This could be implicitly "skipped" or "pending if today"
          // For simplicity, if it's passed and no session, we can count it as effectively skipped for chart purposes
          if (dateInCycle.isBefore(today)) {
            skippedInCurrentCycle++; // Or however you want to define "skipped" for days with no log
          }
        }
      }
    }

    // Remaining is total 'workout' days in cycle minus those completed or skipped up to today.
    // This definition of remaining means "remaining workout days in the cycle that are either upcoming or today and not yet done"
    int remainingInCurrentCycle =
        totalWorkoutDaysInOneCycle -
        completedInCurrentCycle -
        skippedInCurrentCycle;
    // Ensure remaining is not negative, which could happen if skipped logic is complex
    remainingInCurrentCycle = remainingInCurrentCycle < 0
        ? 0
        : remainingInCurrentCycle;

    return {
      'completed': completedInCurrentCycle,
      'skipped': skippedInCurrentCycle,
      'remaining':
          remainingInCurrentCycle, // Total 'workout' days minus (completed + skipped for past/today)
      'totalInCycle':
          totalWorkoutDaysInOneCycle, // Total 'workout' type days in a cycle definition
    };
  }
}
