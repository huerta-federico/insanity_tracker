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
    try {
      debugPrint(
        'Clearing existing workout sessions before setting new start date...',
      );
      await _databaseService.deleteAllWorkoutSessions();
      // Ensure the in-memory list is also cleared immediately
      _sessions = [];
      debugPrint('Existing workout sessions cleared.');
    } catch (e) {
      debugPrint('Error clearing existing workout sessions: $e');
      // Decide if you want to proceed if deletion fails. For robustness,
      // it might be better to stop or ensure _sessions is empty.
      _sessions = []; // Ensure it's empty even on error
    }
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
      await _loadWorkouts();
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

    for (int dayOffset = 0; ; dayOffset++) {
      final currentDateToLog = startDateNormalized.add(
        Duration(days: dayOffset),
      );
      // Stop if we've reached or passed today (auto-complete only for past days)
      if (!currentDateToLog.isBefore(todayNormalized)) {
        break;
      }

      final daysSinceProgramStartForThisDate = currentDateToLog
          .difference(startDateNormalized)
          .inDays;
      final dayInCycle =
          (daysSinceProgramStartForThisDate % programCycleLengthDays) + 1;

      Workout? scheduledWorkout;
      try {
        scheduledWorkout = _workouts.firstWhere(
          (w) => w.dayNumber == dayInCycle,
        );
      } catch (e) {
        debugPrint(
          "WorkoutProvider: Could not find workout for day $dayInCycle in the schedule for auto-completion.",
        );
        continue;
      }

      /// Attempts to determine the program start date from the earliest session
      /// in the database and sets it. This is useful after an import.
      /// Returns true if a start date was found and set, false otherwise.

      // --- MODIFIED ---
      // Skip auto-completing 'rest' days. 'workout' and 'fit_test' should be auto-completed.
      if (scheduledWorkout.workoutType == 'rest') {
        debugPrint(
          "Skipping auto-completion for rest day: ${scheduledWorkout.name} on ${currentDateToLog.toIso8601String().split('T')[0]}",
        );
        continue;
      }

      final dateString = currentDateToLog.toIso8601String().split('T')[0];
      WorkoutSession? existingSession = await _databaseService
          .getWorkoutSessionByDate(dateString);

      if (existingSession == null) {
        WorkoutSession newSession = WorkoutSession(
          workoutId: scheduledWorkout.id,
          date: dateString,
          completed: true,
          notes: 'Auto-completed',
        );
        await _databaseService.insertWorkoutSession(newSession);
        debugPrint(
          'Auto-completed (${scheduledWorkout.workoutType}): ${scheduledWorkout.name} on $dateString',
        );
      } else {
        debugPrint(
          'Session already exists for ${scheduledWorkout.name} on $dateString. Skipping auto-completion for this day.',
        );
      }
    }
  }

  // In WorkoutProvider

  Future<bool> reconcileStartDateFromImportedData() async {
    if (_sessions.isEmpty) {
      debugPrint("WorkoutProvider: No sessions found to infer start date after import.");
      return false;
    }

    _sessions.sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));
    final String earliestSessionDateString = _sessions.first.date;
    DateTime earliestSessionDate = DateTime.parse(earliestSessionDateString);

    DateTime potentialStartDate = earliestSessionDate;
    while (potentialStartDate.weekday != DateTime.monday) {
      potentialStartDate = potentialStartDate.subtract(const Duration(days: 1));
    }

    // Check if the determined start date is actually different from the current one
    if (_programStartDate == null ||
        _programStartDate!.year != potentialStartDate.year ||
        _programStartDate!.month != potentialStartDate.month ||
        _programStartDate!.day != potentialStartDate.day) {

      debugPrint("WorkoutProvider: Reconciling start date. Found earliest session on $earliestSessionDateString. Updating start date to $potentialStartDate");

      _isLoading = true; // Signal loading state
      // Manually update the start date and save to SharedPreferences
      _programStartDate = potentialStartDate;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_programStartDateKey, _programStartDate!.toIso8601String());

      // _sessions are already loaded with imported data.
      // _workouts should also be loaded from the initial initialize() call.
      // We just need to ensure everything is consistent and notify.
      // No need to clear sessions or auto-populate here.

      // If _loadWorkouts() is quick and safe to call again, do it. Otherwise, assume it's done.
      // await _loadWorkouts();

      _isLoading = false;
      notifyListeners(); // This is key to update the UI with the new start date AND existing sessions
      return true;
    } else {
      debugPrint("WorkoutProvider: Start date already matches inferred date from imported data. No changes made.");
      // Even if the date is the same, if initialize() was called before, a notifyListeners() might be good.
      // However, the initial initialize() would have already notified.
      return true; // Date was already correct
    }
  }


  // --- Reset Program Start Date (Optional - for testing or if user makes a mistake) ---
  Future<void> clearProgramStartDate() async {
    _isLoading = true;
    notifyListeners();

    _programStartDate = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_programStartDateKey);

    try {
      // Delete all existing workout sessions from the database
      await _databaseService.deleteAllWorkoutSessions();
      // Reload sessions (which will now be empty)
      await _loadWorkoutSessions(); // This will update _sessions to an empty list
      debugPrint(
        'Program Start Date CLEARED and all workout sessions deleted.',
      );
    } catch (e) {
      debugPrint('Error clearing program start date and deleting sessions: $e');
      // Handle error, maybe set _sessions to empty anyway
      _sessions = [];
    }

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

  // Reset a workout
  Future<void> resetWorkout(
    int workoutId, {
    String? reason,
    DateTime? dateOverride,
  }) async {
    try {
      final dateToLog = dateOverride ?? DateTime.now();
      String dateString = dateToLog.toIso8601String().split('T')[0];
      WorkoutSession? existingSession = await _databaseService
          .getWorkoutSessionByDate(dateString);

      if (existingSession != null) {
        WorkoutSession updatedSession = existingSession.copyWith(
          workoutId: workoutId, // Ensure workoutId is also updated
          completed: false,
          notes: '',
        );
        await _databaseService.updateWorkoutSession(updatedSession);
      } else {
        WorkoutSession newSession = WorkoutSession(
          workoutId: workoutId,
          date: dateString,
          completed: false,
          notes: '',
        );
        await _databaseService.insertWorkoutSession(newSession);
      }
      await _loadWorkoutSessions();
      notifyListeners();
    } catch (e) {
      debugPrint('Error resetting workout: $e');
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

    final int totalProgressCountableWorkoutDaysInOneCycle = _workouts
        .where((w) => w.workoutType == 'workout' || w.workoutType == 'fit_test')
        .length;

    if (totalProgressCountableWorkoutDaysInOneCycle == 0) {
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
          if (workoutForSessionDay.workoutType == 'workout' ||
              workoutForSessionDay.workoutType == 'fit_test') {
            completedInCurrentCycle++;
          }
        } catch (e) {
          // Workout not found for session.workoutId, shouldn't happen if data is consistent
        }
      }
    }

    double currentCycleProgress =
        (completedInCurrentCycle /
            totalProgressCountableWorkoutDaysInOneCycle) *
        100;
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
    if (_programStartDate == null || workouts.isEmpty) {
      return {'completed': 0, 'skipped': 0, 'remaining': 0, 'totalInCycle': 0};
    }

    final DateTime today = DateTime.now();
    final DateTime todayNormalized = DateTime(
      today.year,
      today.month,
      today.day,
    );
    final DateTime startDateNormalized = DateTime(
      _programStartDate!.year,
      _programStartDate!.month,
      _programStartDate!.day,
    );

    if (todayNormalized.isBefore(startDateNormalized)) {
      // Program hasn't started yet
      final int totalCountableDays = workouts
          .where(
            (w) => w.workoutType == 'workout' || w.workoutType == 'fit_test',
          )
          .length;
      return {
        'completed': 0,
        'skipped': 0,
        'remaining': totalCountableDays,
        'totalInCycle': totalCountableDays,
      };
    }

    final int daysSinceProgramStart = todayNormalized
        .difference(startDateNormalized)
        .inDays;
    final int currentCycleNumber =
        (daysSinceProgramStart / programCycleLengthDays).floor();
    final DateTime currentCycleStartDate = startDateNormalized.add(
      Duration(days: currentCycleNumber * programCycleLengthDays),
    );

    // --- MODIFIED ---
    // Calculate total 'workout' and 'fit_test' days in the entire cycle definition
    final int totalCountableDaysInCycleDefinition = workouts
        .where((w) => w.workoutType == 'workout' || w.workoutType == 'fit_test')
        .length;

    int completedThisCycle = 0;
    int skippedThisCycle =
        0; // Assuming 'skipped' still primarily applies to these types

    for (int dayOffset = 0; dayOffset < programCycleLengthDays; dayOffset++) {
      final DateTime dateInCycle = currentCycleStartDate.add(
        Duration(days: dayOffset),
      );
      if (dateInCycle.isAfter(todayNormalized)) {
        break; // Stop if we've passed today
      }

      final String dateString = dateInCycle.toIso8601String().split('T')[0];
      final WorkoutSession? session = getSessionForDate(dateString);
      final Workout? scheduledWorkout = getWorkoutForDate(dateInCycle);

      if (scheduledWorkout != null &&
          (scheduledWorkout.workoutType == 'workout' ||
              scheduledWorkout.workoutType == 'fit_test')) {
        if (session != null) {
          if (session.completed) {
            completedThisCycle++;
          } else {
            // If a session exists but not completed, consider it skipped for these types
            skippedThisCycle++;
          }
        } else {
          // No session exists for a past 'workout' or 'fit_test' day, consider it skipped
          skippedThisCycle++;
        }
      }
    }

    // 'remaining' is total countable days in cycle definition minus those completed or skipped UP TO TODAY
    // More accurately: total countable in definition minus what's been accounted for (completed/skipped) from days passed.
    // Or, total in definition minus completed, and ensure skipped doesn't make remaining negative.
    int remainingInCycle =
        totalCountableDaysInCycleDefinition - completedThisCycle;

    return {
      'completed': completedThisCycle,
      'skipped': skippedThisCycle,
      'remaining': remainingInCycle < 0
          ? 0
          : remainingInCycle, // Ensure not negative
      'totalInCycle': totalCountableDaysInCycleDefinition,
    };
  }

  Workout? getWorkoutForDate(DateTime date) {
    if (_programStartDate == null || _workouts.isEmpty) return null;

    final dateNormalized = DateTime(date.year, date.month, date.day);
    final startDateNormalized = DateTime(
      _programStartDate!.year,
      _programStartDate!.month,
      _programStartDate!.day,
    );

    if (dateNormalized.isBefore(startDateNormalized)) {
      // Date is before the program started
      return null;
    }

    final daysSinceProgramStart = dateNormalized
        .difference(startDateNormalized)
        .inDays;
    final dayInCycle = (daysSinceProgramStart % programCycleLengthDays) + 1;

    try {
      return _workouts.firstWhere((w) => w.dayNumber == dayInCycle);
    } catch (e) {
      debugPrint(
        "WorkoutProvider: Could not find workout for day $dayInCycle (date: $date) in the schedule.",
      );
      return null;
    }
  }
}
