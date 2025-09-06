import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout.dart';
import 'data_import_screen.dart';

/// Home screen showing today's workout and quick actions
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insanity Tracker'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.upload),
                  title: Text('Import Historical Data'),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'import') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DataImportScreen(),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<WorkoutProvider>(
        builder: (context, workoutProvider, child) {
          if (workoutProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final todaysWorkout = workoutProvider.getTodaysWorkout();
          final todaysSession = workoutProvider.getSessionForDate(
            DateTime.now().toIso8601String().split('T')[0],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome section
                _buildWelcomeCard(context),

                const SizedBox(height: 16),

                // Today's workout section
                _buildTodaysWorkoutCard(
                  context,
                  todaysWorkout,
                  todaysSession,
                  workoutProvider,
                ),

                const SizedBox(height: 16),

                // Quick stats section
                _buildQuickStatsCard(context, workoutProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Welcome card with current day information
  Widget _buildWelcomeCard(BuildContext context) {
    final now = DateTime.now();
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final todayName = dayNames[now.weekday - 1];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.waving_hand, size: 32, color: Colors.orange),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$todayName, ${now.day}/${now.month}/${now.year}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Today's workout card with completion actions
  Widget _buildTodaysWorkoutCard(
      BuildContext context,
      Workout? todaysWorkout,
      dynamic todaysSession,
      WorkoutProvider workoutProvider,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Workout',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (todaysWorkout != null) ...[
              // Workout name and type
              Text(
                todaysWorkout.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Week ${todaysWorkout.weekNumber} • Day ${todaysWorkout.dayNumber}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),

              // Workout type chip
              Chip(
                label: Text(
                  todaysWorkout.workoutType.toUpperCase(),
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _getWorkoutTypeColor(todaysWorkout.workoutType),
              ),

              const SizedBox(height: 16),

              // Status and action buttons
              if (todaysSession?.completed == true) ...[
                // Already completed
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Completed!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (todaysSession?.notes != null) ...[
                  const SizedBox(height: 8),
                  Text('Notes: ${todaysSession.notes}'),
                ],
              ] else if (todaysSession?.completed == false) ...[
                // Marked as skipped
                const Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Skipped',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (todaysSession?.notes != null) ...[
                  const SizedBox(height: 8),
                  Text('Reason: ${todaysSession.notes}'),
                ],
              ] else ...[
                // Not completed yet - show action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _completeWorkout(context, todaysWorkout, workoutProvider),
                        icon: const Icon(Icons.check),
                        label: const Text('Complete'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _skipWorkout(context, todaysWorkout, workoutProvider),
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Skip'),
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // No workout scheduled
              const Text(
                'No workout scheduled for today',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Quick stats card showing progress overview
  Widget _buildQuickStatsCard(BuildContext context, WorkoutProvider workoutProvider) {
    final thisWeekSessions = workoutProvider.getThisWeekSessions();
    final completedThisWeek = thisWeekSessions.where((s) => s.completed).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This Week',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Completed',
                  '$completedThisWeek',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatItem(
                  'Total',
                  '${thisWeekSessions.length}',
                  Icons.fitness_center,
                  Colors.blue,
                ),
                _buildStatItem(
                  'Progress',
                  '${workoutProvider.getOverallProgress().toStringAsFixed(0)}%',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Individual stat item widget
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  /// Get color for workout type chip
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

  /// Complete workout with confirmation
  void _completeWorkout(BuildContext context, Workout workout, WorkoutProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Workout'),
        content: Text('Mark "${workout.name}" as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.completeWorkout(workout.id, notes: 'Completed from home screen');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Completed: ${workout.name}!')),
              );
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  /// Skip workout with reason input
  void _skipWorkout(BuildContext context, Workout workout, WorkoutProvider provider) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Workout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Skip "${workout.name}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g., Not feeling well, too busy...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.skipWorkout(
                workout.id,
                reason: reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Skipped: ${workout.name}')),
              );
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}