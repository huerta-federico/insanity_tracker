import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workout_session.dart'; // Ensure this is used or remove
import '../providers/workout_provider.dart';
import '../models/workout.dart';
// import 'package:intl/intl.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  String _formatDateForDisplay(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Helper function to find the nearest Monday (past or present, or future based on flag)
  DateTime _getNearestMonday(DateTime date, {bool allowFuture = true}) {
    if (date.weekday == DateTime.monday) {
      return DateTime(
        date.year,
        date.month,
        date.day,
      ); // Already a Monday, normalize time
    }
    if (allowFuture) {
      return DateTime(
        date.year,
        date.month,
        date.day,
      ).add(Duration(days: (DateTime.monday - date.weekday + 7) % 7));
    } else {
      // Find previous Monday or today if Monday
      int daysToSubtract = (date.weekday - DateTime.monday + 7) % 7;
      return DateTime(
        date.year,
        date.month,
        date.day,
      ).subtract(Duration(days: daysToSubtract));
    }
  }

  Future<void> _pickProgramStartDate(
    BuildContext context,
    WorkoutProvider provider,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          provider.programStartDate ??
          _getNearestMonday(
            DateTime.now().subtract(const Duration(days: 7)),
          ), // Suggest nearest Monday
      firstDate: DateTime(
        2010,
      ), // Ensure firstDate itself could be a Monday or adjust logic
      lastDate: _getNearestMonday(
        DateTime.now(),
        allowFuture: false,
      ), // Allow up to the most recent Monday
      helpText: 'Select Your Program Start Date (Monday)', // Updated help text
      selectableDayPredicate: (DateTime day) {
        // Allow only Mondays to be selected.
        // DateTime.monday is a constant int value 1.
        if (day.weekday == DateTime.monday) {
          return true;
        }
        return false;
      },
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.red, // Active day, header background
              onPrimary: Colors.white, // Text on active day, header text
              onSurface: Colors.black, // Calendar text
            ).copyWith(surface: Colors.white), // Calendar background
            // Optional: Customize dialog buttons if needed
            // textButtonTheme: TextButtonThemeData(
            //   style: TextButton.styleFrom(
            //     foregroundColor: Colors.red, // Button text color
            //   ),
            // ),
          ),
          child: child!,
        );
      },
    );

    // Check mounted after await before using context for ScaffoldMessenger
    if (!context.mounted) return;

    if (picked != null && picked != provider.programStartDate) {
      try {
        await provider.setProgramStartDate(
          picked,
        ); // autoPopulatePastWorkouts defaults to true
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Program start date set to: ${_formatDateForDisplay(picked)}. Past workouts auto-completed.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting start date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, workoutProvider, child) {
        // This initial loading state check is good.
        if (workoutProvider.isLoading &&
            workoutProvider.programStartDate == null &&
            workoutProvider.workouts.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Program Schedule')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Program Schedule'),
            actions: [
              if (workoutProvider.programStartDate != null && kDebugMode)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'DEBUG: Clear Start Date',
                  onPressed: () async {
                    await workoutProvider.clearProgramStartDate();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Program start date cleared for testing.',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              if (workoutProvider.programStartDate == null)
                _buildSetStartDatePrompt(context, workoutProvider)
              else
                _buildStartDateDisplay(context, workoutProvider),
              Expanded(child: _buildScheduleContent(context, workoutProvider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSetStartDatePrompt(
    BuildContext context,
    WorkoutProvider provider,
  ) {
    // This method seems fine.
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Set Your Program Start Date',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'To properly track your schedule and progress, please select the date you first started the Insanity program.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Set Start Date'),
              onPressed: () => _pickProgramStartDate(context, provider),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDateDisplay(
    BuildContext context,
    WorkoutProvider provider,
  ) {
    // This method seems fine.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Program Started:', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            _formatDateForDisplay(provider.programStartDate),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 20, color: Colors.grey[600]),
            tooltip: 'Change Start Date',
            onPressed: () => _pickProgramStartDate(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleContent(
    BuildContext context,
    WorkoutProvider workoutProvider,
  ) {
    if (workoutProvider.programStartDate == null) {
      // This is already handled by the main build method, but acts as a safeguard.
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please set your program start date to view the schedule.',
          ),
        ),
      );
    }

    // If start date is set, but workouts are still loading (e.g., after setting start date)
    if (workoutProvider.isLoading && workoutProvider.workouts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (workoutProvider.workouts.isEmpty && !workoutProvider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No workouts found. Ensure the database is populated and schedule is set.',
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProgramOverviewCard(context, workoutProvider),
          _buildWeeklySchedule(context, workoutProvider),
        ],
      ),
    );
  }

  Widget _buildProgramOverviewCard(
    BuildContext context,
    WorkoutProvider workoutProvider,
  ) {
    // This check is good as programStartDate can be cleared in debug mode.
    if (workoutProvider.programStartDate == null) {
      return const SizedBox.shrink();
    }

    final progressData = workoutProvider.getOverallProgress();
    final currentCycleProgress = progressData['currentCycleProgress'] ?? 0.0;
    final completedCycles = progressData['completedCycles']?.toInt() ?? 0;

    final currentProgramDay = workoutProvider.getCurrentProgramDayInCycle();
    final currentProgramWeek = workoutProvider.getCurrentProgramWeekInCycle();

    // Ensure workouts list is not empty before doing LINQ operations
    final totalCycleWorkouts = workoutProvider.workouts
        .where((w) => w.workoutType == 'workout')
        .length;
    final completedCycleWorkouts = totalCycleWorkouts > 0
        ? (totalCycleWorkouts * (currentCycleProgress / 100)).round()
        : 0;

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Program Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (completedCycles > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Completed Cycles: $completedCycles',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            if (currentProgramWeek != null && currentProgramDay != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Current Cycle: Week $currentProgramWeek, Day $currentProgramDay',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: totalCycleWorkouts > 0
                  ? (currentCycleProgress / 100)
                  : 0.0,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${currentCycleProgress.toStringAsFixed(1)}% of current cycle',
                ),
                if (totalCycleWorkouts > 0)
                  Text(
                    '$completedCycleWorkouts / $totalCycleWorkouts workouts this cycle',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOverviewStat(
                  'Total Days',
                  '${WorkoutProvider.programCycleLengthDays}',
                  Icons.calendar_today_outlined,
                ),
                _buildOverviewStat(
                  'Fit Tests',
                  '${workoutProvider.workouts.where((w) => w.workoutType == 'fit_test').length}',
                  Icons.fitness_center,
                ),
                _buildOverviewStat(
                  'Rest Days',
                  '${workoutProvider.workouts.where((w) => w.workoutType == 'rest').length}',
                  Icons.bed_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStat(String label, String value, IconData icon) {
    // This method seems fine.
    return Column(
      children: [
        Icon(icon, color: Colors.red, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildWeeklySchedule(
    BuildContext context,
    WorkoutProvider workoutProvider,
  ) {
    if (workoutProvider.programStartDate == null) {
      return const SizedBox.shrink(); // Guard
    }

    Map<int, List<Workout>> weeklyWorkouts = {};
    for (int i = 1; i <= WorkoutProvider.programCycleLengthWeeks; i++) {
      weeklyWorkouts[i] = workoutProvider.getWeekWorkouts(i);
    }

    final sortedWeeks = weeklyWorkouts.keys.toList()..sort();

    return Column(
      children: sortedWeeks.map((weekNumberInCycle) {
        final List<Workout> cycleWeekWorkouts =
            weeklyWorkouts[weekNumberInCycle] ?? []; // Handle null case
        return _buildWeekCard(
          context,
          weekNumberInCycle,
          cycleWeekWorkouts,
          workoutProvider,
        );
      }).toList(),
    );
  }

  Widget _buildWeekCard(
    BuildContext context,
    int weekNumberInCycle,
    List<Workout> cycleWeekWorkouts,
    WorkoutProvider workoutProvider,
  ) {
    if (cycleWeekWorkouts.isEmpty) return const SizedBox.shrink();
    // programStartDate will be non-null here due to checks in _buildScheduleContent and _buildWeeklySchedule
    final DateTime absoluteStartDateOfProgram =
        workoutProvider.programStartDate!;

    int completedCount = 0;
    // getCurrentCycleNumber can return null if program hasn't started or date is weird.
    // However, if we reach here, programStartDate is set.
    // If today is before programStartDate, getCurrentCycleNumber is null.
    // If today is on or after programStartDate, it returns a valid cycle number (>=1).
    final int currentCycleNum =
        workoutProvider.getCurrentCycleNumber() ??
        1; // Default to 1 for display if somehow null

    // Calculate the start date of this specific week instance in the *current or most relevant cycle*
    // This logic determines which instance of Week X (e.g., Week 1 of Cycle 1, Week 1 of Cycle 2)
    // we are calculating progress for.
    // For simplicity, let's assume we want to show progress for the *current actual cycle* if the week is part of it,
    // or the *first cycle* if we are looking at past completed cycles (this could be enhanced).
    // The most straightforward is to calculate for the *current* cycle.

    final DateTime firstDayOfCurrentCycle = absoluteStartDateOfProgram.add(
      Duration(
        days: (currentCycleNum - 1) * WorkoutProvider.programCycleLengthDays,
      ),
    );
    final DateTime startDateOfThisWeekInCurrentCycle = firstDayOfCurrentCycle
        .add(Duration(days: (weekNumberInCycle - 1) * 7));

    for (final workoutInCycle in cycleWeekWorkouts) {
      final dayOfWeekInCycle = (workoutInCycle.dayNumber - 1) % 7;
      final actualDateForThisWorkout = startDateOfThisWeekInCurrentCycle.add(
        Duration(days: dayOfWeekInCycle),
      );
      final session = workoutProvider.getSessionForDate(
        actualDateForThisWorkout.toIso8601String().split('T')[0],
      );
      if (session?.completed == true &&
          (workoutInCycle.workoutType == 'workout' ||
              workoutInCycle.workoutType == 'fit_test')) {
        completedCount++;
      }
    }

    final countableWorkoutsInWeek = cycleWeekWorkouts
        .where((w) => w.workoutType == 'workout' || w.workoutType == 'fit_test')
        .length;
    final double weekProgress = countableWorkoutsInWeek > 0
        ? (completedCount / countableWorkoutsInWeek.toDouble()) * 100
        : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ExpansionTile(
        title: Text(
          'Week $weekNumberInCycle',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          // Count only actual workouts and fit tests for completion status
          '$completedCount / $countableWorkoutsInWeek workouts completed (${weekProgress.toStringAsFixed(0)}%)',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        leading: CircleAvatar(
          backgroundColor: weekProgress >= 100
              ? Colors.green
              : (weekProgress > 0 ? Colors.orangeAccent : Colors.redAccent),
          child: Text(
            '$weekNumberInCycle',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: cycleWeekWorkouts.map((workout) {
          // Calculate the actual date for this workout in the current cycle's instance of this week
          final dayOfWeekInCycle = (workout.dayNumber - 1) % 7;
          final DateTime actualWorkoutDate = startDateOfThisWeekInCurrentCycle
              .add(Duration(days: dayOfWeekInCycle));

          return _buildWorkoutListTile(
            context,
            workout,
            workoutProvider,
            actualWorkoutDate,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWorkoutListTile(
    BuildContext context,
    Workout workout,
    WorkoutProvider workoutProvider,
    DateTime actualWorkoutDate,
  ) {
    final dateString = actualWorkoutDate.toIso8601String().split('T')[0];
    final session = workoutProvider.getSessionForDate(dateString);

    Widget statusIcon;
    final today = DateTime.now();
    final normalizedActualDate = DateTime(
      actualWorkoutDate.year,
      actualWorkoutDate.month,
      actualWorkoutDate.day,
    );
    final normalizedToday = DateTime(today.year, today.month, today.day);

    if (session?.completed == true) {
      statusIcon = const Icon(Icons.check_circle, color: Colors.green);
    } else if (session != null && !session.completed) {
      statusIcon = Icon(Icons.cancel_outlined, color: Colors.orange[700]);
    } else if (workout.workoutType == 'rest') {
      // If it's a rest day and no session, it's "done" by resting
      statusIcon = Icon(
        Icons.check_circle_outline,
        color: Colors.blue[300],
      ); // Lighter check for rest
    } else if (normalizedActualDate.isBefore(normalizedToday)) {
      statusIcon = Icon(Icons.remove_circle_outline, color: Colors.red[700]);
    } else if (normalizedActualDate.isAtSameMomentAs(normalizedToday)) {
      statusIcon = Icon(Icons.radio_button_unchecked, color: Colors.blue[700]);
    } else {
      statusIcon = Icon(Icons.radio_button_unchecked, color: Colors.grey[600]);
    }

    return ListTile(
      leading: statusIcon,
      title: Text(workout.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day ${workout.dayNumber} • ${_formatDateForDisplay(actualWorkoutDate)}',
          ), // Removed "of Cycle" to shorten
          if ((session?.notes?.isNotEmpty == true))
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                'Note: ${session?.notes}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      trailing: Chip(
        label: Text(
          workout.workoutType.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(fontSize: 10, color: Colors.black87),
        ),
        backgroundColor: _getWorkoutTypeColor(workout.workoutType),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      ),
      onTap: () => _showWorkoutDetailsDialog(
        context,
        workout,
        workoutProvider,
        session,
        actualWorkoutDate,
      ),
    );
  }

  void _showWorkoutDetailsDialog(
    BuildContext context,
    Workout workout,
    WorkoutProvider workoutProvider,
    WorkoutSession? session,
    DateTime actualWorkoutDate,
  ) {
    // This method seems generally okay from the previous version,
    // ensure `mounted` checks if any further async operations are added inside.
    final today = DateTime.now();
    final normalizedActualDate = DateTime(
      actualWorkoutDate.year,
      actualWorkoutDate.month,
      actualWorkoutDate.day,
    );
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final bool canModify =
        (normalizedActualDate.isAtSameMomentAs(normalizedToday) ||
            normalizedActualDate.isBefore(normalizedToday)) &&
        workoutProvider.programStartDate != null;

    String statusText;
    Color statusColor;

    if (session?.completed == true) {
      statusText = 'Completed';
      statusColor = Colors.green;
    } else if (session != null && !session.completed) {
      statusText = 'Skipped';
      statusColor = Colors.orange;
    } else if (workout.workoutType == 'rest') {
      statusText = 'Rest Day';
      statusColor = Colors.blue;
    } else if (normalizedActualDate.isBefore(normalizedToday)) {
      statusText = 'Missed';
      statusColor = Colors.red;
    } else if (normalizedActualDate.isAtSameMomentAs(normalizedToday)) {
      statusText = 'Today';
      statusColor = Colors.blue;
    } else {
      statusText = 'Upcoming';
      statusColor = Colors.grey;
    }

    final notesController = TextEditingController(text: session?.notes ?? '');

    showDialog(
      context: context, // context is from the builder of showDialog, safe
      builder: (dialogContext) => AlertDialog(
        title: Text(workout.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date: ${_formatDateForDisplay(actualWorkoutDate)} (Day ${workout.dayNumber} of Cycle)',
              ),
              Text(
                'Type: ${workout.workoutType.replaceAll('_', ' ').toUpperCase()}',
              ),
              const SizedBox(height: 8),
              Text(
                'Status: $statusText',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 10),
              if (canModify ||
                  (session?.notes != null && session!.notes!.isNotEmpty))
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Add any notes for this session...',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  enabled: canModify,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (canModify && workout.workoutType != 'rest') ...[
            // Don't show complete/skip for rest days
            if (session?.completed != true)
              ElevatedButton(
                onPressed: () async {
                  await workoutProvider.completeWorkout(
                    workout.id,
                    notes: notesController.text,
                    dateOverride: actualWorkoutDate,
                  );
                  if (!dialogContext.mounted) {
                    return; // Check mounted before popping
                  }
                  Navigator.pop(dialogContext);
                  if (!context.mounted) {
                    return; // Check original context for ScaffoldMessenger
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${workout.name} marked as completed.'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Complete'),
              ),
            // Show skip if not already skipped, OR if it's marked as completed and user wants to un-complete/skip
            if (session?.completed == true ||
                (session == null &&
                    !normalizedActualDate.isAfter(normalizedToday)))
              OutlinedButton(
                onPressed: () async {
                  await workoutProvider.skipWorkout(
                    workout.id,
                    reason: notesController.text,
                    dateOverride: actualWorkoutDate,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${workout.name} marked as skipped/not completed.',
                      ),
                    ),
                  );
                },
                child: Text(
                  session?.completed == true ? 'Mark Not Done' : 'Skip Workout',
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _getWorkoutTypeColor(String workoutType) {
    switch (workoutType) {
      case 'fit_test':
        return Colors.purple.shade100;
      case 'rest':
        return Colors.blue.shade100;
      case 'workout':
        return Colors.red.shade100; // Explicitly for 'workout'
      default:
        return Colors.grey.shade200; // A more neutral default
    }
  }
}
