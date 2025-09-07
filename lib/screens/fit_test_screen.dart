import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/fit_test_provider.dart';
import '../providers/utils_provider.dart';
import '../models/fit_test.dart';
import 'dart:async';

UtilsProvider utils = UtilsProvider();
/// Fit Test screen for inputting and tracking Insanity fit test results
class FitTestScreen extends StatefulWidget {
  const FitTestScreen({super.key});

  @override
  State<FitTestScreen> createState() => _FitTestScreenState();
}

class _FitTestScreenState extends State<FitTestScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for the 8 exercise inputs
  final _switchKicksController = TextEditingController();
  final _powerJacksController = TextEditingController();
  final _powerKneesController = TextEditingController();
  final _powerJumpsController = TextEditingController();
  final _globeJumpsController = TextEditingController();
  final _suicideJumpsController = TextEditingController();
  final _pushupJacksController = TextEditingController();
  final _lowPlankObliqueController = TextEditingController();
  final _notesController = TextEditingController();

  // Timer functionality
  Timer? _timer;
  int _timeRemaining = 60; // 1 minute for each exercise
  bool _isTimerRunning = false;
  int _currentExerciseIndex = 0;

  // Exercise names for timer display
  final List<String> _exerciseNames = [
    'Switch Kicks',
    'Power Jacks',
    'Power Knees',
    'Power Jumps',
    'Globe Jumps',
    'Suicide Jumps',
    'Pushup Jacks',
    'Low Plank Oblique',
  ];

  // Controllers list for easy access
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
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fit Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showPreviousResults,
            tooltip: 'View Previous Results',
          ),
        ],
      ),
      body: Consumer<FitTestProvider>(
        builder: (context, fitTestProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructions card
                  //_buildInstructionsCard(),

                  //const SizedBox(height: 16),

                  // Timer card
                  //_buildTimerCard(),

                  //const SizedBox(height: 16),

                  // Exercise input form
                  _buildExerciseForm(),

                  const SizedBox(height: 16),

                  // Notes section
                  _buildNotesSection(),

                  const SizedBox(height: 24),

                  // Action buttons
                  _buildActionButtons(fitTestProvider),

                  const SizedBox(height: 16),

                  // Previous results preview
                  //_buildPreviousResultsPreview(fitTestProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Instructions card explaining the fit test
  Widget _buildInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fit Test Instructions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Perform each exercise for 1 minute and record the number of reps completed. Rest 1 minute between exercises.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                const Text('Use the timer below to track each exercise'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Timer card with countdown functionality
  Widget _buildTimerCard() {
    return Card(
      color: _isTimerRunning ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              _currentExerciseIndex < _exerciseNames.length
                  ? _exerciseNames[_currentExerciseIndex]
                  : 'Complete!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_timeRemaining ~/ 60).toString().padLeft(2, '0')}:${(_timeRemaining % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: _timeRemaining <= 10 ? Colors.red : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isTimerRunning ? _pauseTimer : _startTimer,
                  icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(_isTimerRunning ? 'Pause' : 'Start'),
                ),
                OutlinedButton.icon(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
                if (_currentExerciseIndex < _exerciseNames.length - 1)
                  OutlinedButton.icon(
                    onPressed: _nextExercise,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Next'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DateTime _selectedTestDate = DateTime.now();

  /// Exercise input form with all 8 exercises
  Widget _buildExerciseForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Record Your Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            InkWell(
              onTap: _pickTestDate, // Extracted date picking logic to a method
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      'Test Date: ${utils.formatDate(_selectedTestDate.toIso8601String())}',
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.red,
                    ), // Or your theme's primary color
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Create input fields for each exercise
            ..._exerciseNames.asMap().entries.map((entry) {
              int index = entry.key;
              String exerciseName = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildExerciseInput(
                  exerciseName,
                  _controllers[index],
                  isHighlighted:
                      _currentExerciseIndex == index && _isTimerRunning,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _pickTestDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedTestDate,
      firstDate: DateTime(2000), // Or an appropriate earlier date
      lastDate: DateTime.now(), // Prevent future dates for past entries
    );
    if (picked != null && picked != _selectedTestDate) {
      setState(() {
        _selectedTestDate = picked;
      });
    }
  }

  /// Individual exercise input field
  Widget _buildExerciseInput(
    String exerciseName,
    TextEditingController controller, {
    bool isHighlighted = false,
  }) {
    return Container(
      decoration: isHighlighted
          ? BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: TextFormField(
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
      ),
    );
  }

  /// Notes section for additional comments
  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'How did you feel? Any observations?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Action buttons for saving the fit test
  Widget _buildActionButtons(FitTestProvider fitTestProvider) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _clearForm,
            icon: const Icon(Icons.clear),
            label: const Text('Clear Form'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSaving
                ? null
                : () => _saveFitTest(fitTestProvider), // Disable if saving
            icon: _isSaving
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save Fit Test'),
          ),
        ),
      ],
    );
  }

  /// Preview of previous fit test results
  Widget _buildPreviousResultsPreview(FitTestProvider fitTestProvider) {
    final latestTest = fitTestProvider.getLatestFitTest();

    if (latestTest == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.fitness_center, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'No previous fit tests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Text('This will be your first fit test!'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Previous Result',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _showPreviousResults,
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Test #${latestTest.testNumber} • ${utils.formatDate(latestTest.testDate)}',
            ),
            const SizedBox(height: 8),
            Text('Total Reps: ${latestTest.totalReps}'),
          ],
        ),
      ),
    );
  }

  // Timer functionality methods
  void _startTimer() {
    setState(() {
      _isTimerRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
        } else {
          _pauseTimer();
          _showTimeUpDialog();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _timeRemaining = 60;
    });
  }

  void _nextExercise() {
    _resetTimer();
    setState(() {
      if (_currentExerciseIndex < _exerciseNames.length - 1) {
        _currentExerciseIndex++;
      }
    });
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Time\'s Up!'),
        content: Text(
          '${_exerciseNames[_currentExerciseIndex]} complete!\n\nRest for 1 minute before the next exercise.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_currentExerciseIndex < _exerciseNames.length - 1) {
                _nextExercise();
              }
            },
            child: Text(
              _currentExerciseIndex < _exerciseNames.length - 1
                  ? 'Next Exercise'
                  : 'Finish',
            ),
          ),
        ],
      ),
    );
  }

  // Form handling methods
  void _clearForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Form'),
        content: const Text('Are you sure you want to clear all entered data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              for (var controller in _controllers) {
                controller.clear();
              }
              _notesController.clear();
              _resetTimer();
              setState(() {
                _currentExerciseIndex = 0;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  bool _isSaving = false;

  void _saveFitTest(FitTestProvider fitTestProvider) {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() {
      // Update UI
      _isSaving = true;
    });

    // Disable button to prevent multiple saves while processing
    // You might want to add a _isSaving state variable for this
    // setState(() { _isSaving = true; });

    final fitTest = FitTest(
      testDate: _selectedTestDate.toIso8601String().split(
        'T',
      )[0], // Assuming you added _selectedTestDate
      testNumber: fitTestProvider.getNextTestNumber(),
      switchKicks:
          int.tryParse(_switchKicksController.text) ??
          0, // Use tryParse for safety
      powerJacks: int.tryParse(_powerJacksController.text) ?? 0,
      powerKnees: int.tryParse(_powerKneesController.text) ?? 0,
      powerJumps: int.tryParse(_powerJumpsController.text) ?? 0,
      globeJumps: int.tryParse(_globeJumpsController.text) ?? 0,
      suicideJumps: int.tryParse(_suicideJumpsController.text) ?? 0,
      pushupJacks: int.tryParse(_pushupJacksController.text) ?? 0,
      lowPlankOblique: int.tryParse(_lowPlankObliqueController.text) ?? 0,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    fitTestProvider
        .saveFitTest(fitTest)
        .then((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fit test saved successfully!'),
              backgroundColor: Colors.green, // Optional: for positive feedback
            ),
          );
          _performAutomaticClear(); // New method to clear without dialog

          // Option: Navigate to the history screen or the details of the saved test
          // For example, to navigate to the history screen:
          // Navigator.pop(context); // If FitTestScreen was pushed
          // Navigator.pushReplacement( // Or replace if you don't want to go back to empty form
          //   context,
          //   MaterialPageRoute(builder: (context) => const FitTestHistoryScreen()),
          // );

          // If you want to navigate to the details of *this specific* saved test,
          // your saveFitTest method in the provider might need to return the saved FitTest object (or its ID)
          // Then you could use that to navigate to a detail view.
        })
        .catchError((error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving fit test: $error'),
              backgroundColor: Colors.red, // Optional: for error feedback
            ),
          );
        })
        .whenComplete(() {
          // Re-enable button if you disabled it
          // setState(() { _isSaving = false; });
          setState(() {
            // Update UI
            _isSaving = false;
          });
        });
  }

  // New method to clear the form without confirmation
  void _performAutomaticClear() {
    _formKey.currentState?.reset(); // Resets validation state too
    for (var controller in _controllers) {
      controller.clear();
    }
    _notesController.clear();
    _resetTimer(); // Assuming this should also happen
    setState(() {
      _currentExerciseIndex = 0;
      _selectedTestDate = DateTime.now(); // Reset selected date to today
    });
  }

  void _showPreviousResults() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FitTestHistoryScreen()),
    );
  }
}

/// Screen showing fit test history and comparisons
// lib/screens/fit_test_screen.dart

// ... (imports and FitTestScreen StatefulWidget/State) ...

/// Screen showing fit test history and comparisons
class FitTestHistoryScreen extends StatelessWidget {
  const FitTestHistoryScreen({super.key});

  // Helper method for building exercise result row
  Widget _buildExerciseResult(String exercise, int reps) {
    // ... (your implementation)
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(exercise),
          Text(
            '$reps reps',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showFitTestDetails(
      BuildContext context, // This is the context from the ListTile's builder
      FitTest fitTest,
      // List<FitTest> allTests, // Not strictly needed for this version
      ) {
    final fitTestProvider = Provider.of<FitTestProvider>(context, listen: false);

    // It's good practice to capture ScaffoldMessengerState if you plan to use it post-await
    // However, for simple SnackBars, checking mounted status of the original context (implicitly)
    // or the dialog's context is often sufficient.

    showDialog(
      context: context, // Use the passed context for showing the dialog
      builder: (BuildContext dialogContext) { // Dialog's own context
        // This is a common pattern: if the Stateful widget hosting the context
        // that launched the dialog is unmounted, then the dialog itself will
        // also be dismissed. The check primarily applies to operations within
        // the original context, or if the dialog might itself have async operations
        // after which 'dialogContext' could be invalid.

        return AlertDialog(
          title: Text('Fit Test #${fitTest.testNumber}'),
          content: SingleChildScrollView(
            // ... (your content Column)
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${utils.formatDate(fitTest.testDate)}'),
                const SizedBox(height: 16),
                _buildExerciseResult('Switch Kicks', fitTest.switchKicks),
                _buildExerciseResult('Power Jacks', fitTest.powerJacks),
                _buildExerciseResult('Power Knees', fitTest.powerKnees),
                _buildExerciseResult('Power Jumps', fitTest.powerJumps),
                _buildExerciseResult('Globe Jumps', fitTest.globeJumps),
                _buildExerciseResult('Suicide Jumps', fitTest.suicideJumps),
                _buildExerciseResult('Pushup Jacks', fitTest.pushupJacks),
                _buildExerciseResult(
                  'Low Plank Oblique',
                  fitTest.lowPlankOblique,
                ),
                const Divider(),
                Text(
                  'Total: ${fitTest.totalReps} reps',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (fitTest.notes != null && fitTest.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(fitTest.notes!),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                if (fitTest.id == null) {
                  // It's generally safe to use dialogContext here before an await
                  // because if this button is pressed, the dialog is still visible.
                  Navigator.pop(dialogContext);
                  // And context (from ListTile) should also still be valid.
                  if (!context.mounted) return; // FIX: Check context before using
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error: Test ID missing.')),
                  );
                  return;
                }

                // Show confirmation dialog
                // The `context` here is the one from the ListTile, it's the one
                // that launched the _showFitTestDetails dialog.
                if (!context.mounted) return; // FIX: Check context before showing another dialog
                bool? confirmDelete = await showDialog<bool>(
                  context: context, // Use the outer context
                  builder: (BuildContext confirmCtx) => AlertDialog(
                    title: const Text('Confirm Delete'),
                    content: Text(
                        'Delete Test #${fitTest.testNumber} from ${utils.formatDate(fitTest.testDate)}?'),
                    actions: <Widget>[
                      TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(confirmCtx, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                // After the await for confirmDelete dialog
                if (confirmDelete == true) {
                  try {
                    // ASYNC GAP for deleting from provider
                    await fitTestProvider.deleteFitTest(fitTest.id!);

                    // FIX: Check if dialogContext is still valid (its widget is mounted)
                    // This is a bit tricky because dialogContext is for the AlertDialog.
                    // A simpler way is to check the original context. If the original
                    // screen that launched the dialog is gone, the dialog is likely gone too.
                    // However, the most robust way is to pass the mounted check from
                    // the stateful widget that owns the original context if possible,
                    // or rely on Navigator.pop not throwing if context is bad (it usually doesn't crash).

                    // More direct check for the dialog:
                    // Check if the current route associated with dialogContext is still active.
                    // This is less common. Usually, we check the 'mounted' status of the
                    // widget that *owns* the context that launched the dialog.

                    // Attempt to pop the details dialog.
                    // If dialogContext's widget is no longer mounted, this might not find it,
                    // but usually, it won't throw a critical error.
                    // A common pattern is to just call pop and if it was already popped by
                    // the parent screen disappearing, it's a no-op.
                    if (dialogContext.mounted) { // Check if the dialog's context is still mounted
                      Navigator.pop(dialogContext);
                    }


                    // FIX: Check the original context (from ListTile) before showing SnackBar
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fit test deleted.')),
                    );
                  } catch (e) {
                    // Error occurred during deletion.
                    // Try to close the details dialog if it's still open.
                    if (dialogContext.mounted) { // Check if the dialog's context is still mounted
                      Navigator.pop(dialogContext);
                    }

                    // FIX: Check the original context before showing error SnackBar
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (your build method for FitTestHistoryScreen)
    // Example call to _showFitTestDetails from the ListTile:
    // onTap: () => _showFitTestDetails(context, fitTest),
    return Scaffold(
      appBar: AppBar(title: const Text('Fit Test History')),
      body: Consumer<FitTestProvider>(
        builder: (context, fitTestProvider, child) {
          final fitTests = fitTestProvider.getAllResults();

          if (fitTests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No fit tests recorded yet'),
                  Text('Complete your first fit test to see results here'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: fitTests.length,
            itemBuilder: (BuildContext listTileContext, int index) { // Using a specific name for clarity
              final fitTest = fitTests[index];
              final isLatest = index == fitTests.length - 1;

              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                color: isLatest ? Colors.red.shade50 : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLatest ? Colors.red : Colors.grey,
                    child: Text(
                      '${fitTest.testNumber}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text('Fit Test #${fitTest.testNumber}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(utils.formatDate(fitTest.testDate)),
                      Text('Total Reps: ${fitTest.totalReps}'),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showFitTestDetails(listTileContext, fitTest), // Pass the listTileContext
                ),
              );
            },
          );
        },
      ),
    );
  }
}

