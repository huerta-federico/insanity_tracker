// lib/providers/fit_test_provider.dart
import 'package:flutter/foundation.dart';
import '../models/fit_test.dart';
import '../services/database_service.dart';

class FitTestProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  List<FitTest> _fitTests = [];
  bool _isLoading = false;

  List<FitTest> get fitTests =>
      List.unmodifiable(_fitTests); // Return unmodifiable list
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadAndRenumberFitTests();
    } catch (e) {
      debugPrint('Error initializing FitTestProvider: $e');
      _fitTests = []; // Ensure list is empty on error
    }
    _isLoading = false;
    notifyListeners();
  }

  // Renamed and updated to also handle renumbering
  Future<void> _loadAndRenumberFitTests() async {
    List<FitTest> testsFromDb = await _databaseService.getAllFitTests();
    // Database query now orders by test_date ASC

    // Renumber tests based on their chronological order
    List<FitTest> renumberedTests = [];
    for (int i = 0; i < testsFromDb.length; i++) {
      // Create a new FitTest instance with the correct testNumber.
      // This is important if FitTest objects are treated as immutable
      // or if the instance from DB needs its testNumber property updated
      // for the provider's state.
      renumberedTests.add(
        FitTest(
          id: testsFromDb[i].id,
          testDate: testsFromDb[i].testDate,
          testNumber: i + 1, // Assign new number based on sorted order
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
    // No need to call notifyListeners() here if called by the public methods like initialize, save, delete.
  }

  Future<void> saveFitTest(FitTest fitTest) async {
    // The fitTest.testNumber passed here is just an initial guess.
    // The database will store it, but _loadAndRenumberFitTests will correct it for the provider's state.
    try {
      // Create a map that includes the provisional test number
      Map<String, dynamic> fitTestMap = fitTest.toMap();
      if (!fitTestMap.containsKey('test_number') ||
          fitTestMap['test_number'] == null) {
        // If testNumber wasn't explicitly set (e.g. new test), use provisional.
        // The database itself has NOT NULL on test_number
        fitTestMap['test_number'] = getNextTestNumber();
      }

      // Use a FitTest object that includes this provisional test number for insertion
      FitTest testToInsert = FitTest.fromMap(fitTestMap);
      await _databaseService.insertFitTest(testToInsert);
      await _loadAndRenumberFitTests(); // Reload and renumber all tests
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving fit test: $e');
      // Optionally, re-throw or handle more gracefully
    }
  }

  // New method to delete a fit test
  Future<void> deleteFitTest(int id) async {
    try {
      await _databaseService.deleteFitTest(id);
      await _loadAndRenumberFitTests(); // Reload and renumber after deletion
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting fit test: $e');
      // Optionally, re-throw or handle more gracefully
    }
  }

  FitTest? getLatestFitTest() {
    if (_fitTests.isEmpty) return null;
    // _fitTests is already sorted by date due to _loadAndRenumberFitTests
    return _fitTests.last;
  }

  List<FitTest> getAllResults() {
    // _fitTests is already sorted and correctly numbered
    return _fitTests;
  }

  // This method now gives the next number if a new test were added *now*
  // The actual stored number will be based on its date relative to others.
  int getNextTestNumber() {
    // After loading and renumbering, this will be correct for a new entry
    return _fitTests.length + 1;
  }

  // Keep other methods like isNextTestDue, getImprovementPercentages
  // They should work correctly as they use the _fitTests list which is now
  // always sorted and correctly numbered.

  // Check if it's time for next fit test (every 2 weeks)
  bool isNextTestDue(DateTime programStartDate) {
    if (_fitTests.isEmpty) {
      int daysSinceStart = DateTime.now().difference(programStartDate).inDays;
      return daysSinceStart >= 0;
    }
    FitTest? lastTest = getLatestFitTest();
    if (lastTest == null) {
      return true; // Should not happen if _fitTests is not empty
    }

    DateTime lastTestDate = DateTime.parse(lastTest.testDate);
    int daysSinceLastTest = DateTime.now().difference(lastTestDate).inDays;
    return daysSinceLastTest >= 14;
  }

  Map<String, double> getImprovementPercentages() {
    if (_fitTests.length < 2) return {};
    // Assumes _fitTests is sorted by date, so first is earliest, last is latest.
    FitTest first = _fitTests.first;
    FitTest latest = _fitTests.last;
    return {
      'switchKicks': _calculateImprovement(
        first.switchKicks,
        latest.switchKicks,
      ),
      'powerJacks': _calculateImprovement(first.powerJacks, latest.powerJacks),
      'powerKnees': _calculateImprovement(first.powerKnees, latest.powerKnees),
      'powerJumps': _calculateImprovement(first.powerJumps, latest.powerJumps),
      'globeJumps': _calculateImprovement(first.globeJumps, latest.globeJumps),
      'suicideJumps': _calculateImprovement(
        first.suicideJumps,
        latest.suicideJumps,
      ),
      'pushupJacks': _calculateImprovement(
        first.pushupJacks,
        latest.pushupJacks,
      ),
      'lowPlankOblique': _calculateImprovement(
        first.lowPlankOblique,
        latest.lowPlankOblique,
      ),
    };
  }

  double _calculateImprovement(int oldValue, int newValue) {
    if (oldValue == 0) {
      return newValue > 0
          ? 100.0
          : 0.0; // Avoid division by zero, handle improvement from 0
    }
    return ((newValue - oldValue) / oldValue.toDouble()) * 100;
  }
}
