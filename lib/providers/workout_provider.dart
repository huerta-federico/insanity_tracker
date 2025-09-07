import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/database_service.dart';

/// Provider that manages workout program state and progress tracking.
///
/// This provider handles workout data, session tracking, program progress,
/// and provides cached computations for performance optimization.
class WorkoutProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  // Core data
  List<Workout> _workouts = [];
  List<WorkoutSession> _sessions = [];
  bool _isLoading = false;
  DateTime? _programStartDate;
  String? _lastError;

  // Cache for expensive computations
  Map<String, dynamic>? _cachedProgress;
  Map<String, int>? _cachedCycleStats;
  List<WorkoutSession>? _cachedThisWeekSessions;
  int? _cachedCurrentDayInCycle;
  int? _cachedCurrentWeekInCycle;
  int? _cachedCurrentCycleNumber;

  // Cache invalidation tracking
  DateTime? _lastCacheUpdate;
  String? _lastSessionsHash;
  bool _cacheInvalidated = false;

  // Constants
  static const int programCycleLengthDays = 63;
  static const int programCycleLengthWeeks = 9;
  static const String _programStartDateKey = 'programStartDate';
  static const int _cacheValidityMinutes = 5;

  // Getters
  List<Workout> get workouts => List.unmodifiable(_workouts);
  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoading => _isLoading;
  DateTime? get programStartDate => _programStartDate;
  String? get lastError => _lastError;

  @override
  void dispose() {
    _clearCaches();
    super.dispose();
  }

  /// Initializes the provider by loading all necessary data.
  /// Should be called once when the app starts.
  Future<void> initialize() async {
    //debugPrint("WorkoutProvider: INITIALIZE START");
    if (_isLoading) {
      //debugPrint("WorkoutProvider: Already loading, skipping initialization.");
      return;
    }

    await _performOperation(() async {
      await Future.wait([_loadProgramStartDate(), _loadWorkouts()]);
      await _loadWorkoutSessions();
      _refreshCaches();
    });

    //debugPrint("WorkoutProvider: INITIALIZE COMPLETE");
  }

  /// Sets the program start date and optionally populates past workouts.
  Future<void> setProgramStartDate(
    DateTime startDate, {
    bool shouldReloadData = true,
    bool autoPopulatePastWorkouts = true,
  }) async {
    await _performOperation(() async {
      // Clear existing sessions
      await _clearExistingSessions();

      // Set new start date
      await _updateProgramStartDate(startDate);

      if (autoPopulatePastWorkouts) {
        await _autoCompletePastWorkouts(startDate);
      }

      if (shouldReloadData) {
        await _reloadData();
      }

      _refreshCaches();
    });
  }

  /// Clears the program start date and all associated data.
  Future<void> clearProgramStartDate() async {
    await _performOperation(() async {
      _programStartDate = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_programStartDateKey);

      await _databaseService.deleteAllWorkoutSessions();
      _sessions = [];
      _refreshCaches();
    });
  }

  /// Reconciles start date from imported workout session data.
  Future<bool> reconcileStartDateFromImportedData() async {
    if (_sessions.isEmpty) {
      /*
      debugPrint(
        "WorkoutProvider: No sessions found to infer start date after import.",
      );
      */
      return false;
    }

    final sortedSessions = List<WorkoutSession>.from(
      _sessions,
    )..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

    final earliestDate = DateTime.parse(sortedSessions.first.date);
    final potentialStartDate = _findMondayBefore(earliestDate);

    if (_isDateDifferent(_programStartDate, potentialStartDate)) {
      await _performOperation(() async {
        await _updateProgramStartDate(potentialStartDate);
        _refreshCaches();
      });
      return true;
    }

    return true;
  }

  // Workout session management

  /// Marks a workout as completed.
  Future<void> completeWorkout(
    int workoutId, {
    String? notes,
    DateTime? dateOverride,
  }) async {
    await _updateWorkoutSession(
      workoutId: workoutId,
      completed: true,
      notes: notes,
      dateOverride: dateOverride,
    );
  }

  /// Marks a workout as skipped.
  Future<void> skipWorkout(
    int workoutId, {
    String? reason,
    DateTime? dateOverride,
  }) async {
    await _updateWorkoutSession(
      workoutId: workoutId,
      completed: false,
      notes: reason,
      dateOverride: dateOverride,
    );
  }

  /// Resets a workout session.
  Future<void> resetWorkout(
    int workoutId, {
    String? reason,
    DateTime? dateOverride,
  }) async {
    await _updateWorkoutSession(
      workoutId: workoutId,
      completed: false,
      notes: '',
      dateOverride: dateOverride,
    );
  }

  /// Bulk upsert multiple workout sessions.
  Future<void> bulkUpsertWorkoutSessions(
    List<WorkoutSession> sessionsToProcess,
  ) async {
    if (sessionsToProcess.isEmpty) return;

    await _performOperation(() async {
      // Process in batches for better performance
      const batchSize = 20;
      for (int i = 0; i < sessionsToProcess.length; i += batchSize) {
        final batch = sessionsToProcess.skip(i).take(batchSize);
        await _processSessions(batch.toList());
      }

      await _loadWorkoutSessions();
      _refreshCaches();
    });
  }

  // Data retrieval methods with caching

  /// Gets the current program day within the cycle (1-63).
  int? getCurrentProgramDayInCycle() {
    if (_shouldUseCachedValue(_cachedCurrentDayInCycle)) {
      return _cachedCurrentDayInCycle;
    }

    _cachedCurrentDayInCycle = _calculateCurrentProgramDayInCycle();
    _updateCacheTimestamp();
    return _cachedCurrentDayInCycle;
  }

  /// Gets the current program week within the cycle (1-9).
  int? getCurrentProgramWeekInCycle() {
    if (_shouldUseCachedValue(_cachedCurrentWeekInCycle)) {
      return _cachedCurrentWeekInCycle;
    }

    final currentDay = getCurrentProgramDayInCycle();
    _cachedCurrentWeekInCycle = currentDay == null
        ? null
        : ((currentDay - 1) / 7).floor() + 1;

    _updateCacheTimestamp();
    return _cachedCurrentWeekInCycle;
  }

  /// Gets the current cycle number (1, 2, 3, ...).
  int? getCurrentCycleNumber() {
    if (_shouldUseCachedValue(_cachedCurrentCycleNumber)) {
      return _cachedCurrentCycleNumber;
    }

    _cachedCurrentCycleNumber = _calculateCurrentCycleNumber();
    _updateCacheTimestamp();
    return _cachedCurrentCycleNumber;
  }

  /// Gets overall program progress statistics.
  Map<String, double> getOverallProgress() {
    if (_shouldUseCachedValue(_cachedProgress)) {
      return Map<String, double>.from(_cachedProgress!);
    }

    _cachedProgress = _calculateOverallProgress();
    _updateCacheTimestamp();
    return Map<String, double>.from(_cachedProgress!);
  }

  /// Gets current cycle session statistics (completed, skipped, remaining).
  Map<String, int> getCurrentCycleSessionStats() {
    //debugPrint("WorkoutProvider: getCurrentCycleSessionStats CALLED");

    if (_shouldUseCachedValue(_cachedCycleStats)) {
      /*
      debugPrint(
        "WorkoutProvider: Using cached cycle stats: $_cachedCycleStats",
      );
      */
      return Map<String, int>.from(_cachedCycleStats!);
    }

    //debugPrint("WorkoutProvider: Calculating fresh cycle stats");
    _cachedCycleStats = _calculateCurrentCycleSessionStats();
    _updateCacheTimestamp();

    //debugPrint("WorkoutProvider: Fresh cycle stats: $_cachedCycleStats");
    return Map<String, int>.from(_cachedCycleStats!);
  }

  /// Gets workout sessions for the current week.
  List<WorkoutSession> getThisWeekSessions() {
    if (_shouldUseCachedValue(_cachedThisWeekSessions)) {
      return List<WorkoutSession>.from(_cachedThisWeekSessions!);
    }

    _cachedThisWeekSessions = _calculateThisWeekSessions();
    _updateCacheTimestamp();
    return List<WorkoutSession>.from(_cachedThisWeekSessions!);
  }

  // Business logic methods

  /// Gets today's scheduled workout.
  Workout? getTodaysWorkout() {
    if (_workouts.isEmpty) return null;
    final currentDay = getCurrentProgramDayInCycle();
    if (currentDay == null) return null;

    try {
      return _workouts.firstWhere((w) => w.dayNumber == currentDay);
    } catch (e) {
      //debugPrint("WorkoutProvider: Could not find workout for day $currentDay");
      return null;
    }
  }

  /// Gets all workouts for a specific week in the cycle.
  List<Workout> getWeekWorkouts(int weekInCycle) {
    if (weekInCycle < 1 || weekInCycle > programCycleLengthWeeks) {
      return [];
    }
    return _workouts
        .where((workout) => workout.weekNumber == weekInCycle)
        .toList();
  }

  /// Gets the workout session for a specific date.
  WorkoutSession? getSessionForDate(String dateString) {
    try {
      return _sessions.firstWhere((session) => session.date == dateString);
    } catch (e) {
      return null;
    }
  }

  /// Gets the scheduled workout for a specific date.
  Workout? getWorkoutForDate(DateTime date) {
    if (_programStartDate == null || _workouts.isEmpty) return null;

    final dateNormalized = _normalizeDatetime(date);
    final startDateNormalized = _normalizeDatetime(_programStartDate!);

    if (dateNormalized.isBefore(startDateNormalized)) return null;

    final daysSinceProgramStart = dateNormalized
        .difference(startDateNormalized)
        .inDays;
    final dayInCycle = (daysSinceProgramStart % programCycleLengthDays) + 1;

    try {
      return _workouts.firstWhere((w) => w.dayNumber == dayInCycle);
    } catch (e) {
      //debugPrint("WorkoutProvider: Could not find workout for day $dayInCycle");
      return null;
    }
  }

  /// Clears any error state.
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  // Private methods

  /// Wrapper for operations that handles loading state and error management.
  Future<void> _performOperation(Future<void> Function() operation) async {
    if (_isLoading) return; // Prevent concurrent operations

    _setLoadingState(true);
    _lastError = null;

    try {
      await operation();
    } catch (e) {
      _lastError = e.toString();
      //debugPrint('WorkoutProvider error: $e');

      // Ensure we maintain valid state on error
      _workouts = _workouts.isEmpty ? [] : _workouts;
      _sessions = _sessions.isEmpty ? [] : _sessions;

      rethrow;
    } finally {
      _setLoadingState(false);
    }
  }

  Future<void> _loadProgramStartDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startDateString = prefs.getString(_programStartDateKey);
      if (startDateString != null) {
        _programStartDate = DateTime.tryParse(startDateString);
      }
    } catch (e) {
      //debugPrint('Error loading program start date: $e');
      _programStartDate = null;
    }
  }

  Future<void> _loadWorkouts() async {
    try {
      _workouts = await _databaseService.getAllWorkouts();
      _workouts.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    } catch (e) {
      //debugPrint('Error loading workouts: $e');
      _workouts = [];
    }
  }

  Future<void> _loadWorkoutSessions() async {
    try {
      final newSessions = await _databaseService.getAllWorkoutSessions();
      final newHash = _calculateSessionsHash(newSessions);

      if (_lastSessionsHash != newHash) {
        _sessions = newSessions;
        _lastSessionsHash = newHash;
        _invalidateComputedCaches(); // Only invalidate computed caches, not basic data
      }
    } catch (e) {
      //debugPrint('Error loading workout sessions: $e');
      _sessions = [];
    }
  }

  Future<void> _clearExistingSessions() async {
    try {
      await _databaseService.deleteAllWorkoutSessions();
      _sessions = [];
    } catch (e) {
      //debugPrint('Error clearing existing workout sessions: $e');
      _sessions = [];
    }
  }

  Future<void> _updateProgramStartDate(DateTime startDate) async {
    _programStartDate = startDate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_programStartDateKey, startDate.toIso8601String());
  }

  Future<void> _reloadData() async {
    await Future.wait([_loadWorkouts(), _loadWorkoutSessions()]);
  }

  Future<void> _autoCompletePastWorkouts(DateTime programStartDate) async {
    if (_workouts.isEmpty) {
      await _loadWorkouts();
      if (_workouts.isEmpty) {
        //debugPrint("Cannot auto-complete: Workouts list is empty.");
        return;
      }
    }

    final today = _getTodayNormalized();
    final startDateNormalized = _normalizeDatetime(programStartDate);

    final sessionsToInsert = <WorkoutSession>[];

    for (int dayOffset = 0; ; dayOffset++) {
      final currentDate = startDateNormalized.add(Duration(days: dayOffset));

      if (!currentDate.isBefore(today)) break;

      final workout = await _getWorkoutForDayOffset(
        dayOffset,
        startDateNormalized,
      );
      if (workout == null || workout.workoutType == 'rest') continue;

      final dateString = _dateToString(currentDate);
      final existingSession = await _databaseService.getWorkoutSessionByDate(
        dateString,
      );

      if (existingSession == null) {
        sessionsToInsert.add(
          WorkoutSession(
            workoutId: workout.id,
            date: dateString,
            completed: true,
            notes: 'Auto-completed',
          ),
        );
      }

      // Process in batches of 10
      if (sessionsToInsert.length >= 10) {
        await _insertSessionsBatch(sessionsToInsert);
        sessionsToInsert.clear();
      }
    }

    // Insert remaining sessions
    if (sessionsToInsert.isNotEmpty) {
      await _insertSessionsBatch(sessionsToInsert);
    }
  }

  Future<void> _insertSessionsBatch(List<WorkoutSession> sessions) async {
    for (final session in sessions) {
      await _databaseService.insertWorkoutSession(session);
    }
  }

  Future<void> _updateWorkoutSession({
    required int workoutId,
    required bool completed,
    String? notes,
    DateTime? dateOverride,
  }) async {
    try {
      final dateString = _dateToString(dateOverride ?? DateTime.now());
      final existingSession = await _databaseService.getWorkoutSessionByDate(
        dateString,
      );

      final session =
          existingSession?.copyWith(
            workoutId: workoutId,
            completed: completed,
            notes: notes,
          ) ??
          WorkoutSession(
            workoutId: workoutId,
            date: dateString,
            completed: completed,
            notes: notes,
          );

      if (existingSession != null) {
        await _databaseService.updateWorkoutSession(session);
      } else {
        await _databaseService.insertWorkoutSession(session);
      }

      await _loadWorkoutSessions(); // This will invalidate caches automatically
      notifyListeners();
    } catch (e) {
      //debugPrint('Error updating workout session: $e');
      rethrow;
    }
  }

  Future<void> _processSessions(List<WorkoutSession> sessions) async {
    for (final session in sessions) {
      final existingSession = await _databaseService.getWorkoutSessionByDate(
        session.date,
      );

      if (existingSession != null) {
        final updatedSession = session.copyWith(id: existingSession.id);
        await _databaseService.updateWorkoutSession(updatedSession);
      } else {
        await _databaseService.insertWorkoutSession(session);
      }
    }
  }

  void _setLoadingState(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  // Cache management - FIXED LOGIC

  /// Checks if a cached value should be used instead of recalculating.
  bool _shouldUseCachedValue<T>(T? cachedValue) {
    if (cachedValue == null) return false;
    if (_cacheInvalidated) return false;

    final now = DateTime.now();
    if (_lastCacheUpdate == null) return false;

    // Cache is valid for _cacheValidityMinutes
    return now.difference(_lastCacheUpdate!).inMinutes < _cacheValidityMinutes;
  }

  /// Updates the cache timestamp and resets invalidation flag.
  void _updateCacheTimestamp() {
    _lastCacheUpdate = DateTime.now();
    _cacheInvalidated = false;
  }

  /// Refreshes all caches by recalculating them immediately.
  void _refreshCaches() {
    //debugPrint("WorkoutProvider: Refreshing all caches");
    _cachedCurrentDayInCycle = _calculateCurrentProgramDayInCycle();
    _cachedCurrentWeekInCycle = _cachedCurrentDayInCycle == null
        ? null
        : ((_cachedCurrentDayInCycle! - 1) / 7).floor() + 1;
    _cachedCurrentCycleNumber = _calculateCurrentCycleNumber();
    _cachedProgress = _calculateOverallProgress();
    _cachedCycleStats = _calculateCurrentCycleSessionStats();
    _cachedThisWeekSessions = _calculateThisWeekSessions();
    _updateCacheTimestamp();
    //debugPrint("WorkoutProvider: Cache refresh complete");
  }

  /// Invalidates only the computed caches, not the basic data caches.
  void _invalidateComputedCaches() {
    //debugPrint("WorkoutProvider: Invalidating computed caches");
    _cachedProgress = null;
    _cachedCycleStats = null;
    _cachedThisWeekSessions = null;
    _cacheInvalidated = true;
  }

  /// Clears all caches completely.
  void _clearCaches() {
    _cachedProgress = null;
    _cachedCycleStats = null;
    _cachedThisWeekSessions = null;
    _cachedCurrentDayInCycle = null;
    _cachedCurrentWeekInCycle = null;
    _cachedCurrentCycleNumber = null;
    _lastCacheUpdate = null;
    _lastSessionsHash = null;
    _cacheInvalidated = false;
  }

  // Calculation methods (unchanged but cleaned up)

  int? _calculateCurrentProgramDayInCycle() {
    if (_programStartDate == null) return null;

    final today = _getTodayNormalized();
    final startDateNormalized = _normalizeDatetime(_programStartDate!);

    if (today.isBefore(startDateNormalized)) return null;

    final daysSinceProgramStart = today.difference(startDateNormalized).inDays;
    return (daysSinceProgramStart % programCycleLengthDays) + 1;
  }

  int? _calculateCurrentCycleNumber() {
    if (_programStartDate == null) return null;

    final today = _getTodayNormalized();
    final startDateNormalized = _normalizeDatetime(_programStartDate!);

    if (today.isBefore(startDateNormalized)) return null;

    final daysSinceProgramStart = today.difference(startDateNormalized).inDays;
    return (daysSinceProgramStart / programCycleLengthDays).floor() + 1;
  }

  Map<String, double> _calculateOverallProgress() {
    const defaultProgress = {
      'currentCycleProgress': 0.0,
      'completedCycles': 0.0,
    };

    if (_programStartDate == null || _workouts.isEmpty) {
      return defaultProgress;
    }

    final totalProgressCountableWorkoutDaysInOneCycle = _workouts
        .where((w) => w.workoutType == 'workout' || w.workoutType == 'fit_test')
        .length;

    if (totalProgressCountableWorkoutDaysInOneCycle == 0) {
      return defaultProgress;
    }

    final today = _getTodayNormalized();
    final startDateNormalized = _normalizeDatetime(_programStartDate!);
    final daysSinceProgramStart = today.difference(startDateNormalized).inDays;

    if (daysSinceProgramStart < 0) {
      return defaultProgress;
    }

    final completedCycles = (daysSinceProgramStart / programCycleLengthDays)
        .floor();
    final currentCycleStartDate = startDateNormalized.add(
      Duration(days: completedCycles * programCycleLengthDays),
    );

    int completedInCurrentCycle = 0;
    final sessionMap = {for (var session in _sessions) session.date: session};

    for (int i = 0; i < programCycleLengthDays; i++) {
      final dateInCycle = currentCycleStartDate.add(Duration(days: i));
      if (dateInCycle.isAfter(today)) break;

      final dateString = _dateToString(dateInCycle);
      final session = sessionMap[dateString];

      if (session?.completed == true) {
        final workout = _getWorkoutById(session!.workoutId);
        if (workout != null &&
            (workout.workoutType == 'workout' ||
                workout.workoutType == 'fit_test')) {
          completedInCurrentCycle++;
        }
      }
    }

    final currentCycleProgress =
        (completedInCurrentCycle /
                totalProgressCountableWorkoutDaysInOneCycle *
                100)
            .clamp(0.0, 100.0);

    return {
      'currentCycleProgress': currentCycleProgress.isNaN
          ? 0.0
          : currentCycleProgress,
      'completedCycles': completedCycles.toDouble(),
    };
  }

  Map<String, int> _calculateCurrentCycleSessionStats() {
    const defaultStats = {
      'completed': 0,
      'skipped': 0,
      'remaining': 0,
      'totalInCycle': 0,
    };

    /*
    debugPrint(
      '_calculateCurrentCycleSessionStats: Program Start Date: $_programStartDate',
    );
    */
    if (_programStartDate == null || _workouts.isEmpty) {
      return defaultStats;
    }

    final today = _getTodayNormalized();
    final startDateNormalized = _normalizeDatetime(_programStartDate!);

    final totalCountableDays = _workouts
        .where((w) => w.workoutType == 'workout' || w.workoutType == 'fit_test')
        .length;

    if (today.isBefore(startDateNormalized)) {
      return {
        'completed': 0,
        'skipped': 0,
        'remaining': totalCountableDays,
        'totalInCycle': totalCountableDays,
      };
    }

    final daysSinceProgramStart = today.difference(startDateNormalized).inDays;
    final currentCycleNumber = (daysSinceProgramStart / programCycleLengthDays)
        .floor();
    final currentCycleStartDate = startDateNormalized.add(
      Duration(days: currentCycleNumber * programCycleLengthDays),
    );

    int completed = 0;
    int skipped = 0;
    final sessionMap = {for (var session in _sessions) session.date: session};
    /*
    debugPrint(
      '_calculateCurrentCycleSessionStats: Checking sessions from ${_dateToString(currentCycleStartDate)} for $programCycleLengthDays days',
    );
    debugPrint(
      '_calculateCurrentCycleSessionStats: Session map has ${sessionMap.length} entries',
    );
    */

    for (int dayOffset = 0; dayOffset < programCycleLengthDays; dayOffset++) {
      final dateInCycle = currentCycleStartDate.add(Duration(days: dayOffset));
      if (dateInCycle.isAfter(today)) break;

      final workout = _getWorkoutForDayOffsetSync(dayOffset);
      if (workout?.workoutType != 'workout' &&
          workout?.workoutType != 'fit_test') {
        continue;
      }

      final dateString = _dateToString(dateInCycle);
      final session = sessionMap[dateString];

      if (session?.completed == true) {
        completed++;
        /*
        debugPrint(
          '_calculateCurrentCycleSessionStats: Found completed session for $dateString',
        );
        */
      } else if (session != null || dateInCycle.isBefore(today)) {
        skipped++;
        /*
        debugPrint(
          '_calculateCurrentCycleSessionStats: Found skipped/missed session for $dateString',
        );
        */
      }
    }

    final result = {
      'completed': completed,
      'skipped': skipped,
      'remaining': (totalCountableDays - completed).clamp(
        0,
        totalCountableDays,
      ),
      'totalInCycle': totalCountableDays,
    };

    //debugPrint('_calculateCurrentCycleSessionStats: Final result: $result');
    return result;
  }

  List<WorkoutSession> _calculateThisWeekSessions() {
    final currentWeek = getCurrentProgramWeekInCycle();
    final currentCycle = getCurrentCycleNumber();

    if (_programStartDate == null ||
        currentWeek == null ||
        currentCycle == null) {
      return [];
    }

    final daysFromCycleStart = (currentWeek - 1) * 7;
    final cycleStartDate = _normalizeDatetime(
      _programStartDate!,
    ).add(Duration(days: (currentCycle - 1) * programCycleLengthDays));
    final weekStartDate = cycleStartDate.add(
      Duration(days: daysFromCycleStart),
    );

    final sessionMap = {for (var session in _sessions) session.date: session};
    final weekSessions = <WorkoutSession>[];

    for (int i = 0; i < 7; i++) {
      final date = weekStartDate.add(Duration(days: i));
      final session = sessionMap[_dateToString(date)];
      if (session != null) {
        weekSessions.add(session);
      }
    }

    return weekSessions;
  }

  // Utility methods (unchanged)

  DateTime _getTodayNormalized() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _normalizeDatetime(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dateToString(DateTime date) {
    return date.toIso8601String().split('T')[0];
  }

  DateTime _findMondayBefore(DateTime date) {
    DateTime monday = date;
    while (monday.weekday != DateTime.monday) {
      monday = monday.subtract(const Duration(days: 1));
    }
    return monday;
  }

  bool _isDateDifferent(DateTime? date1, DateTime date2) {
    if (date1 == null) return true;
    return date1.year != date2.year ||
        date1.month != date2.month ||
        date1.day != date2.day;
  }

  String _calculateSessionsHash(List<WorkoutSession> sessions) {
    return sessions
        .map((s) => '${s.date}-${s.completed}-${s.workoutId}')
        .join('|');
  }

  Workout? _getWorkoutById(int workoutId) {
    try {
      return _workouts.firstWhere((w) => w.id == workoutId);
    } catch (e) {
      return null;
    }
  }

  Future<Workout?> _getWorkoutForDayOffset(
    int dayOffset,
    DateTime startDate,
  ) async {
    final dayInCycle = (dayOffset % programCycleLengthDays) + 1;

    try {
      return _workouts.firstWhere((w) => w.dayNumber == dayInCycle);
    } catch (e) {
      return null;
    }
  }

  Workout? _getWorkoutForDayOffsetSync(int dayOffset) {
    final dayInCycle = (dayOffset % programCycleLengthDays) + 1;
    try {
      return _workouts.firstWhere((w) => w.dayNumber == dayInCycle);
    } catch (e) {
      return null;
    }
  }
}
