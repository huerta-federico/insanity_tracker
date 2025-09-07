import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../services/database_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  // Core data
  List<Workout> _workouts = [];
  List<WorkoutSession> _sessions = [];
  bool _isLoading = false;
  DateTime? _programStartDate;

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

  // Constants
  static const int programCycleLengthDays = 63;
  static const int programCycleLengthWeeks = 9;
  static const String _programStartDateKey = 'programStartDate';

  // Getters
  List<Workout> get workouts => List.unmodifiable(_workouts);
  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoading => _isLoading;
  DateTime? get programStartDate => _programStartDate;

  @override
  void dispose() {
    _clearCaches();
    super.dispose();
  }

  Future<void> initialize() async {
    debugPrint("WorkoutProvider: INITIALIZE START");
    if (_isLoading) {
      debugPrint("WorkoutProvider: Already loading, skipping initialization.");
      return;
    }// Prevent multiple initializations

    await _setLoadingState(true);

    try {
      await Future.wait([
        _loadProgramStartDate(),
        _loadWorkouts(),
      ]);
      await _loadWorkoutSessions();
      _invalidateCaches();
    } catch (e) {
      debugPrint('Error initializing WorkoutProvider: $e');
      _programStartDate = null;
      _workouts = [];
      _sessions = [];
    } finally {
      await _setLoadingState(false);
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
      debugPrint('Error loading program start date: $e');
      _programStartDate = null;
    }
  }

  Future<void> setProgramStartDate(
      DateTime startDate, {
        bool shouldReloadData = true,
        bool autoPopulatePastWorkouts = true,
      }) async {
    await _setLoadingState(true);

    try {
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

      _invalidateCaches();
    } catch (e) {
      debugPrint('Error setting program start date: $e');
      rethrow;
    } finally {
      await _setLoadingState(false);
    }
  }

  Future<void> _clearExistingSessions() async {
    try {
      await _databaseService.deleteAllWorkoutSessions();
      _sessions = [];
    } catch (e) {
      debugPrint('Error clearing existing workout sessions: $e');
      _sessions = [];
    }
  }

  Future<void> _updateProgramStartDate(DateTime startDate) async {
    _programStartDate = startDate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_programStartDateKey, startDate.toIso8601String());
  }

  Future<void> _reloadData() async {
    await Future.wait([
      _loadWorkouts(),
      _loadWorkoutSessions(),
    ]);
  }

  Future<void> _autoCompletePastWorkouts(DateTime programStartDate) async {
    if (_workouts.isEmpty) {
      await _loadWorkouts();
      if (_workouts.isEmpty) {
        debugPrint("Cannot auto-complete: Workouts list is empty.");
        return;
      }
    }

    final today = _getTodayNormalized();
    final startDateNormalized = _normalizeDatetime(programStartDate);

    // Process in batches to avoid blocking the UI
    final sessionsToInsert = <WorkoutSession>[];

    for (int dayOffset = 0; ; dayOffset++) {
      final currentDate = startDateNormalized.add(Duration(days: dayOffset));

      if (!currentDate.isBefore(today)) break;

      final workout = await _getWorkoutForDayOffset(dayOffset, startDateNormalized);
      if (workout == null || workout.workoutType == 'rest') continue;

      final dateString = _dateToString(currentDate);
      final existingSession = await _databaseService.getWorkoutSessionByDate(dateString);

      if (existingSession == null) {
        sessionsToInsert.add(WorkoutSession(
          workoutId: workout.id,
          date: dateString,
          completed: true,
          notes: 'Auto-completed',
        ));
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

  Future<bool> reconcileStartDateFromImportedData() async {
    if (_sessions.isEmpty) {
      debugPrint("WorkoutProvider: No sessions found to infer start date after import.");
      return false;
    }

    final sortedSessions = List<WorkoutSession>.from(_sessions)
      ..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

    final earliestDate = DateTime.parse(sortedSessions.first.date);
    final potentialStartDate = _findMondayBefore(earliestDate);

    if (_isDateDifferent(_programStartDate, potentialStartDate)) {
      await _setLoadingState(true);

      try {
        await _updateProgramStartDate(potentialStartDate);
        _invalidateCaches();
        return true;
      } finally {
        await _setLoadingState(false);
      }
    }

    return true;
  }

  Future<void> clearProgramStartDate() async {
    await _setLoadingState(true);

    try {
      _programStartDate = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_programStartDateKey);

      await _databaseService.deleteAllWorkoutSessions();
      _sessions = [];
      _invalidateCaches();
    } catch (e) {
      debugPrint('Error clearing program start date: $e');
      _sessions = [];
    } finally {
      await _setLoadingState(false);
    }
  }

  Future<void> _loadWorkouts() async {
    try {
      _workouts = await _databaseService.getAllWorkouts();
      _workouts.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    } catch (e) {
      debugPrint('Error loading workouts: $e');
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
        _invalidateCaches();
      }
    } catch (e) {
      debugPrint('Error loading workout sessions: $e');
      _sessions = [];
    }
  }

  // Cached computation methods
  int? getCurrentProgramDayInCycle() {
    debugPrint('Program Start Date: $_programStartDate');
    if (_shouldRecalculateCache()) {
      _cachedCurrentDayInCycle = _calculateCurrentProgramDayInCycle();
    }
    return _cachedCurrentDayInCycle;
  }

  int? getCurrentProgramWeekInCycle() {
    if (_shouldRecalculateCache()) {
      final currentDay = getCurrentProgramDayInCycle();
      _cachedCurrentWeekInCycle = currentDay == null
          ? null
          : ((currentDay - 1) / 7).floor() + 1;
    }
    return _cachedCurrentWeekInCycle;
  }

  int? getCurrentCycleNumber() {
    if (_shouldRecalculateCache()) {
      _cachedCurrentCycleNumber = _calculateCurrentCycleNumber();
    }
    return _cachedCurrentCycleNumber;
  }

  Map<String, double> getOverallProgress() {
    if (_shouldRecalculateCache()) {
      _cachedProgress = _calculateOverallProgress();
    }
    return Map<String, double>.from(_cachedProgress ?? {'currentCycleProgress': 0.0, 'completedCycles': 0.0});
  }

  Map<String, int> getCurrentCycleSessionStats() {
    debugPrint("WorkoutProvider: getCurrentCycleSessionStats CALLED");
    if (_shouldRecalculateCache() || _cachedCycleStats == null) {
      _cachedCycleStats = _calculateCurrentCycleSessionStats();
      debugPrint("WorkoutProvider: _cachedCycleStats: ${_cachedCycleStats != null}");
    }
    return Map<String, int>.from(_cachedCycleStats ??
        {'completed': 0, 'skipped': 0, 'remaining': 0, 'totalInCycle': 0});
  }

  List<WorkoutSession> getThisWeekSessions() {
    if (_shouldRecalculateCache()) {
      _cachedThisWeekSessions = _calculateThisWeekSessions();
    }
    return List<WorkoutSession>.from(_cachedThisWeekSessions ?? []);
  }

  // Core business logic methods
  Workout? getTodaysWorkout() {
    if (_workouts.isEmpty) return null;
    final currentDay = getCurrentProgramDayInCycle();
    if (currentDay == null) return null;

    try {
      return _workouts.firstWhere((w) => w.dayNumber == currentDay);
    } catch (e) {
      debugPrint("WorkoutProvider: Could not find workout for day $currentDay");
      return null;
    }
  }

  List<Workout> getWeekWorkouts(int weekInCycle) {
    if (weekInCycle < 1 || weekInCycle > programCycleLengthWeeks) {
      return [];
    }
    return _workouts.where((workout) => workout.weekNumber == weekInCycle).toList();
  }

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

  WorkoutSession? getSessionForDate(String dateString) {
    try {
      return _sessions.firstWhere((session) => session.date == dateString);
    } catch (e) {
      return null;
    }
  }

  Workout? getWorkoutForDate(DateTime date) {
    if (_programStartDate == null || _workouts.isEmpty) return null;

    final dateNormalized = _normalizeDatetime(date);
    final startDateNormalized = _normalizeDatetime(_programStartDate!);

    if (dateNormalized.isBefore(startDateNormalized)) return null;

    final daysSinceProgramStart = dateNormalized.difference(startDateNormalized).inDays;
    final dayInCycle = (daysSinceProgramStart % programCycleLengthDays) + 1;

    try {
      return _workouts.firstWhere((w) => w.dayNumber == dayInCycle);
    } catch (e) {
      debugPrint("WorkoutProvider: Could not find workout for day $dayInCycle");
      return null;
    }
  }

  Future<void> bulkUpsertWorkoutSessions(List<WorkoutSession> sessionsToProcess) async {
    if (sessionsToProcess.isEmpty) return;

    await _setLoadingState(true);

    try {
      // Process in batches for better performance
      const batchSize = 20;
      for (int i = 0; i < sessionsToProcess.length; i += batchSize) {
        final batch = sessionsToProcess.skip(i).take(batchSize);
        await _processSessions(batch.toList());
      }

      await _loadWorkoutSessions();
      _invalidateCaches();
    } catch (e) {
      debugPrint('Error in bulkUpsertWorkoutSessions: $e');
      rethrow;
    } finally {
      await _setLoadingState(false);
    }
  }

  // Private helper methods
  Future<void> _setLoadingState(bool loading) async {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
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
      final existingSession = await _databaseService.getWorkoutSessionByDate(dateString);

      final session = existingSession?.copyWith(
        workoutId: workoutId,
        completed: completed,
        notes: notes,
      ) ?? WorkoutSession(
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

      await _loadWorkoutSessions();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating workout session: $e');
      rethrow;
    }
  }

  Future<void> _processSessions(List<WorkoutSession> sessions) async {
    for (final session in sessions) {
      final existingSession = await _databaseService.getWorkoutSessionByDate(session.date);

      if (existingSession != null) {
        final updatedSession = session.copyWith(id: existingSession.id);
        await _databaseService.updateWorkoutSession(updatedSession);
      } else {
        await _databaseService.insertWorkoutSession(session);
      }
    }
  }

  // Cache management
  bool _shouldRecalculateCache() {
    final now = DateTime.now();
    debugPrint("WorkoutProvider: _shouldRecalculateCache CHECKING:");
    debugPrint("WorkoutProvider: _lastCacheUpdate: $_lastCacheUpdate");
    debugPrint("WorkoutProvider: _cachedProgress: ${_cachedProgress != null}");
    debugPrint("WorkoutProvider: _cachedCycleStats: ${_cachedCycleStats != null}"); // Add this check for specific use case

    return _lastCacheUpdate == null ||
        now.difference(_lastCacheUpdate!).inMinutes > 5 ||
        _cachedProgress == null;
  }

  void _invalidateCaches() {
    _cachedProgress = null;
    _cachedCycleStats = null;
    _cachedThisWeekSessions = null;
    _cachedCurrentDayInCycle = null;
    _cachedCurrentWeekInCycle = null;
    _cachedCurrentCycleNumber = null;
    _lastCacheUpdate = DateTime.now();
  }

  void _clearCaches() {
    _invalidateCaches();
    _lastSessionsHash = null;
  }

  // Calculation methods
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
    if (_programStartDate == null || _workouts.isEmpty) {
      return {'currentCycleProgress': 0.0, 'completedCycles': 0.0};
    }

    final totalProgressCountableWorkoutDaysInOneCycle = _workouts
        .where((w) => w.workoutType == 'workout' || w.workoutType == 'fit_test')
        .length;

    if (totalProgressCountableWorkoutDaysInOneCycle == 0) {
      return {'currentCycleProgress': 0.0, 'completedCycles': 0.0};
    }

    final today = _getTodayNormalized();
    final startDateNormalized = _normalizeDatetime(_programStartDate!);
    final daysSinceProgramStart = today.difference(startDateNormalized).inDays;

    if (daysSinceProgramStart < 0) {
      return {'currentCycleProgress': 0.0, 'completedCycles': 0.0};
    }

    final completedCycles = (daysSinceProgramStart / programCycleLengthDays).floor();
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
            (workout.workoutType == 'workout' || workout.workoutType == 'fit_test')) {
          completedInCurrentCycle++;
        }
      }
    }

    final currentCycleProgress =
    (completedInCurrentCycle / totalProgressCountableWorkoutDaysInOneCycle * 100)
        .clamp(0.0, 100.0);

    return {
      'currentCycleProgress': currentCycleProgress.isNaN ? 0.0 : currentCycleProgress,
      'completedCycles': completedCycles.toDouble(),
    };
  }

  Map<String, int> _calculateCurrentCycleSessionStats() {
    debugPrint('Program Start Date: $_programStartDate');
    if (_programStartDate == null || _workouts.isEmpty) {
      return {'completed': 0, 'skipped': 0, 'remaining': 0, 'totalInCycle': 0};
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
    final currentCycleNumber = (daysSinceProgramStart / programCycleLengthDays).floor();
    final currentCycleStartDate = startDateNormalized.add(
      Duration(days: currentCycleNumber * programCycleLengthDays),
    );

    int completed = 0;
    int skipped = 0;
    final sessionMap = {for (var session in _sessions) session.date: session};

    for (int dayOffset = 0; dayOffset < programCycleLengthDays; dayOffset++) {
      final dateInCycle = currentCycleStartDate.add(Duration(days: dayOffset));
      if (dateInCycle.isAfter(today)) break;

      final workout = _getWorkoutForDayOffsetSync(dayOffset);
      if (workout?.workoutType != 'workout' && workout?.workoutType != 'fit_test') {
        continue;
      }

      final dateString = _dateToString(dateInCycle);
      final session = sessionMap[dateString];

      if (session?.completed == true) {
        completed++;
      } else if (session != null || dateInCycle.isBefore(today)) {
        skipped++;
      }
    }

    return {
      'completed': completed,
      'skipped': skipped,
      'remaining': (totalCountableDays - completed).clamp(0, totalCountableDays),
      'totalInCycle': totalCountableDays,
    };
  }

  List<WorkoutSession> _calculateThisWeekSessions() {
    final currentWeek = getCurrentProgramWeekInCycle();
    final currentCycle = getCurrentCycleNumber();

    if (_programStartDate == null || currentWeek == null || currentCycle == null) {
      return [];
    }

    final daysFromCycleStart = (currentWeek - 1) * 7;
    final cycleStartDate = _normalizeDatetime(_programStartDate!).add(
      Duration(days: (currentCycle - 1) * programCycleLengthDays),
    );
    final weekStartDate = cycleStartDate.add(Duration(days: daysFromCycleStart));

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

  // Utility methods
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