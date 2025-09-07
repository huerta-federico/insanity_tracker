import 'package:flutter/material.dart';
import 'package:insanity_tracker/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import '../models/workout_session.dart';
import '../providers/workout_provider.dart';
import '../models/workout.dart';

class _TodaysWorkoutData {
  final Workout? workout;
  final WorkoutSession? session;
  final bool isLoading;

  const _TodaysWorkoutData({
    this.workout,
    this.session,
    required this.isLoading,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TodaysWorkoutData &&
          workout == other.workout &&
          session == other.session &&
          isLoading == other.isLoading;

  @override
  int get hashCode => Object.hash(workout, session, isLoading);
}

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

class _HomeScreenBody extends StatelessWidget {
  const _HomeScreenBody();

  @override
  Widget build(BuildContext context) {
    return Selector<WorkoutProvider, bool>(
      selector: (_, provider) =>
          provider.isLoading &&
          provider.getTodaysWorkout() == null &&
          provider.sessions.isEmpty,
      builder: (context, isInitialLoading, _) {
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

class _WelcomeCard extends StatefulWidget {
  const _WelcomeCard();

  @override
  State<_WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<_WelcomeCard> {
  late String _dateString;
  late String _todayName;
  late int _lastUpdatedDay;

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
  void initState() {
    super.initState();
    _updateDateInfo();
  }

  void _updateDateInfo() {
    final now = DateTime.now();
    _todayName = _dayNames[now.weekday - 1];
    _dateString = '${now.day}/${now.month}/${now.year}';
    _lastUpdatedDay = now.day;
  }

  @override
  Widget build(BuildContext context) {
    // Check if we need to update the date (crossed midnight)
    final currentDay = DateTime.now().day;
    if (currentDay != _lastUpdatedDay) {
      _updateDateInfo();
    }

    return const Card(
      child: Padding(padding: EdgeInsets.all(16.0), child: _WelcomeContent()),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent();

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
    final todayName = _dayNames[now.weekday - 1];
    final dateString = '${now.day}/${now.month}/${now.year}';

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

class _TodaysWorkoutSection extends StatelessWidget {
  const _TodaysWorkoutSection();

  @override
  Widget build(BuildContext context) {
    return Selector<WorkoutProvider, _TodaysWorkoutData>(
      selector: (_, provider) {
        final todayKey = DateTime.now().toIso8601String().split('T')[0];
        return _TodaysWorkoutData(
          workout: provider.getTodaysWorkout(),
          session: provider.getSessionForDate(todayKey),
          isLoading: provider.isLoading,
        );
      },
      builder: (context, data, _) {
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

class _TodaysWorkoutCard extends StatelessWidget {
  final Workout? todaysWorkout;
  final WorkoutSession? todaysSession;

  const _TodaysWorkoutCard({
    required this.todaysWorkout,
    required this.todaysSession,
  });

  static const _titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
  static const _workoutNameStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const _detailsStyle = TextStyle(fontSize: 14, color: Colors.grey);
  static const _chipTextStyle = TextStyle(fontSize: 12);
  static const _noWorkoutStyle = TextStyle(fontSize: 16, color: Colors.grey);
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
            if (todaysWorkout != null) ...[
              Text(todaysWorkout!.name, style: _workoutNameStyle),
              const SizedBox(height: 4),
              Text(
                'Week ${todaysWorkout!.weekNumber} • Day ${todaysWorkout!.dayNumber}',
                style: _detailsStyle,
              ),
              const SizedBox(height: 8),
              _WorkoutTypeChip(
                workoutType: todaysWorkout!.workoutType,
                backgroundColor: _getWorkoutTypeColor(
                  todaysWorkout!.workoutType,
                ),
              ),
              const SizedBox(height: 16),
              _WorkoutStatus(workout: todaysWorkout!, session: todaysSession),
            ] else ...[
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
        workoutType.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

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
          if (session?.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Notes: ${session!.notes}'),
          ],
        ],
      );
    }

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

    return _WorkoutActionButtons(workout: workout);
  }
}

class _WorkoutActionButtons extends StatelessWidget {
  final Workout workout;

  const _WorkoutActionButtons({required this.workout});

  Future<void> _completeWorkout(BuildContext context) async {
    // Check if the workout is a rest day before showing the dialog
    // Although the button itself will be hidden, this is a good secondary check
    // if this function were ever called from somewhere else.
    if (workout.workoutType == 'rest') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rest days are automatically completed.'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete Workout'),
        content: Text('Mark "${workout.name}" as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final provider = Provider.of<WorkoutProvider>(context, listen: false);
      await provider.completeWorkout(
        workout.id,
        notes: 'Completed from home screen',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completed: ${workout.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _skipWorkout(BuildContext context) async {
    // Check if the workout is a rest day
    if (workout.workoutType == 'rest') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rest days cannot be skipped.'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final provider = Provider.of<WorkoutProvider>(context, listen: false);
      await provider.skipWorkout(
        workout.id,
        reason: reasonController.text.isEmpty
            ? 'No reason provided'
            : reasonController.text,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Skipped: ${workout.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (workout.workoutType == 'rest') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        alignment: Alignment.center,
        child: Text(
          'Enjoy your rest day!',
          style: TextStyle(
            fontSize: 16,
            color: Colors.blue.shade700, // Or Theme.of(context).primaryColor
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _completeWorkout(context),
            icon: const Icon(Icons.check),
            label: const Text('Complete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _skipWorkout(context),
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip'),
          ),
        ),
      ],
    );
  }
}

class _QuickStatsSection extends StatelessWidget {
  const _QuickStatsSection();

  @override
  Widget build(BuildContext context) {
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
