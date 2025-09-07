import 'package:flutter/material.dart';
import '../providers/workout_provider.dart';
import '../providers/utils_provider.dart';

/// A provider that handles the program start date selection workflow.
///
/// This provider manages the UI flow for selecting a program start date,
/// including date picker presentation, validation, confirmation dialogs,
/// and user feedback.
class StartDateProvider extends ChangeNotifier {
  /// Presents a date picker for selecting the program start date.
  ///
  /// This method handles the complete workflow:
  /// 1. Shows a date picker constrained to Mondays only
  /// 2. If a date is selected, shows a confirmation dialog
  /// 3. Updates the workout provider and shows appropriate feedback
  ///
  /// Parameters:
  /// - [context]: The build context for showing dialogs
  /// - [workoutProvider]: The workout provider to update
  ///
  /// Returns a Future that completes when the operation is finished.
  Future<void> pickProgramStartDate(
      BuildContext context,
      WorkoutProvider workoutProvider,
      ) async {
    final DateTime? picked = await _showStartDatePicker(context, workoutProvider);

    if (!context.mounted || picked == null) return;

    // Only proceed if the selected date is different from current
    if (picked == workoutProvider.programStartDate) return;

    final bool shouldProceed = await _showConfirmationDialog(context, picked);

    if (!context.mounted || !shouldProceed) return;

    await _updateStartDate(context, workoutProvider, picked);
  }

  /// Shows the date picker dialog with appropriate constraints.
  Future<DateTime?> _showStartDatePicker(
      BuildContext context,
      WorkoutProvider workoutProvider,
      ) async {
    final DateTime? currentStartDate = workoutProvider.programStartDate;
    final DateTime now = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: currentStartDate ?? _getDefaultStartDate(now),
      firstDate: DateTime(2010),
      lastDate: UtilsProvider.getNearestMonday(now, allowFuture: false),
      helpText: 'Select Program Start Date (Monday)',
      selectableDayPredicate: _isMondaySelectable,
      builder: _buildDatePickerTheme,
    );
  }

  /// Gets the default start date (previous Monday from a week ago).
  DateTime _getDefaultStartDate(DateTime now) {
    return UtilsProvider.getNearestMonday(
      now.subtract(const Duration(days: 7)),
      allowFuture: false,
    );
  }

  /// Determines if a day is selectable (Mondays only).
  bool _isMondaySelectable(DateTime day) {
    return day.weekday == DateTime.monday;
  }

  /// Builds the themed date picker widget.
  Widget _buildDatePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(
          primary: Colors.red,
          onPrimary: Colors.white,
          onSurface: Colors.black,
          surface: Colors.white,
        ),
      ),
      child: child!,
    );
  }

  /// Shows a confirmation dialog warning about data loss.
  Future<bool> _showConfirmationDialog(BuildContext context, DateTime picked) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _buildConfirmationDialog(
        dialogContext,
        picked,
      ),
    );

    return result ?? false;
  }

  /// Builds the confirmation dialog widget.
  Widget _buildConfirmationDialog(BuildContext dialogContext, DateTime picked) {
    return AlertDialog(
      title: const Text('Confirm Start Date Change'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New start date: ${UtilsProvider.formatDateForDisplay(picked)}'),
          const SizedBox(height: 12),
          const Text(
            'Warning: This will permanently delete all previously logged '
                'workout sessions and reset your current progress.',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text('Are you sure you want to continue?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
          child: const Text('Change and Reset'),
        ),
      ],
    );
  }

  /// Updates the start date and handles success/error feedback.
  Future<void> _updateStartDate(
      BuildContext context,
      WorkoutProvider workoutProvider,
      DateTime picked,
      ) async {
    try {
      await workoutProvider.setProgramStartDate(
        picked,
        autoPopulatePastWorkouts: true,
      );

      if (!context.mounted) return;

      _showSuccessMessage(context, picked);
    } catch (error) {
      if (!context.mounted) return;

      _showErrorMessage(context, error.toString());
    }
  }

  /// Shows a success message when the start date is updated.
  void _showSuccessMessage(BuildContext context, DateTime picked) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Program start date set to ${UtilsProvider.formatDateForDisplay(picked)}. '
              'Past workouts reset and auto-completed.',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows an error message when the start date update fails.
  void _showErrorMessage(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to set start date: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }
}