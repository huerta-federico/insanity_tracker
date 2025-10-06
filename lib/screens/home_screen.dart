import 'package:flutter/material.dart';
import 'package:insanity_tracker/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import '../models/workout_session.dart';
import '../providers/utils_provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout.dart';

/// Data class to hold today's workout information
/// Using a separate class allows Selector to efficiently track changes
class _TodaysWorkoutData {
  final Workout? workout;
  final WorkoutSession? session;
  final bool isLoading;

  const _TodaysWorkoutData({
    this.workout,
    this.session,
    required this.isLoading,
  });

  /// Override equality operator to enable proper change detection in Selector
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _TodaysWorkoutData &&
              workout == other.workout &&
              session == other.session &&
              isLoading == other.isLoading;

  /// Override hashCode when overriding equality operator (Dart requirement)
  @override
  int get hashCode => Object.hash(workout, session, isLoading);
}

/// Data class to hold quick statistics for the week
/// Separating this data allows the stats section to rebuild independently
class _QuickStatsData {
  final int completedThisWeek;
  final int scheduledThisWeek;
  final double currentCycleProgress;
  final bool isLoading;

  const _QuickStatsData({
    required this.completedThisWeek,
    required this.scheduledThisWeek,
    required this.currentCycleProgress,
    required this.isLoading,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _QuickStatsData &&
              completedThisWeek == other.completedThisWeek &&
              scheduledThisWeek == other.scheduledThisWeek &&
              currentCycleProgress == other.currentCycleProgress &&
              isLoading == other.isLoading;

  @override
  int get hashCode => Object.hash(
    completedThisWeek,
    scheduledThisWeek,
    currentCycleProgress,
    isLoading,
  );
}

/// Main home screen widget
/// This is a StatelessWidget because it doesn't manage its own state
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insanity Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: const _HomeScreenBody(),
    );
  }
}

/// Body content of the home screen
/// Separated into its own widget for better organization
class _HomeScreenBody extends StatelessWidget {
  const _HomeScreenBody();

  @override
  Widget build(BuildContext context) {
    // Selector listens to WorkoutProvider but only rebuilds when the selected value changes
    // This is more efficient than Consumer which rebuilds on any provider change
    return Selector<WorkoutProvider, bool>(
      selector: (_, provider) =>
      provider.isLoading &&
          provider.getTodaysWorkout() == null &&
          provider.sessions.isEmpty,
      builder: (context, isInitialLoading, _) {
        // Show loading indicator only during initial app startup
        if (isInitialLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing app data...'),
              ],
            ),
          );
        }

        // Main content with scrolling enabled for smaller screens
        return const SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeCard(),
              SizedBox(height: 16),
              _TodaysWorkoutSection(),
              SizedBox(height: 16),
              _QuickStatsSection(),
            ],
          ),
        );
      },
    );
  }
}

/// Welcome card that displays greeting and current date
/// StatefulWidget because it needs to track the day to update at midnight
class _WelcomeCard extends StatefulWidget {
  const _WelcomeCard();

  @override
  State<_WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<_WelcomeCard> {
  late int _lastUpdatedDay;

  @override
  void initState() {
    super.initState();
    _updateDateInfo();
  }

  /// Store the current day number to detect when the date changes
  void _updateDateInfo() {
    final now = DateTime.now();
    _lastUpdatedDay = now.day;
  }

  @override
  Widget build(BuildContext context) {
    // Check if the day has changed since last build
    // This ensures the date updates if the user keeps the app open past midnight
    final currentDay = DateTime.now().day;
    if (currentDay != _lastUpdatedDay) {
      _updateDateInfo();
    }

    return const Card(
      child: Padding(padding: EdgeInsets.all(16.0), child: _WelcomeContent()),
    );
  }
}

/// Content for the welcome card (separated for cleaner code)
class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent();

  /// Array of day names for display (Monday = index 0)
  static const List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // weekday is 1-7 (Monday-Sunday), subtract 1 to get array index
    final todayName = _dayNames[now.weekday - 1];
    final dateString = UtilsProvider.formatDate(
      UtilsProvider.formatDateForDisplay(now),
    );

    return Row(
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
              '$todayName, $dateString',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}

/// Section that displays today's workout information
/// Uses Selector to efficiently rebuild only when today's workout data changes
class _TodaysWorkoutSection extends StatelessWidget {
  const _TodaysWorkoutSection();

  @override
  Widget build(BuildContext context) {
    return Selector<WorkoutProvider, _TodaysWorkoutData>(
      selector: (_, provider) {
        // Get today's date in ISO format (YYYY-MM-DD) for session lookup
        final todayKey = DateTime.now().toIso8601String().split('T')[0];
        return _TodaysWorkoutData(
          workout: provider.getTodaysWorkout(),
          session: provider.getSessionForDate(todayKey),
          isLoading: provider.isLoading,
        );
      },
      builder: (context, data, _) {
        // Show loading indicator if data isn't ready yet
        if (data.isLoading && data.workout == null && data.session == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return _TodaysWorkoutCard(
          todaysWorkout: data.workout,
          todaysSession: data.session,
        );
      },
    );
  }
}

/// Card displaying today's workout details and action buttons
class _TodaysWorkoutCard extends StatelessWidget {
  final Workout? todaysWorkout;
  final WorkoutSession? todaysSession;

  const _TodaysWorkoutCard({
    required this.todaysWorkout,
    required this.todaysSession,
  });

  // Define text styles as constants for consistency and performance
  // Defining them once avoids recreating TextStyle objects on every build
  static const _titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
  static const _workoutNameStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const _detailsStyle = TextStyle(fontSize: 14, color: Colors.grey);
  static const _noWorkoutStyle = TextStyle(fontSize: 16, color: Colors.grey);

  /// Returns appropriate color based on workout type
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

  /// Formats workout duration into human-readable text
  /// Examples: "45 min", "1h 15min", "No workout"
  String _formatDuration(int minutes) {
    if (minutes == 0) return 'No workout';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60; // Integer division
    final remainingMinutes = minutes % 60; // Modulo operator for remainder
    if (remainingMinutes == 0) return '${hours}h';
    return '${hours}h ${remainingMinutes}min';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today\'s Workout', style: _titleStyle),
            const SizedBox(height: 12),
            // Conditional rendering: show workout details or "no workout" message
            if (todaysWorkout != null) ...[
              Text(todaysWorkout!.name, style: _workoutNameStyle),
              const SizedBox(height: 4),
              // Display workout metadata in a horizontal row
              Row(
                children: [
                  Text(
                    'Week ${todaysWorkout!.weekNumber} • Day ${todaysWorkout!.dayNumber}',
                    style: _detailsStyle,
                  ),
                  // Only show duration if it's greater than 0
                  if (todaysWorkout!.durationMinutes > 0) ...[
                    const Text(' • ', style: _detailsStyle),
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(todaysWorkout!.durationMinutes),
                      style: _detailsStyle,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Visual badge showing workout type
              _WorkoutTypeChip(
                workoutType: todaysWorkout!.workoutType,
                backgroundColor: _getWorkoutTypeColor(
                  todaysWorkout!.workoutType,
                ),
              ),
              const SizedBox(height: 16),
              // Display appropriate UI based on workout completion status
              _WorkoutStatus(workout: todaysWorkout!, session: todaysSession),
            ] else ...[
              // Fallback when no workout is scheduled
              const Text(
                'No workout scheduled for today',
                style: _noWorkoutStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Visual chip/badge displaying the workout type
class _WorkoutTypeChip extends StatelessWidget {
  final String workoutType;
  final Color backgroundColor;

  const _WorkoutTypeChip({
    required this.workoutType,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        // Convert "fit_test" to "FIT TEST" for display
        workoutType.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Widget that shows the current workout status and appropriate UI
/// This could be: completed message, skipped message, or action buttons
class _WorkoutStatus extends StatelessWidget {
  final Workout workout;
  final WorkoutSession? session;

  const _WorkoutStatus({required this.workout, required this.session});

  static const _completedStyle = TextStyle(
    fontSize: 16,
    color: Colors.green,
    fontWeight: FontWeight.bold,
  );
  static const _skippedStyle = TextStyle(
    fontSize: 16,
    color: Colors.orange,
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    // If workout is already completed, show completion message
    if (session?.completed == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Completed!', style: _completedStyle),
            ],
          ),
          // Show notes if they exist
          if (session?.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Notes: ${session!.notes}'),
          ],
        ],
      );
    }

    // If workout was skipped, show skip message
    if (session?.completed == false) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cancel, color: Colors.orange),
              SizedBox(width: 8),
              Text('Skipped', style: _skippedStyle),
            ],
          ),
          if (session?.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Reason: ${session!.notes}'),
          ],
        ],
      );
    }

    // Otherwise, show action buttons to complete or skip
    return _WorkoutActionButtons(workout: workout);
  }
}

/// Interactive section with notes field and Complete/Skip buttons
/// StatefulWidget because it needs to manage the text field's state
class _WorkoutActionButtons extends StatefulWidget {
  final Workout workout;

  const _WorkoutActionButtons({required this.workout});

  @override
  State<_WorkoutActionButtons> createState() => _WorkoutActionButtonsState();
}

class _WorkoutActionButtonsState extends State<_WorkoutActionButtons> {
  // Controller to manage the text field's content
  // We need to create and dispose of this properly to avoid memory leaks
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    // Initialize the controller when the widget is first created
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    // Always dispose of controllers to free up resources
    // This is critical in Flutter to prevent memory leaks
    _notesController.dispose();
    super.dispose();
  }

  /// Marks the workout as completed and saves any notes
  Future<void> _completeWorkout(BuildContext context) async {
    // Rest days have special handling
    if (widget.workout.workoutType == 'rest') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rest days are automatically completed.'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // Get the WorkoutProvider without listening to changes
    // listen: false is important here because we're in a callback, not build()
    final provider = Provider.of<WorkoutProvider>(context, listen: false);

    // Trim the notes and only save if there's actual content
    final notes = _notesController.text.trim();
    await provider.completeWorkout(
      widget.workout.id,
      notes: notes.isEmpty ? null : notes,
    );

    // Check if widget is still mounted before using context
    // This prevents errors if user navigates away during the async operation
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Completed: ${widget.workout.name}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Marks the workout as skipped with optional reason
  Future<void> _skipWorkout(BuildContext context) async {
    if (widget.workout.workoutType == 'rest') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rest days cannot be skipped.'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    final reason = _notesController.text.trim();

    await provider.skipWorkout(
      widget.workout.id,
      reason: reason.isEmpty ? 'No reason provided' : reason,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skipped: ${widget.workout.name}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Special UI for rest days
    if (widget.workout.workoutType == 'rest') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        alignment: Alignment.center,
        child: Text(
          'Enjoy your rest day!',
          style: TextStyle(
            fontSize: 16,
            color: Colors.blue.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Regular workout UI with notes field and action buttons
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Text field for notes - always visible and editable
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'How did it go? Any thoughts?',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            // Add a small icon to make it clear this is for notes
            prefixIcon: Icon(Icons.note_outlined, size: 20),
          ),
          maxLines: 2,
          minLines: 1,
          // Done button on keyboard instead of new line
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        // Action buttons in a horizontal row
        Row(
          children: [
            // Expanded makes each button take equal width
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _completeWorkout(context),
                icon: const Icon(Icons.check),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  // Add some padding for better touch targets
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _skipWorkout(context),
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Quick statistics section showing weekly progress
class _QuickStatsSection extends StatelessWidget {
  const _QuickStatsSection();

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when stats actually change
    return Selector<WorkoutProvider, _QuickStatsData>(
      selector: (_, provider) {
        final thisWeekSessions = provider.getThisWeekSessions();
        final progressData = provider.getOverallProgress();

        return _QuickStatsData(
          completedThisWeek: thisWeekSessions.where((s) => s.completed).length,
          scheduledThisWeek: thisWeekSessions.length,
          currentCycleProgress: progressData['currentCycleProgress'] ?? 0.0,
          isLoading: provider.isLoading,
        );
      },
      builder: (context, data, _) {
        // Show loading state if no data is available yet
        if (data.isLoading && data.scheduledThisWeek == 0) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return _QuickStatsCard(
          completedThisWeek: data.completedThisWeek,
          scheduledThisWeek: data.scheduledThisWeek,
          currentCycleProgress: data.currentCycleProgress,
        );
      },
    );
  }
}

/// Card displaying quick statistics in a visual format
class _QuickStatsCard extends StatelessWidget {
  final int completedThisWeek;
  final int scheduledThisWeek;
  final double currentCycleProgress;

  const _QuickStatsCard({
    required this.completedThisWeek,
    required this.scheduledThisWeek,
    required this.currentCycleProgress,
  });

  static const _titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This Week', style: _titleStyle),
            const SizedBox(height: 12),
            // Display stats in a horizontal row with equal spacing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Completed',
                  value: '$completedThisWeek',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                _StatItem(
                  label: 'Scheduled',
                  value: '$scheduledThisWeek',
                  icon: Icons.fitness_center,
                  color: Colors.blue,
                ),
                _StatItem(
                  label: 'Cycle Progress',
                  // toStringAsFixed(0) shows whole number with no decimals
                  value: '${currentCycleProgress.toStringAsFixed(0)}%',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual stat item with icon, value, and label
/// Used to display each metric in the quick stats section
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  static const _labelStyle = TextStyle(fontSize: 12, color: Colors.grey);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        Text(label, style: _labelStyle),
      ],
    );
  }
}