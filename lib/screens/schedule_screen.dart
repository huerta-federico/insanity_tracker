import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workout_session.dart';
import '../providers/start_date_provider.dart';
import '../providers/utils_provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout.dart';

final StartDateProvider _startDateProvider = StartDateProvider();


class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Program Schedule')),
      body: Consumer<WorkoutProvider>(
        builder: (context, workoutProvider, child) {
          if (workoutProvider.isLoading &&
              workoutProvider.programStartDate == null &&
              workoutProvider.workouts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (workoutProvider.programStartDate == null)
                _SetStartDatePrompt(
                  onSetStartDate: () => _startDateProvider.pickProgramStartDate(
                    context,
                    workoutProvider,
                  ),
                )
              else
                Expanded(
                  child: _ScheduleContent(workoutProvider: workoutProvider),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SetStartDatePrompt extends StatelessWidget {
  final VoidCallback onSetStartDate;

  const _SetStartDatePrompt({required this.onSetStartDate});

  @override
  Widget build(BuildContext context) {
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
              onPressed: onSetStartDate,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleContent extends StatelessWidget {
  final WorkoutProvider workoutProvider;

  const _ScheduleContent({required this.workoutProvider});

  @override
  Widget build(BuildContext context) {
    if (workoutProvider.programStartDate == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Please set your program start date to view the schedule.',
          ),
        ),
      );
    }

    if (workoutProvider.isLoading && workoutProvider.workouts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (workoutProvider.workouts.isEmpty && !workoutProvider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No workouts found. Ensure the database is populated.'),
        ),
      );
    }

    // Pre-calculate common values to avoid repeated calculations
    final programStartDate = workoutProvider.programStartDate!;
    final currentCycleNum = workoutProvider.getCurrentCycleNumber() ?? 1;
    final firstDayOfCurrentCycle = programStartDate.add(
      Duration(
        days: (currentCycleNum - 1) * WorkoutProvider.programCycleLengthDays,
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _ProgramOverviewCard(workoutProvider: workoutProvider),
        ),
        _WeeklyScheduleSliver(
          workoutProvider: workoutProvider,
          firstDayOfCurrentCycle: firstDayOfCurrentCycle,
        ),
      ],
    );
  }
}

class _ProgramOverviewCard extends StatelessWidget {
  final WorkoutProvider workoutProvider;

  const _ProgramOverviewCard({required this.workoutProvider});

  @override
  Widget build(BuildContext context) {
    if (workoutProvider.programStartDate == null) {
      return const SizedBox.shrink();
    }

    // Pre-calculate all values to avoid rebuilds
    final progressData = workoutProvider.getOverallProgress();
    final currentCycleProgress = progressData['currentCycleProgress'] ?? 0.0;
    final currentProgramDay = workoutProvider.getCurrentProgramDayInCycle();
    final currentProgramWeek = workoutProvider.getCurrentProgramWeekInCycle();

    final totalCountableWorkouts = workoutProvider.workouts
        .where((w) => w.workoutType == 'workout' || w.workoutType == 'fit_test')
        .length;

    final completedCycleWorkouts = totalCountableWorkouts > 0
        ? (totalCountableWorkouts * (currentCycleProgress / 100)).round()
        : 0;

    final restDays = workoutProvider.workouts
        .where((w) => w.workoutType == 'rest')
        .length;

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
            if (currentProgramWeek != null && currentProgramDay != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Current Cycle: Week $currentProgramWeek, Day $currentProgramDay',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: totalCountableWorkouts > 0
                    ? (currentCycleProgress / 100)
                    : 0.0,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${currentCycleProgress.toStringAsFixed(1)}% of current cycle',
                ),
                if (totalCountableWorkouts > 0)
                  Text(
                    '$completedCycleWorkouts / $totalCountableWorkouts workouts completed',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _OverviewStat(
                  label: 'Total Days',
                  value: '${WorkoutProvider.programCycleLengthDays}',
                  icon: Icons.calendar_month_outlined,
                ),
                _OverviewStat(
                  label: 'Active Days',
                  value: '$totalCountableWorkouts',
                  icon: Icons.fitness_center,
                ),
                _OverviewStat(
                  label: 'Rest Days',
                  value: '$restDays',
                  icon: Icons.bed_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _OverviewStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
}

class _WeeklyScheduleSliver extends StatelessWidget {
  final WorkoutProvider workoutProvider;
  final DateTime firstDayOfCurrentCycle;

  const _WeeklyScheduleSliver({
    required this.workoutProvider,
    required this.firstDayOfCurrentCycle,
  });

  @override
  Widget build(BuildContext context) {
    final weekNumbers = List.generate(
      WorkoutProvider.programCycleLengthWeeks,
      (index) => index + 1,
    );

    return SliverList.builder(
      itemCount: weekNumbers.length,
      itemBuilder: (context, index) {
        final weekNumber = weekNumbers[index];
        final cycleWeekWorkouts = workoutProvider.getWeekWorkouts(weekNumber);

        if (cycleWeekWorkouts.isEmpty) {
          return const SizedBox.shrink();
        }

        final startDateOfThisWeekInCycle = firstDayOfCurrentCycle.add(
          Duration(days: (weekNumber - 1) * 7),
        );

        return _WeekCard(
          key: ValueKey('week_$weekNumber'),
          weekNumber: weekNumber,
          cycleWeekWorkouts: cycleWeekWorkouts,
          workoutProvider: workoutProvider,
          startDateOfThisWeek: startDateOfThisWeekInCycle,
        );
      },
    );
  }
}

class _WorkoutStatus {
  final String text;
  final Color color;
  final IconData iconData;

  const _WorkoutStatus(this.text, this.color, this.iconData);

  static const completed = _WorkoutStatus(
    'Completed',
    Colors.green,
    Icons.check_circle,
  );
  static const restDay = _WorkoutStatus(
    'Rest Day',
    Color(0xFF64B5F6),
    Icons.check_circle_outline,
  );
  static const today = _WorkoutStatus(
    'Today',
    Color(0xFF1976D2),
    Icons.radio_button_unchecked,
  );
  static const upcoming = _WorkoutStatus(
    'Upcoming',
    Color(0xFF757575),
    Icons.radio_button_unchecked,
  );

  static _WorkoutStatus skipped = _WorkoutStatus(
    'Skipped',
    Colors.orange.shade700,
    Icons.cancel_outlined,
  );
  static _WorkoutStatus missed = _WorkoutStatus(
    'Missed',
    Colors.red.shade700,
    Icons.remove_circle_outline,
  );
}

class _WeekCard extends StatefulWidget {
  final int weekNumber;
  final List<Workout> cycleWeekWorkouts;
  final WorkoutProvider workoutProvider;
  final DateTime startDateOfThisWeek;

  const _WeekCard({
    super.key,
    required this.weekNumber,
    required this.cycleWeekWorkouts,
    required this.workoutProvider,
    required this.startDateOfThisWeek,
  });

  @override
  State<_WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends State<_WeekCard>
    with AutomaticKeepAliveClientMixin {
  late final DateTime _todayNormalized;
  late final double _weekProgress;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayNormalized = DateTime(now.year, now.month, now.day);
    _weekProgress = _calculateWeekProgress();
  }

  double _calculateWeekProgress() {
    if (widget.cycleWeekWorkouts.isEmpty) return 0.0;

    int completedInThisWeekInstance = 0;
    int countableWorkoutsInWeek = 0;

    for (final workout in widget.cycleWeekWorkouts) {
      if (workout.workoutType == 'workout' ||
          workout.workoutType == 'fit_test') {
        countableWorkoutsInWeek++;
        final dayOfWeek = (workout.dayNumber - 1) % 7;
        final actualDate = widget.startDateOfThisWeek.add(
          Duration(days: dayOfWeek),
        );
        final session = widget.workoutProvider.getSessionForDate(
          actualDate.toIso8601String().split('T')[0],
        );
        if (session?.completed == true) {
          completedInThisWeekInstance++;
        }
      }
    }

    return countableWorkoutsInWeek > 0
        ? (completedInThisWeekInstance / countableWorkoutsInWeek) * 100
        : 0.0;
  }

  Color get _circleAvatarColor {
    if (_weekProgress >= 100) return Colors.green;
    if (_weekProgress > 0) return Colors.orangeAccent;
    return Colors.redAccent.shade100;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ExpansionTile(
        key: PageStorageKey<int>(widget.weekNumber),
        title: Text(
          'Week ${widget.weekNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_weekProgress.toStringAsFixed(0)}% Completed',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        leading: CircleAvatar(
          backgroundColor: _circleAvatarColor,
          child: Text(
            '${widget.weekNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: widget.cycleWeekWorkouts.map((workout) {
          final dayOfWeek = (workout.dayNumber - 1) % 7;
          final actualWorkoutDate = widget.startDateOfThisWeek.add(
            Duration(days: dayOfWeek),
          );

          return _WorkoutListTile(
            key: ValueKey(
              '${workout.id}_${actualWorkoutDate.millisecondsSinceEpoch}',
            ),
            workout: workout,
            workoutProvider: widget.workoutProvider,
            actualWorkoutDate: actualWorkoutDate,
            todayNormalized: _todayNormalized,
          );
        }).toList(),
      ),
    );
  }
}

class _WorkoutListTile extends StatelessWidget {
  final Workout workout;
  final WorkoutProvider workoutProvider;
  final DateTime actualWorkoutDate;
  final DateTime todayNormalized;

  const _WorkoutListTile({
    super.key,
    required this.workout,
    required this.workoutProvider,
    required this.actualWorkoutDate,
    required this.todayNormalized,
  });

  _WorkoutStatus _getWorkoutStatus(
    WorkoutSession? session,
    DateTime normalizedActualDate,
  ) {
    if (session?.completed == true) {
      return _WorkoutStatus.completed;
    } else if (session != null && !session.completed) {
      return _WorkoutStatus.skipped;
    } else if (workout.workoutType == 'rest') {
      return _WorkoutStatus.restDay;
    } else if (normalizedActualDate.isBefore(todayNormalized)) {
      return _WorkoutStatus.missed;
    } else if (normalizedActualDate.isAtSameMomentAs(todayNormalized)) {
      return _WorkoutStatus.today;
    } else {
      return _WorkoutStatus.upcoming;
    }
  }

  Color _getWorkoutTypeChipColor(String workoutType) {
    switch (workoutType) {
      case 'fit_test':
        return Colors.purple.shade100;
      case 'rest':
        return Colors.blue.shade100;
      case 'workout':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateString = actualWorkoutDate.toIso8601String().split('T')[0];
    final session = workoutProvider.getSessionForDate(dateString);
    final normalizedActualDate = DateTime(
      actualWorkoutDate.year,
      actualWorkoutDate.month,
      actualWorkoutDate.day,
    );

    final status = _getWorkoutStatus(session, normalizedActualDate);
    final displayDate = UtilsProvider.formatMonthDay(actualWorkoutDate);

    return ListTile(
      leading: Icon(status.iconData, color: status.color),
      title: Text(workout.name),
      subtitle: Text('Day ${workout.dayNumber} • $displayDate'),
      trailing: _WorkoutTypeChip(
        workoutType: workout.workoutType,
        backgroundColor: _getWorkoutTypeChipColor(workout.workoutType),
      ),
      onTap: () => _showWorkoutDetailsDialog(
        context,
        workout,
        workoutProvider,
        session,
        actualWorkoutDate,
        todayNormalized,
        status,
      ),
    );
  }

  void _showWorkoutDetailsDialog(
    BuildContext context,
    Workout workout,
    WorkoutProvider workoutProvider,
    WorkoutSession? session,
    DateTime actualWorkoutDate,
    DateTime normalizedToday,
    _WorkoutStatus currentStatus,
  ) {
    final normalizedActualDate = DateTime(
      actualWorkoutDate.year,
      actualWorkoutDate.month,
      actualWorkoutDate.day,
    );
    final canModify =
        (normalizedActualDate.isAtSameMomentAs(normalizedToday) ||
            normalizedActualDate.isBefore(normalizedToday)) &&
        workoutProvider.programStartDate != null;

    final notesController = TextEditingController(text: session?.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(workout.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date: ${UtilsProvider.formatDateForDisplay(actualWorkoutDate)} (Day ${workout.dayNumber})',
              ),
              Text(
                'Type: ${workout.workoutType.replaceAll('_', ' ').toUpperCase()}',
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${currentStatus.text}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: currentStatus.color,
                ),
              ),
              const SizedBox(height: 16),
              if (canModify || (session?.notes?.isNotEmpty == true))
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Add any notes for this session...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  enabled: canModify,
                  textInputAction: TextInputAction.done,
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
            if (session?.completed != true)
              ElevatedButton(
                onPressed: () => _handleCompleteWorkout(
                  context,
                  dialogContext,
                  workoutProvider,
                  workout,
                  notesController.text,
                  actualWorkoutDate,
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Complete'),
              ),
            if (session?.completed == true ||
                (session == null &&
                    !normalizedActualDate.isAfter(normalizedToday)))
              OutlinedButton(
                onPressed: () => _handleSkipWorkout(
                  context,
                  dialogContext,
                  workoutProvider,
                  workout,
                  session,
                  notesController.text,
                  actualWorkoutDate,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: session?.completed == true
                      ? Colors.orange.shade700
                      : null,
                  side: session?.completed == true
                      ? BorderSide(color: Colors.orange.shade700)
                      : null,
                ),
                child: Text(
                  session?.completed == true ? 'Mark Not Done' : 'Skip Workout',
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleCompleteWorkout(
    BuildContext context,
    BuildContext dialogContext,
    WorkoutProvider workoutProvider,
    Workout workout,
    String notes,
    DateTime actualWorkoutDate,
  ) async {
    await workoutProvider.completeWorkout(
      workout.id,
      notes: notes,
      dateOverride: actualWorkoutDate,
    );

    if (!dialogContext.mounted) return;
    Navigator.pop(dialogContext);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${workout.name} marked as completed.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleSkipWorkout(
    BuildContext context,
    BuildContext dialogContext,
    WorkoutProvider workoutProvider,
    Workout workout,
    WorkoutSession? session,
    String notes,
    DateTime actualWorkoutDate,
  ) async {
    await workoutProvider.skipWorkout(
      workout.id,
      reason: notes,
      dateOverride: actualWorkoutDate,
    );

    if (!dialogContext.mounted) return;
    Navigator.pop(dialogContext);

    if (context.mounted) {
      final message = session?.completed == true
          ? '${workout.name} marked as not done.'
          : '${workout.name} marked as skipped.';
      final color = session?.completed == true
          ? Colors.orange
          : Colors.blueGrey;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
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
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
