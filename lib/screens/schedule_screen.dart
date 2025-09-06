import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout.dart';

/// Schedule screen showing the complete 60-day Insanity program calendar
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('60-Day Schedule')),
      body: Consumer<WorkoutProvider>(
        builder: (context, workoutProvider, child) {
          if (workoutProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Program overview card
                _buildProgramOverviewCard(workoutProvider),

                // Weekly schedule breakdown
                _buildWeeklySchedule(context, workoutProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Program overview card with completion stats
  Widget _buildProgramOverviewCard(WorkoutProvider workoutProvider) {
    final totalWorkouts = workoutProvider.workouts
        .where((w) => w.workoutType == 'workout')
        .length;
    final completedWorkouts = workoutProvider.sessions
        .where((s) => s.completed)
        .length;
    final progress = totalWorkouts > 0
        ? (completedWorkouts / totalWorkouts) * 100
        : 0.0;

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
            const SizedBox(height: 12),

            // Progress bar
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${progress.toStringAsFixed(1)}% Complete'),
                Text('$completedWorkouts/$totalWorkouts workouts'),
              ],
            ),

            const SizedBox(height: 12),

            // Quick stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOverviewStat('Total Days', '60', Icons.calendar_month),
                _buildOverviewStat('Fit Tests', '5', Icons.fitness_center),
                _buildOverviewStat('Rest Days', '9', Icons.bed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Individual overview stat widget
  Widget _buildOverviewStat(String label, String value, IconData icon) {
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

  /// Build weekly schedule breakdown
  Widget _buildWeeklySchedule(
    BuildContext context,
    WorkoutProvider workoutProvider,
  ) {
    // Group workouts by week
    Map<int, List<Workout>> weeklyWorkouts = {};
    for (var workout in workoutProvider.workouts) {
      if (!weeklyWorkouts.containsKey(workout.weekNumber)) {
        weeklyWorkouts[workout.weekNumber] = [];
      }
      weeklyWorkouts[workout.weekNumber]!.add(workout);
    }

    // Sort weeks and workouts within each week
    final sortedWeeks = weeklyWorkouts.keys.toList()..sort();
    for (var week in sortedWeeks) {
      weeklyWorkouts[week]!.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    }

    return Column(
      children: sortedWeeks.map((weekNumber) {
        final weekWorkouts = weeklyWorkouts[weekNumber]!;
        return _buildWeekCard(
          context,
          weekNumber,
          weekWorkouts,
          workoutProvider,
        );
      }).toList(),
    );
  }

  /// Build individual week card
  Widget _buildWeekCard(
    BuildContext context,
    int weekNumber,
    List<Workout> weekWorkouts,
    WorkoutProvider workoutProvider,
  ) {
    // Calculate week completion
    final completedCount = weekWorkouts.where((workout) {
      final session = workoutProvider.getSessionForDate(
        _getWorkoutDate(workout.dayNumber).toIso8601String().split('T')[0],
      );
      return session?.completed == true;
    }).length;

    final weekProgress = weekWorkouts.isNotEmpty
        ? (completedCount / weekWorkouts.length) * 100
        : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ExpansionTile(
        title: Text(
          'Week $weekNumber',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$completedCount/${weekWorkouts.length} completed (${weekProgress.toStringAsFixed(0)}%)',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        leading: CircleAvatar(
          backgroundColor: weekProgress == 100 ? Colors.green : Colors.red,
          child: Text(
            '$weekNumber',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: weekWorkouts.map((workout) {
          return _buildWorkoutListTile(context, workout, workoutProvider);
        }).toList(),
      ),
    );
  }

  /// Build individual workout list tile
  Widget _buildWorkoutListTile(
    BuildContext context,
    Workout workout,
    WorkoutProvider workoutProvider,
  ) {
    final workoutDate = _getWorkoutDate(workout.dayNumber);
    final dateString = workoutDate.toIso8601String().split('T')[0];
    final session = workoutProvider.getSessionForDate(dateString);

    // Determine status
    Widget statusIcon;
    Color statusColor;
    String statusText;

    if (session?.completed == true) {
      statusIcon = const Icon(Icons.check_circle, color: Colors.green);
      statusColor = Colors.green;
      statusText = 'Completed';
    } else if (session?.completed == false) {
      statusIcon = const Icon(Icons.cancel, color: Colors.orange);
      statusColor = Colors.orange;
      statusText = 'Skipped';
    } else if (_isPastDate(workoutDate)) {
      statusIcon = const Icon(Icons.schedule, color: Colors.red);
      statusColor = Colors.red;
      statusText = 'Missed';
    } else if (_isToday(workoutDate)) {
      statusIcon = const Icon(Icons.today, color: Colors.blue);
      statusColor = Colors.blue;
      statusText = 'Today';
    } else {
      statusIcon = const Icon(Icons.radio_button_unchecked, color: Colors.grey);
      statusColor = Colors.grey;
      statusText = 'Upcoming';
    }

    return ListTile(
      leading: statusIcon,
      title: Text(workout.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Day ${workout.dayNumber} • ${_formatDate(workoutDate)}'),
          if (session?.notes != null && session!.notes!.isNotEmpty)
            Text(
              'Note: ${session.notes}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Chip(
            label: Text(
              workout.workoutType.toUpperCase(),
              style: const TextStyle(fontSize: 10),
            ),
            backgroundColor: _getWorkoutTypeColor(workout.workoutType),
          ),
        ],
      ),
      onTap: () =>
          _showWorkoutDetails(context, workout, workoutProvider, session),
    );
  }

  /// Show workout details dialog
  void _showWorkoutDetails(
    BuildContext context,
    Workout workout,
    WorkoutProvider workoutProvider,
    dynamic session,
  ) {
    final workoutDate = _getWorkoutDate(workout.dayNumber);
    final canModify = _isToday(workoutDate) || _isPastDate(workoutDate);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(workout.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Day ${workout.dayNumber} of 60'),
            Text('Week ${workout.weekNumber}'),
            Text('Date: ${_formatDate(workoutDate)}'),
            Text('Type: ${workout.workoutType.toUpperCase()}'),

            if (session != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              Text(
                'Status: ${session.completed ? "Completed" : "Skipped"}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: session.completed ? Colors.green : Colors.orange,
                ),
              ),
              if (session.notes != null && session.notes.isNotEmpty)
                Text('Notes: ${session.notes}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (canModify && (session?.completed != true)) ...[
            ElevatedButton(
              onPressed: () {
                workoutProvider.completeWorkout(
                  workout.id,
                  notes: 'Completed from schedule',
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Completed: ${workout.name}')),
                );
              },
              child: const Text('Complete'),
            ),
          ],
        ],
      ),
    );
  }

  /// Get workout type color
  Color _getWorkoutTypeColor(String workoutType) {
    switch (workoutType) {
      case 'fit_test':
        return Colors.purple.shade100;
      case 'rest':
        return Colors.blue.shade100;
      default:
        return Colors.red.shade100;
    }
  }

  /// Calculate workout date based on day number (assuming program starts today)
  /// Note: In a real app, you'd have a program start date setting
  DateTime _getWorkoutDate(int dayNumber) {
    final today = DateTime.now();
    // For now, assume day 1 was today - you can adjust this logic later
    return today.add(Duration(days: dayNumber - 1));
  }

  /// Check if date is today
  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  /// Check if date is in the past
  bool _isPastDate(DateTime date) {
    final today = DateTime.now();
    return date.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
