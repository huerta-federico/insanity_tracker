import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/fit_test_provider.dart';
import '../providers/utils_provider.dart';
import '../models/fit_test.dart';
import 'dart:async';

final UtilsProvider _utils = UtilsProvider();

class FitTestScreen extends StatefulWidget {
  const FitTestScreen({super.key});

  @override
  State<FitTestScreen> createState() => _FitTestScreenState();
}

class _FitTestScreenState extends State<FitTestScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;
  late final TextEditingController _notesController;

  final int _currentExerciseIndex = 0;

  // Form state
  DateTime _selectedTestDate = DateTime.now();
  bool _isSaving = false;

  static const List<String> _exerciseNames = [
    'Switch Kicks',
    'Power Jacks',
    'Power Knees',
    'Power Jumps',
    'Globe Jumps',
    'Suicide Jumps',
    'Pushup Jacks',
    'Low Plank Oblique',
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(8, (_) => TextEditingController());
    _notesController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fit Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _navigateToHistory,
            tooltip: 'View Previous Results',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: _ExerciseForm(
                  selectedDate: _selectedTestDate,
                  onDateChanged: _updateSelectedDate,
                  controllers: _controllers,
                  exerciseNames: _exerciseNames,
                  currentExerciseIndex: _currentExerciseIndex,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: _NotesSection(controller: _notesController),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: _ActionButtons(
                  isSaving: _isSaving,
                  onClear: _showClearDialog,
                  onSave: _saveFitTest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSelectedDate(DateTime date) {
    if (mounted) {
      setState(() => _selectedTestDate = date);
    }
  }

  void _showClearDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Form'),
        content: const Text('Are you sure you want to clear all entered data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _performClear();
              Navigator.pop(dialogContext);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _performClear() {
    if (!mounted) return;

    _formKey.currentState?.reset();
    for (final controller in _controllers) {
      controller.clear();
    }
    _notesController.clear();

    setState(() {
      _selectedTestDate = DateTime.now();
    });
  }

  Future<void> _saveFitTest() async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final provider = Provider.of<FitTestProvider>(context, listen: false);
      final fitTest = FitTest(
        testDate: _selectedTestDate.toIso8601String().split('T')[0],
        testNumber: provider.getNextTestNumber(),
        switchKicks: int.tryParse(_controllers[0].text) ?? 0,
        powerJacks: int.tryParse(_controllers[1].text) ?? 0,
        powerKnees: int.tryParse(_controllers[2].text) ?? 0,
        powerJumps: int.tryParse(_controllers[3].text) ?? 0,
        globeJumps: int.tryParse(_controllers[4].text) ?? 0,
        suicideJumps: int.tryParse(_controllers[5].text) ?? 0,
        pushupJacks: int.tryParse(_controllers[6].text) ?? 0,
        lowPlankOblique: int.tryParse(_controllers[7].text) ?? 0,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      await provider.saveFitTest(fitTest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fit test saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _performClear();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving fit test: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FitTestHistoryScreen()),
    );
  }
}

class _ExerciseForm extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final List<TextEditingController> controllers;
  final List<String> exerciseNames;
  final int currentExerciseIndex;

  const _ExerciseForm({
    required this.selectedDate,
    required this.onDateChanged,
    required this.controllers,
    required this.exerciseNames,
    required this.currentExerciseIndex,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: () => _pickDate(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      'Test Date: ${_utils.formatDate(selectedDate.toIso8601String())}',
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.calendar_today, color: Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...exerciseNames.asMap().entries.map((entry) {
              final index = entry.key;
              final exerciseName = entry.value;
              final isHighlighted = currentExerciseIndex == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _ExerciseInput(
                  exerciseName: exerciseName,
                  controller: controllers[index],
                  isHighlighted: isHighlighted,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ExerciseInput extends StatelessWidget {
  final String exerciseName;
  final TextEditingController controller;
  final bool isHighlighted;

  const _ExerciseInput({
    required this.exerciseName,
    required this.controller,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _NotesSection extends StatelessWidget {
  final TextEditingController controller;

  const _NotesSection({required this.controller});

  @override
  Widget build(BuildContext context) {
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
              controller: controller,
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
}

class _ActionButtons extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onClear;
  final VoidCallback onSave;

  const _ActionButtons({
    required this.isSaving,
    required this.onClear,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isSaving ? null : onClear,
            icon: const Icon(Icons.clear),
            label: const Text('Clear Form'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(isSaving ? 'Saving...' : 'Save Fit Test'),
          ),
        ),
      ],
    );
  }
}

class FitTestHistoryScreen extends StatelessWidget {
  const FitTestHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fit Test History')),
      body: Consumer<FitTestProvider>(
        builder: (context, fitTestProvider, _) {
          final fitTests = fitTestProvider.getAllResults();

          if (fitTests.isEmpty) {
            return const _EmptyHistoryView();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: fitTests.length,
            itemBuilder: (context, index) {
              final fitTest = fitTests[index];
              final isLatest = index == fitTests.length - 1;

              return _FitTestHistoryItem(
                fitTest: fitTest,
                isLatest: isLatest,
                onTap: () => _showFitTestDetails(context, fitTest),
              );
            },
          );
        },
      ),
    );
  }

  void _showFitTestDetails(BuildContext context, FitTest fitTest) {
    showDialog(
      context: context,
      builder: (dialogContext) => _FitTestDetailsDialog(
        fitTest: fitTest,
        onDelete: () => _handleDelete(context, dialogContext, fitTest),
      ),
    );
  }

  Future<void> _handleDelete(
    BuildContext context,
    BuildContext dialogContext,
    FitTest fitTest,
  ) async {
    if (fitTest.id == null) {
      Navigator.pop(dialogContext);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Test ID missing.')),
        );
      }
      return;
    }

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (confirmContext) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Delete Test #${fitTest.testNumber} from ${_utils.formatDate(fitTest.testDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        final provider = Provider.of<FitTestProvider>(context, listen: false);
        await provider.deleteFitTest(fitTest.id!);

        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Fit test deleted.')));
        }
      } catch (e) {
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
        }
      }
    }
  }
}

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No fit tests recorded yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Complete your first fit test to see results here'),
        ],
      ),
    );
  }
}

class _FitTestHistoryItem extends StatelessWidget {
  final FitTest fitTest;
  final bool isLatest;
  final VoidCallback onTap;

  const _FitTestHistoryItem({
    required this.fitTest,
    required this.isLatest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: isLatest ? Colors.red.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLatest ? Colors.red : Colors.grey,
          child: Text(
            '${fitTest.testNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text('Fit Test #${fitTest.testNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_utils.formatDate(fitTest.testDate)),
            Text('Total Reps: ${fitTest.totalReps}'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _FitTestDetailsDialog extends StatelessWidget {
  final FitTest fitTest;
  final VoidCallback onDelete;

  const _FitTestDetailsDialog({required this.fitTest, required this.onDelete});

  static const List<String> _exerciseNames = [
    'Switch Kicks',
    'Power Jacks',
    'Power Knees',
    'Power Jumps',
    'Globe Jumps',
    'Suicide Jumps',
    'Pushup Jacks',
    'Low Plank Oblique',
  ];

  @override
  Widget build(BuildContext context) {
    final exerciseValues = [
      fitTest.switchKicks,
      fitTest.powerJacks,
      fitTest.powerKnees,
      fitTest.powerJumps,
      fitTest.globeJumps,
      fitTest.suicideJumps,
      fitTest.pushupJacks,
      fitTest.lowPlankOblique,
    ];

    return AlertDialog(
      title: Text('Fit Test #${fitTest.testNumber}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${_utils.formatDate(fitTest.testDate)}'),
            const SizedBox(height: 16),
            ..._exerciseNames.asMap().entries.map((entry) {
              final index = entry.key;
              final exerciseName = entry.value;
              final reps = exerciseValues[index];

              return _ExerciseResult(exerciseName: exerciseName, reps: reps);
            }),
            const Divider(),
            Text(
              'Total: ${fitTest.totalReps} reps',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (fitTest.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text(
                'Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(fitTest.notes!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: onDelete,
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

class _ExerciseResult extends StatelessWidget {
  final String exerciseName;
  final int reps;

  const _ExerciseResult({required this.exerciseName, required this.reps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(exerciseName),
          Text(
            '$reps reps',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
