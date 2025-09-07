import 'package:flutter/foundation.dart';
import '../models/fit_test.dart';
import '../services/database_service.dart';

/// Provider that manages fit test data and state.
///
/// This provider handles loading, saving, deleting, and analyzing fit test results,
/// including automatic renumbering based on chronological order and improvement calculations.
class FitTestProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  List<FitTest> _fitTests = [];
  bool _isLoading = false;
  String? _lastError;

  /// Returns an unmodifiable view of all fit tests, sorted by date.
  List<FitTest> get fitTests => List.unmodifiable(_fitTests);

  /// Returns true if a database operation is currently in progress.
  bool get isLoading => _isLoading;

  /// Returns the last error message, if any.
  String? get lastError => _lastError;

  /// Initializes the provider by loading all fit tests from the database.
  ///
  /// This method should be called once when the app starts.
  /// Sets [isLoading] to true during the operation.
  Future<void> initialize() async {
    await _performDatabaseOperation(_loadAndRenumberFitTests);
  }

  /// Saves a new fit test to the database.
  ///
  /// The test number will be automatically assigned based on chronological order.
  /// After saving, all tests are reloaded and renumbered to maintain consistency.
  ///
  /// Parameters:
  /// - [fitTest]: The fit test data to save
  ///
  /// Throws an exception if the save operation fails.
  Future<void> saveFitTest(FitTest fitTest) async {
    await _performDatabaseOperation(() async {
      // Prepare the fit test data with provisional test number if not set
      final Map<String, dynamic> fitTestMap = fitTest.toMap();

      if (!fitTestMap.containsKey('test_number') ||
          fitTestMap['test_number'] == null) {
        fitTestMap['test_number'] = getNextTestNumber();
      }

      final FitTest testToInsert = FitTest.fromMap(fitTestMap);
      await _databaseService.insertFitTest(testToInsert);
      await _loadAndRenumberFitTests();
    });
  }

  /// Deletes a fit test from the database.
  ///
  /// After deletion, all remaining tests are reloaded and renumbered.
  ///
  /// Parameters:
  /// - [id]: The database ID of the fit test to delete
  ///
  /// Throws an exception if the delete operation fails.
  Future<void> deleteFitTest(int id) async {
    await _performDatabaseOperation(() async {
      await _databaseService.deleteFitTest(id);
      await _loadAndRenumberFitTests();
    });
  }

  /// Returns the most recent fit test, or null if no tests exist.
  FitTest? getLatestFitTest() {
    return _fitTests.isEmpty ? null : _fitTests.last;
  }

  /// Returns all fit test results in chronological order.
  List<FitTest> getAllResults() {
    return _fitTests; // Already sorted and correctly numbered
  }

  /// Returns the test number that would be assigned to the next fit test.
  ///
  /// This is based on the current number of tests plus one.
  int getNextTestNumber() {
    return _fitTests.length + 1;
  }

  /// Checks if it's time for the next fit test based on the program schedule.
  ///
  /// Rules:
  /// - If no tests exist, returns true if the program has started
  /// - If tests exist, returns true if 14+ days have passed since the last test
  ///
  /// Parameters:
  /// - [programStartDate]: The date the program started
  ///
  /// Returns true if a new fit test is due.
  bool isNextTestDue(DateTime programStartDate) {
    if (_fitTests.isEmpty) {
      final daysSinceStart = DateTime.now().difference(programStartDate).inDays;
      return daysSinceStart >= 0;
    }

    final FitTest? lastTest = getLatestFitTest();
    if (lastTest == null) return true; // Shouldn't happen but handle gracefully

    final DateTime lastTestDate = DateTime.parse(lastTest.testDate);
    final int daysSinceLastTest = DateTime.now()
        .difference(lastTestDate)
        .inDays;
    return daysSinceLastTest >= 14;
  }

  /// Calculates improvement percentages for each exercise between first and latest test.
  ///
  /// Returns a map with exercise names as keys and improvement percentages as values.
  /// Returns empty map if fewer than 2 tests exist.
  ///
  /// Example: {'switchKicks': 25.0, 'powerJacks': -10.5, ...}
  Map<String, double> getImprovementPercentages() {
    if (_fitTests.length < 2) return {};

    final FitTest firstTest = _fitTests.first;
    final FitTest latestTest = _fitTests.last;

    return {
      'switchKicks': _calculateImprovement(
        firstTest.switchKicks,
        latestTest.switchKicks,
      ),
      'powerJacks': _calculateImprovement(
        firstTest.powerJacks,
        latestTest.powerJacks,
      ),
      'powerKnees': _calculateImprovement(
        firstTest.powerKnees,
        latestTest.powerKnees,
      ),
      'powerJumps': _calculateImprovement(
        firstTest.powerJumps,
        latestTest.powerJumps,
      ),
      'globeJumps': _calculateImprovement(
        firstTest.globeJumps,
        latestTest.globeJumps,
      ),
      'suicideJumps': _calculateImprovement(
        firstTest.suicideJumps,
        latestTest.suicideJumps,
      ),
      'pushupJacks': _calculateImprovement(
        firstTest.pushupJacks,
        latestTest.pushupJacks,
      ),
      'lowPlankOblique': _calculateImprovement(
        firstTest.lowPlankOblique,
        latestTest.lowPlankOblique,
      ),
    };
  }

  /// Gets improvement data for a specific exercise between two tests.
  ///
  /// Parameters:
  /// - [exerciseName]: Name of the exercise (e.g., 'switchKicks')
  /// - [fromTestNumber]: Starting test number (defaults to 1)
  /// - [toTestNumber]: Ending test number (defaults to latest)
  ///
  /// Returns null if the specified tests don't exist or exercise name is invalid.
  double? getExerciseImprovement(
    String exerciseName, {
    int fromTestNumber = 1,
    int? toTestNumber,
  }) {
    if (_fitTests.isEmpty) return null;

    toTestNumber ??= _fitTests.length;

    if (fromTestNumber < 1 ||
        toTestNumber < 1 ||
        fromTestNumber > _fitTests.length ||
        toTestNumber > _fitTests.length ||
        fromTestNumber >= toTestNumber) {
      return null;
    }

    final FitTest fromTest = _fitTests[fromTestNumber - 1];
    final FitTest toTest = _fitTests[toTestNumber - 1];

    final int? fromValue = _getExerciseValue(fromTest, exerciseName);
    final int? toValue = _getExerciseValue(toTest, exerciseName);

    if (fromValue == null || toValue == null) return null;

    return _calculateImprovement(fromValue, toValue);
  }

  /// Clears any previous error state.
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  // Private Methods

  /// Loads all fit tests from database and renumbers them chronologically.
  Future<void> _loadAndRenumberFitTests() async {
    final List<FitTest> testsFromDb = await _databaseService.getAllFitTests();

    // Renumber tests based on chronological order
    final List<FitTest> renumberedTests = <FitTest>[];
    for (int i = 0; i < testsFromDb.length; i++) {
      renumberedTests.add(
        FitTest(
          id: testsFromDb[i].id,
          testDate: testsFromDb[i].testDate,
          testNumber: i + 1, // Assign sequential number based on date order
          switchKicks: testsFromDb[i].switchKicks,
          powerJacks: testsFromDb[i].powerJacks,
          powerKnees: testsFromDb[i].powerKnees,
          powerJumps: testsFromDb[i].powerJumps,
          globeJumps: testsFromDb[i].globeJumps,
          suicideJumps: testsFromDb[i].suicideJumps,
          pushupJacks: testsFromDb[i].pushupJacks,
          lowPlankOblique: testsFromDb[i].lowPlankOblique,
          notes: testsFromDb[i].notes,
        ),
      );
    }

    _fitTests = renumberedTests;
  }

  /// Wrapper for database operations that handles loading state and error handling.
  Future<void> _performDatabaseOperation(
    Future<void> Function() operation,
  ) async {
    _setLoadingState(true);
    _lastError = null;

    try {
      await operation();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('FitTestProvider error: $e');

      // Ensure we have a valid state even on error
      if (_fitTests.isEmpty) {
        _fitTests = [];
      }

      rethrow; // Re-throw so caller can handle if needed
    } finally {
      _setLoadingState(false);
    }
  }

  /// Sets the loading state and notifies listeners if changed.
  void _setLoadingState(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Calculates percentage improvement between two values.
  ///
  /// Handles edge cases like division by zero and negative improvements.
  double _calculateImprovement(int oldValue, int newValue) {
    if (oldValue == 0) {
      return newValue > 0 ? 100.0 : 0.0; // Improvement from 0 is 100% or 0%
    }
    return ((newValue - oldValue) / oldValue) * 100.0;
  }

  /// Gets the value for a specific exercise from a fit test.
  int? _getExerciseValue(FitTest test, String exerciseName) {
    switch (exerciseName.toLowerCase()) {
      case 'switchkicks':
      case 'switch_kicks':
        return test.switchKicks;
      case 'powerjacks':
      case 'power_jacks':
        return test.powerJacks;
      case 'powerknees':
      case 'power_knees':
        return test.powerKnees;
      case 'powerjumps':
      case 'power_jumps':
        return test.powerJumps;
      case 'globejumps':
      case 'globe_jumps':
        return test.globeJumps;
      case 'suicidejumps':
      case 'suicide_jumps':
        return test.suicideJumps;
      case 'pushupjacks':
      case 'pushup_jacks':
        return test.pushupJacks;
      case 'lowplankoblique':
      case 'low_plank_oblique':
        return test.lowPlankOblique;
      default:
        return null;
    }
  }
}
