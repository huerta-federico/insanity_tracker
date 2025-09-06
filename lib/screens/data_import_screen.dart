import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/workout.dart';
import '../providers/fit_test_provider.dart';
import '../providers/workout_provider.dart';
import '../models/fit_test.dart';
import '../models/workout_session.dart';

/// Screen for importing historical fit test data and workout completions
class DataImportScreen extends StatefulWidget {
  const DataImportScreen({super.key});

  @override
  State<DataImportScreen> createState() => _DataImportScreenState();
}

class _DataImportScreenState extends State<DataImportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Historical Data'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Fit Tests'),
            Tab(text: 'Workouts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [FitTestImportTab(), WorkoutImportTab()],
      ),
    );
  }
}

/// Tab for importing historical fit test results
class FitTestImportTab extends StatefulWidget {
  const FitTestImportTab({super.key});

  @override
  State<FitTestImportTab> createState() => _FitTestImportTabState();
}

class _FitTestImportTabState extends State<FitTestImportTab> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _testNumberController = TextEditingController();

  // Exercise controllers
  final _switchKicksController = TextEditingController();
  final _powerJacksController = TextEditingController();
  final _powerKneesController = TextEditingController();
  final _powerJumpsController = TextEditingController();
  final _globeJumpsController = TextEditingController();
  final _suicideJumpsController = TextEditingController();
  final _pushupJacksController = TextEditingController();
  final _lowPlankObliqueController = TextEditingController();
  final _notesController = TextEditingController();

  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = [
      _switchKicksController,
      _powerJacksController,
      _powerKneesController,
      _powerJumpsController,
      _globeJumpsController,
      _suicideJumpsController,
      _pushupJacksController,
      _lowPlankObliqueController,
    ];
  }

  @override
  void dispose() {
    _dateController.dispose();
    _testNumberController.dispose();
    _notesController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Historical Fit Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your previous fit test results with custom dates.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date picker
                    TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'Test Date',
                        hintText: 'YYYY-MM-DD',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter test date';
                        }
                        try {
                          DateTime.parse(value);
                        } catch (e) {
                          return 'Please enter valid date (YYYY-MM-DD)';
                        }
                        return null;
                      },
                      onTap: () => _selectDate(),
                    ),

                    const SizedBox(height: 12),

                    // Test number
                    TextFormField(
                      controller: _testNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Test Number',
                        hintText: 'e.g., 1, 2, 3...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter test number';
                        }
                        final number = int.tryParse(value);
                        if (number == null || number < 1) {
                          return 'Please enter valid test number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Exercise results
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exercise Results',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildExerciseInput('Switch Kicks', _switchKicksController),
                    const SizedBox(height: 8),
                    _buildExerciseInput('Power Jacks', _powerJacksController),
                    const SizedBox(height: 8),
                    _buildExerciseInput('Power Knees', _powerKneesController),
                    const SizedBox(height: 8),
                    _buildExerciseInput('Power Jumps', _powerJumpsController),
                    const SizedBox(height: 8),
                    _buildExerciseInput('Globe Jumps', _globeJumpsController),
                    const SizedBox(height: 8),
                    _buildExerciseInput(
                      'Suicide Jumps',
                      _suicideJumpsController,
                    ),
                    const SizedBox(height: 8),
                    _buildExerciseInput('Pushup Jacks', _pushupJacksController),
                    const SizedBox(height: 8),
                    _buildExerciseInput(
                      'Low Plank Oblique',
                      _lowPlankObliqueController,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Notes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Any notes about this test...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearForm,
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _importFitTest,
                    child: const Text('Import Fit Test'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseInput(
    String exerciseName,
    TextEditingController controller,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: exerciseName,
        hintText: 'Number of reps',
        suffixText: 'reps',
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter number of reps';
        }
        final number = int.tryParse(value);
        if (number == null || number < 0) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (!mounted || picked == null) {
      return; // Check mounted and if picked is null
    }
    _dateController.text = picked.toIso8601String().split('T')[0];
  }

  void _clearForm() {
    _dateController.clear();
    _testNumberController.clear();
    _notesController.clear();
    for (var controller in _controllers) {
      controller.clear();
    }
  }

  void _importFitTest() async {
    // Make it async if it wasn't already for provider call
    if (!_formKey.currentState!.validate()) {
      // It's generally safe to use context directly here for ScaffoldMessenger
      // if the action is immediate and doesn't follow an await from this function scope
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final fitTest = FitTest(
      testDate: _dateController.text,
      testNumber: int.parse(_testNumberController.text),
      switchKicks: int.parse(_switchKicksController.text),
      powerJacks: int.parse(_powerJacksController.text),
      powerKnees: int.parse(_powerKneesController.text),
      powerJumps: int.parse(_powerJumpsController.text),
      globeJumps: int.parse(_globeJumpsController.text),
      suicideJumps: int.parse(_suicideJumpsController.text),
      pushupJacks: int.parse(_pushupJacksController.text),
      lowPlankOblique: int.parse(_lowPlankObliqueController.text),
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    try {
      await context.read<FitTestProvider>().saveFitTest(fitTest); // await here

      if (!mounted) return; // Check after await
      ScaffoldMessenger.of(context).showSnackBar(
        // Use the original context
        SnackBar(
          content: Text(
            'Fit Test #${fitTest.testNumber} imported successfully!',
          ),
        ),
      );
      _clearForm();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        // Use the original context
        SnackBar(content: Text('Error importing fit test: $error')),
      );
    }
  }
}

/// Tab for importing historical workout completions
class WorkoutImportTab extends StatefulWidget {
  const WorkoutImportTab({super.key});

  @override
  State<WorkoutImportTab> createState() => _WorkoutImportTabState();
}

class _WorkoutImportTabState extends State<WorkoutImportTab> {
  final _formKey = GlobalKey<FormState>();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  // Bulk import options
  // --- START: New state variables ---
  bool _importAllCompleted = true; // Default to importing all as completed
  final _skipDaysController =
      TextEditingController(); // For comma-separated skip days
  final _notesController =
      TextEditingController(); // Already there, ensure it's used
  bool _isImporting = false; // For loading indicator
  // --- END: New state variables ---

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _notesController.dispose();
    _skipDaysController.dispose(); // Don't forget to dispose
    super.dispose();
  }

  // Inside class _WorkoutImportTabState extends State<WorkoutImportTab>

  // --- START: New methods ---
  void _clearWorkoutForm() {
    _formKey.currentState?.reset();
    _startDateController.clear();
    _endDateController.clear();
    _skipDaysController.clear();
    _notesController.clear();
    setState(() {
      _importAllCompleted = true;
    });
  }

  List<int> _parseRelativeDaysInput(String input) {
    if (input.isEmpty) return [];
    return input
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .where((element) => element != null && element > 0)
        .cast<int>()
        .toList();
  }

  Future<void> _processWorkoutImport() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields properly.'),
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    final startDate = DateTime.tryParse(_startDateController.text);
    final endDate = DateTime.tryParse(_endDateController.text);
    final notes = _notesController.text.trim();
    final relativeDaysToModify = _parseRelativeDaysInput(
      _skipDaysController.text,
    );

    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid date format.')));
      setState(() {
        _isImporting = false;
      });
      return;
    }

    if (endDate.isBefore(startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date.')),
      );
      setState(() {
        _isImporting = false;
      });
      return;
    }

    final workoutProvider = context.read<WorkoutProvider>();
    final allScheduledWorkouts = List<Workout>.from(
      workoutProvider.workouts,
    ); // Make a mutable copy
    if (allScheduledWorkouts.isEmpty) {
      await workoutProvider.initialize(); // Try to load them if empty
      if (!mounted) return; // Check
      if (workoutProvider.workouts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout schedule not loaded. Please try again.'),
          ),
        );
        setState(() {
          _isImporting = false;
        });
        return;
      }
      allScheduledWorkouts.addAll(workoutProvider.workouts);
    }
    allScheduledWorkouts.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    List<WorkoutSession> sessionsToCreateOrUpdate = [];
    int programDayNumber = 1; // Assumes import starts from Day 1 of the program
    int dayInCurrentPeriod = 0; // To track the Nth day of the import range

    for (
      DateTime currentDate = startDate;
      currentDate.isBefore(endDate.add(const Duration(days: 1)));
      currentDate = currentDate.add(const Duration(days: 1))
    ) {
      dayInCurrentPeriod++;

      Workout? scheduledWorkout;
      try {
        scheduledWorkout = allScheduledWorkouts.firstWhere(
          (w) => w.dayNumber == programDayNumber,
        );
      } catch (e) {
        // No workout for this programDayNumber (e.g., end of schedule)
        debugPrint(
          "Import notice: No scheduled workout found for program day $programDayNumber on ${currentDate.toIso8601String().split('T')[0]}. Skipping this day.",
        );
        programDayNumber++; // Increment to check next program day for next actual date
        continue; // Skip this date if no corresponding program workout
      }

      // Skip Fit Test days as they are handled separately
      if (scheduledWorkout.workoutType == 'fit_test') {
        programDayNumber++;
        continue;
      }

      bool isCompleted;
      if (_importAllCompleted) {
        // If importing all as completed, check if this day is in the "skip" list
        isCompleted = !relativeDaysToModify.contains(dayInCurrentPeriod);
      } else {
        // If importing all as NOT completed (or skipped), check if this day is in the "complete" list
        isCompleted = relativeDaysToModify.contains(dayInCurrentPeriod);
      }

      // For rest days, always mark as completed if not explicitly skipped by user wanting to skip everything
      if (scheduledWorkout.workoutType == 'rest') {
        isCompleted = _importAllCompleted
            ? !relativeDaysToModify.contains(dayInCurrentPeriod)
            : true;
      }

      sessionsToCreateOrUpdate.add(
        WorkoutSession(
          workoutId: scheduledWorkout.id,
          date: currentDate.toIso8601String().split('T')[0],
          completed: isCompleted,
          notes: notes.isEmpty ? null : notes,
        ),
      );
      programDayNumber++;
    }

    if (sessionsToCreateOrUpdate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No workout sessions to import for the selected range and criteria.',
          ),
        ),
      );
      setState(() {
        _isImporting = false;
      });
      return;
    }

    try {
      await workoutProvider.bulkUpsertWorkoutSessions(sessionsToCreateOrUpdate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${sessionsToCreateOrUpdate.length} workout session(s) processed!',
          ),
        ),
      );
      _clearWorkoutForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing workout sessions: $e')),
      );
    } finally {
      if (mounted) {
        // Check before setState in finally
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
  // --- END: New methods ---

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Historical Workouts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Import your completed workouts for a date range. This will mark all workouts in the period as completed unless you specify skip days.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Date range
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date Range',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Start date
                    TextFormField(
                      controller: _startDateController,
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        hintText: 'YYYY-MM-DD',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter start date';
                        }
                        try {
                          DateTime.parse(value);
                        } catch (e) {
                          return 'Please enter valid date (YYYY-MM-DD)';
                        }
                        return null;
                      },
                      onTap: () => _selectStartDate(),
                    ),

                    const SizedBox(height: 12),

                    // End date
                    TextFormField(
                      controller: _endDateController,
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        hintText: 'YYYY-MM-DD',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter end date';
                        }
                        try {
                          final endDate = DateTime.parse(value);
                          if (_startDateController.text.isNotEmpty) {
                            final startDate = DateTime.parse(
                              _startDateController.text,
                            );
                            if (endDate.isBefore(startDate)) {
                              return 'End date must be after start date';
                            }
                          }
                        } catch (e) {
                          return 'Please enter valid date (YYYY-MM-DD)';
                        }
                        return null;
                      },
                      onTap: () => _selectEndDate(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Import options
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // --- START: Replace this comment with the following ---
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text(
                        'Mark all workouts in range as completed?',
                      ),
                      value: _importAllCompleted,
                      onChanged: (bool? value) {
                        if (value != null) {
                          setState(() {
                            _importAllCompleted = value;
                          });
                        }
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _skipDaysController,
                      decoration: InputDecoration(
                        labelText: _importAllCompleted
                            ? 'Days to mark as SKIPPED (e.g., 2, 5, 10)'
                            : 'Days to mark as COMPLETED (e.g., 1, 3, 6)',
                        hintText: 'Comma-separated day numbers',
                        border: const OutlineInputBorder(),
                        helperText: _importAllCompleted
                            ? 'Enter the Nth day OF THE SELECTED PERIOD to skip.'
                            : 'Enter the Nth day OF THE SELECTED PERIOD to complete.',
                      ),
                      keyboardType: TextInputType.text, // Numbers and commas
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController, // Already exists
                      decoration: const InputDecoration(
                        labelText: 'Notes for imported sessions (Optional)',
                        hintText: 'e.g., Imported retrospectively',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    // --- END: Replacement ---
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // Preview Section
            // --- START: Update this part ---
            if (_startDateController.text.isNotEmpty &&
                _endDateController.text.isNotEmpty)
              _buildPreview(), // Call the revised preview method
            // --- END: Update this part ---
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isImporting ? null : _clearWorkoutForm,
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isImporting ? null : _processWorkoutImport,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                      _isImporting ? 'Importing...' : 'Import Workouts',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Preview
            if (_startDateController.text.isNotEmpty &&
                _endDateController.text.isNotEmpty)
              _buildPreview(),
          ],
        ),
      ),
    );
  }

  // Inside class _WorkoutImportTabState extends State<WorkoutImportTab>

  // Make sure you have this at the top of your file if not already:
  // import 'package:provider/provider.dart';
  // import '../providers/workout_provider.dart'; // Assuming path
  // import '../models/workout.dart'; // Assuming path

  // ... (other methods and build method) ...

  // Inside class _WorkoutImportTabState extends State<WorkoutImportTab>

  // ... (all the methods we've defined earlier, including _processWorkoutImport, _clearWorkoutForm, _parseRelativeDaysInput) ...

  // Method to show DatePicker for Start Date
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDateController.text.isNotEmpty
          ? (DateTime.tryParse(_startDateController.text) ?? DateTime.now())
          : DateTime.now().subtract(
              const Duration(days: 60),
            ), // Sensible default
      firstDate: DateTime(2020), // Or your app's earliest relevant date
      lastDate: DateTime.now(), // Users import past data
    );
    if (!mounted || picked == null) return;
    setState(() {
      _startDateController.text = picked.toIso8601String().split('T')[0];
    });
  }

  // Method to show DatePicker for End Date
  Future<void> _selectEndDate() async {
    final DateTime? initialEndDate = _endDateController.text.isNotEmpty
        ? DateTime.tryParse(_endDateController.text)
        : null;
    final DateTime? initialStartDate = _startDateController.text.isNotEmpty
        ? DateTime.tryParse(_startDateController.text)
        : null;

    DateTime suggestedInitialDate = DateTime.now();
    if (initialEndDate != null) {
      suggestedInitialDate = initialEndDate;
    } else if (initialStartDate != null) {
      suggestedInitialDate = initialStartDate.add(
        const Duration(days: 60),
      ); // Suggest 60 days after start
      if (suggestedInitialDate.isAfter(DateTime.now())) {
        suggestedInitialDate = DateTime.now();
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: suggestedInitialDate,
      firstDate:
          initialStartDate ??
          DateTime(2020), // End date can't be before start date
      lastDate: DateTime.now(),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _endDateController.text = picked.toIso8601String().split('T')[0];
    });
  }

  // THIS IS THE CORRECT _buildPreview method discussed and revised previously.
  // Ensure this is the ONLY _buildPreview method within _WorkoutImportTabState.
  Widget _buildPreview() {
    // Ensure controllers have text and are valid dates before trying to parse
    if (_startDateController.text.isEmpty || _endDateController.text.isEmpty) {
      return const SizedBox.shrink(); // Don't show preview if dates are missing
    }

    final DateTime? startDate = DateTime.tryParse(_startDateController.text);
    final DateTime? endDate = DateTime.tryParse(_endDateController.text);

    // Basic validation for the preview itself
    if (startDate == null || endDate == null || endDate.isBefore(startDate)) {
      return Card(
        color: Colors.yellow[100],
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Preview unavailable: Please enter valid start and end dates, with end date after start date.',
            style: TextStyle(color: Colors.orange),
          ),
        ),
      );
    }

    // Access WorkoutProvider for the schedule
    final workoutProvider = context.read<WorkoutProvider>();
    final allScheduledWorkouts = List<Workout>.from(
      workoutProvider.workouts,
    ); // Make a mutable copy

    if (allScheduledWorkouts.isEmpty) {
      // It's good practice to handle the case where workouts might not be loaded yet
      // although WorkoutProvider's initialize should handle this.
      return Card(
        color: Colors.yellow[100],
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Preview unavailable: Workout schedule not loaded. Please ensure schedule is available.',
            style: TextStyle(color: Colors.orange),
          ),
        ),
      );
    }
    allScheduledWorkouts.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

    // Logic from the _processWorkoutImport to calculate preview numbers
    final totalDaysInPeriod = endDate.difference(startDate).inDays + 1;
    final List<int> relativeDaysToModify = _parseRelativeDaysInput(
      _skipDaysController.text,
    );

    int actualProgramDaysInRange = 0;
    int fitTestsSkipped = 0;
    int restDaysProcessed = 0;
    int actualWorkoutsToProcess = 0; // Actual workout-type days
    int daysMarkedCompleted = 0;
    int daysMarkedNotCompleted = 0;

    int programDayNumber =
        1; // Assuming import starts from Day 1 of the program
    int dayInCurrentPeriod = 0;

    for (
      DateTime currentDate = startDate;
      currentDate.isBefore(endDate.add(const Duration(days: 1)));
      currentDate = currentDate.add(const Duration(days: 1))
    ) {
      dayInCurrentPeriod++;
      actualProgramDaysInRange++;

      Workout? scheduledWorkout;
      try {
        scheduledWorkout = allScheduledWorkouts.firstWhere(
          (w) => w.dayNumber == programDayNumber,
        );
      } catch (e) {
        programDayNumber++;
        actualProgramDaysInRange--; // This day in the period won't map to a program day
        continue;
      }

      if (scheduledWorkout.workoutType == 'fit_test') {
        fitTestsSkipped++;
        programDayNumber++;
        continue;
      }

      bool isCompleted;
      if (_importAllCompleted) {
        isCompleted = !relativeDaysToModify.contains(dayInCurrentPeriod);
      } else {
        isCompleted = relativeDaysToModify.contains(dayInCurrentPeriod);
      }

      if (scheduledWorkout.workoutType == 'rest') {
        isCompleted = _importAllCompleted
            ? !relativeDaysToModify.contains(dayInCurrentPeriod)
            : true;
        restDaysProcessed++;
      } else {
        actualWorkoutsToProcess++;
      }

      if (isCompleted) {
        daysMarkedCompleted++;
      } else {
        daysMarkedNotCompleted++;
      }
      programDayNumber++;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Import Preview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Date Range: ${_startDateController.text} to ${_endDateController.text}',
            ),
            Text('Total Days in Selected Period: $totalDaysInPeriod'),
            const Divider(height: 20),
            Text(
              'Program Days Mapped in Period: ${actualProgramDaysInRange - fitTestsSkipped}',
            ),
            if (fitTestsSkipped > 0)
              Text(
                'Fit Test Days within period (will be skipped by this import): $fitTestsSkipped',
              ),
            Text(
              'Workout/Rest Sessions to Process: ${actualWorkoutsToProcess + restDaysProcessed}',
            ),
            const SizedBox(height: 8),
            Text(
              '  - To be marked COMPLETED: $daysMarkedCompleted',
              style: TextStyle(color: Colors.green[700]),
            ),
            Text(
              '  - To be marked NOT COMPLETED/SKIPPED: $daysMarkedNotCompleted',
              style: TextStyle(color: Colors.red[700]),
            ),
            const SizedBox(height: 8),
            if (_notesController.text.isNotEmpty)
              Text('Notes for sessions: "${_notesController.text}"'),
            if (actualProgramDaysInRange - fitTestsSkipped == 0 &&
                totalDaysInPeriod > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Warning: The selected date range does not seem to map to any processable program workouts or rest days based on a Day 1 start.',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // } // This would be the closing brace for _WorkoutImportTabState class
}
