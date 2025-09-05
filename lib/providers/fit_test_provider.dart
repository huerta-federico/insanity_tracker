import 'package:flutter/foundation.dart';
import '../models/fit_test.dart';
import '../services/database_service.dart';

class FitTestProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService.instance;

  List<FitTest> _fitTests = [];
  bool _isLoading = false;

  // Getters
  List<FitTest> get fitTests => _fitTests;
  bool get isLoading => _isLoading;

  // Initialize - load all fit test data
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadFitTests();
    } catch (e) {
      debugPrint('Error initializing FitTestProvider: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load all fit tests from database
  Future<void> _loadFitTests() async {
    _fitTests = await _databaseService.getAllFitTests();
  }

  // Save a new fit test
  Future<void> saveFitTest(FitTest fitTest) async {
    try {
      await _databaseService.insertFitTest(fitTest);
      await _loadFitTests(); // Reload to get the new data
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving fit test: $e');
    }
  }

  // Get the most recent fit test
  FitTest? getLatestFitTest() {
    if (_fitTests.isEmpty) return null;
    return _fitTests.last; // List is ordered by date ASC, so last is most recent
  }

  // Get all fit test results
  List<FitTest> getAllResults() {
    return _fitTests;
  }

  // Check if it's time for next fit test (every 2 weeks)
  bool isNextTestDue(DateTime programStartDate) {
    if (_fitTests.isEmpty) {
      // If no tests yet, check if it's day 1 or later
      int daysSinceStart = DateTime.now().difference(programStartDate).inDays;
      return daysSinceStart >= 0;
    }

    FitTest? lastTest = getLatestFitTest();
    if (lastTest == null) return true;

    DateTime lastTestDate = DateTime.parse(lastTest.testDate);
    int daysSinceLastTest = DateTime.now().difference(lastTestDate).inDays;

    return daysSinceLastTest >= 14; // Every 2 weeks (14 days)
  }

  // Get improvement percentages between first and latest test
  Map<String, double> getImprovementPercentages() {
    if (_fitTests.length < 2) return {};

    FitTest first = _fitTests.first;
    FitTest latest = _fitTests.last;

    return {
      'switchKicks': _calculateImprovement(first.switchKicks, latest.switchKicks),
      'powerJacks': _calculateImprovement(first.powerJacks, latest.powerJacks),
      'powerKnees': _calculateImprovement(first.powerKnees, latest.powerKnees),
      'powerJumps': _calculateImprovement(first.powerJumps, latest.powerJumps),
      'globeJumps': _calculateImprovement(first.globeJumps, latest.globeJumps),
      'suicideJumps': _calculateImprovement(first.suicideJumps, latest.suicideJumps),
      'pushupJacks': _calculateImprovement(first.pushupJacks, latest.pushupJacks),
      'lowPlankOblique': _calculateImprovement(first.lowPlankOblique, latest.lowPlankOblique),
    };
  }

  // Calculate percentage improvement
  double _calculateImprovement(int oldValue, int newValue) {
    if (oldValue == 0) return 0.0;
    return ((newValue - oldValue) / oldValue) * 100;
  }

  // Get the next test number
  int getNextTestNumber() {
    return _fitTests.length + 1;
  }
}