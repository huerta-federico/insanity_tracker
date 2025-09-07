import 'package:flutter/material.dart';
import '../providers/workout_provider.dart';
import '../providers/utils_provider.dart';

class StartDateProvider extends ChangeNotifier {
  UtilsProvider utils = UtilsProvider();

  Future<void> pickProgramStartDate(
      BuildContext context,
      WorkoutProvider provider,
      ) async {
    final DateTime? currentStartDate = provider.programStartDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentStartDate ??
          utils.getNearestMonday(
            DateTime.now().subtract(const Duration(days: 7)),
          ),
      firstDate: DateTime(2010),
      lastDate: utils.getNearestMonday(DateTime.now(), allowFuture: false),
      helpText: 'Select Program Start Date (Monday)',
      selectableDayPredicate: (DateTime day) {
        return day.weekday == DateTime.monday;
      },
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.red,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ).copyWith(surface: Colors.white),
          ),
          child: child!,
        );
      },
    );

    // Check mounted after await before using context for dialogs/SnackBar
    if (!context.mounted) return;

    if (picked != null && picked != currentStartDate) {
      // --- START: ADD CONFIRMATION DIALOG ---
      final bool? shouldChange = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // User must explicitly choose an action
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Confirm Change Start Date'),
            content: const Text(
              'Changing the program start date will ERASE all previously logged workout sessions and reset your current progress. Are you sure you want to continue?',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: Text('Change and Reset',
                    style: TextStyle(color: Colors.red[700])),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          );
        },
      );
      // --- END: ADD CONFIRMATION DIALOG ---

      if (!context.mounted) return; // Re-check mounted after dialog

      if (shouldChange == true) {
        try {
          // setProgramStartDate in WorkoutProvider will handle deleting old sessions
          await provider.setProgramStartDate(
            picked,
            autoPopulatePastWorkouts: true, // This can remain true
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Program start date set to: ${utils.formatDateForDisplay(
                    picked)}. Past workouts reset and auto-completed.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error setting start date: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
