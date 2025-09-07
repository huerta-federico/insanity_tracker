import 'package:flutter/material.dart';
import 'package:insanity_tracker/providers/start_date_provider.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/fit_test_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/utils_provider.dart';

/// Progress screen showing workout completion statistics and fit test improvements
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  // Cache expensive computations
  Map<String, dynamic>? _cachedProgressData;
  Map<String, double>? _cachedImprovements;
  List<dynamic>? _cachedFitTests;
  Map<String, int>? _cachedCycleStats;
  int? _cachedStreak;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: Consumer2<WorkoutProvider, FitTestProvider>(
        builder: (context, workoutProvider, fitTestProvider, child) {
          if (workoutProvider.isLoading || fitTestProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Cache computations to avoid recalculating on every build
          _updateCachedData(workoutProvider, fitTestProvider);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OverallStatsCard(
                  workoutProvider: workoutProvider,
                  progressData: _cachedProgressData!,
                ),
                const SizedBox(height: 16),
                _FitTestProgressChart(fitTests: _cachedFitTests!),
                const SizedBox(height: 16),
                _WorkoutCompletionChart(cycleStats: _cachedCycleStats!),
                const SizedBox(height: 16),
                _ImprovementCard(improvements: _cachedImprovements!),
                const SizedBox(height: 16),
                _DetailedStatsCard(
                  fitTests: _cachedFitTests!,
                  fitTestProvider: fitTestProvider,
                  currentStreak: _cachedStreak!,
                ),
                if (workoutProvider.programStartDate != null)
                  _StartDateDisplay(workoutProvider: workoutProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateCachedData(
    WorkoutProvider workoutProvider,
    FitTestProvider fitTestProvider,
  ) {
    _cachedProgressData = {
      ...workoutProvider.getOverallProgress(),
      'completedWorkouts': workoutProvider.sessions
          .where((s) => s.completed)
          .length,
      'totalWorkoutsInCycle': workoutProvider.workouts
          .where(
            (w) => w.workoutType == 'workout' || w.workoutType == 'fit_test',
          )
          .length,
      'thisWeekCompleted': workoutProvider
          .getThisWeekSessions()
          .where((s) => s.completed)
          .length,
    };

    _cachedFitTests = fitTestProvider.getAllResults();
    _cachedImprovements = fitTestProvider.getImprovementPercentages();
    _cachedCycleStats = workoutProvider.getCurrentCycleSessionStats();
    _cachedStreak = _calculateCurrentStreak(workoutProvider.sessions);
  }

  int _calculateCurrentStreak(List<dynamic> sessions) {
    if (sessions.isEmpty) return 0;

    final sortedSessions = List.from(
      sessions,
    )..sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));

    int streak = 0;
    DateTime? lastDate;

    for (var session in sortedSessions) {
      if (!session.completed) break;

      final sessionDate = DateTime.parse(session.date);

      if (lastDate == null) {
        lastDate = sessionDate;
        streak = 1;
      } else {
        final daysDifference = lastDate.difference(sessionDate).inDays;
        if (daysDifference == 1) {
          streak++;
          lastDate = sessionDate;
        } else {
          break;
        }
      }
    }

    return streak;
  }
}

// Separate widget classes to prevent unnecessary rebuilds

class _OverallStatsCard extends StatelessWidget {
  final WorkoutProvider workoutProvider;
  final Map<String, dynamic> progressData;

  const _OverallStatsCard({
    required this.workoutProvider,
    required this.progressData,
  });

  @override
  Widget build(BuildContext context) {
    final completedWorkouts = progressData['completedWorkouts'] as int;
    final totalWorkoutsInCycle = progressData['totalWorkoutsInCycle'] as int;
    final currentCycleProgress =
        (progressData['currentCycleProgress'] as double?) ?? 0.0;
    final completedCycles =
        ((progressData['completedCycles'] as double?) ?? 0.0).toInt();
    final completedThisWeek = progressData['thisWeekCompleted'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (completedCycles > 0)
              Text(
                'Completed Cycles: $completedCycles',
                style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
              ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: totalWorkoutsInCycle > 0
                  ? (currentCycleProgress / 100)
                  : 0.0,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              'Current Cycle: ${currentCycleProgress.toStringAsFixed(1)}% Complete',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Total workouts',
                    value: '$completedWorkouts',
                    unit: 'workouts',
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'This Week',
                    value: '$completedThisWeek',
                    unit: 'workouts',
                    icon: Icons.calendar_month,
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Per Cycle',
                    value: '$totalWorkoutsInCycle',
                    unit: 'workouts',
                    icon: Icons.fitness_center,
                    color: Colors.orange,
                  ),
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
  final String unit;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FitTestProgressChart extends StatefulWidget {
  final List<dynamic> fitTests;

  const _FitTestProgressChart({required this.fitTests});

  @override
  State<_FitTestProgressChart> createState() => _FitTestProgressChartState();
}

class _FitTestProgressChartState extends State<_FitTestProgressChart> {
  LineChartData? _cachedChartData;
  List<dynamic>? _lastFitTests;

  @override
  Widget build(BuildContext context) {
    if (widget.fitTests.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Fit Test Progress',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.show_chart, size: 64, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                widget.fitTests.isEmpty
                    ? 'Complete your first fit test to see progress'
                    : 'Complete another fit test to see progress chart',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Cache chart data to avoid recalculation
    if (_cachedChartData == null || _lastFitTests != widget.fitTests) {
      _cachedChartData = _buildChartData();
      _lastFitTests = widget.fitTests;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fit Test Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: LineChart(_cachedChartData!)),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.center,
              child: Text(
                'Total Reps per Fit Test',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData() {
    double labelInterval = 1.0;
    const maxLabelsToShow = 5;
    if (widget.fitTests.length > maxLabelsToShow) {
      labelInterval = (widget.fitTests.length / maxLabelsToShow).ceilToDouble();
    }
    double calculatedMaxX = (widget.fitTests.length - 1).toDouble();
    double maxXPadding = widget.fitTests.isNotEmpty ? 0.5 : 0.0;

    return LineChartData(
      gridData: const FlGridData(show: true),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 40),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: labelInterval,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();

              // --- Start of refined logic ---
              // Only show titles that correspond to an actual data point index.
              if (index >= 0 && index < widget.fitTests.length) {
                // Ensure 'value' closely matches an actual data point's x-coordinate (which is 'index').
                // This helps avoid rendering labels for interpolated title positions near maxX.
                if ((value - index).abs() < 0.01) {
                  // Check if 'value' is very close to an integer 'index'
                  if (index % labelInterval.toInt() == 0 ||
                      labelInterval == 1.0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Test ${widget.fitTests[index].testNumber}'),
                    );
                  }
                }
              }
              // --- End of refined logic ---
              return const SizedBox.shrink(); // Return empty for all other cases
            },
            reservedSize: 30,
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: true),
      lineBarsData: [
        LineChartBarData(
          spots: widget.fitTests.asMap().entries.map((entry) {
            return FlSpot(
              entry.key.toDouble(),
              entry.value.totalReps.toDouble(),
            );
          }).toList(),
          isCurved: true,
          color: Colors.red,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.red.withAlpha(30),
          ),
        ),
      ],
      minX: 0,
      maxX: calculatedMaxX + maxXPadding,
    );
  }
}

class _WorkoutCompletionChart extends StatelessWidget {
  final Map<String, int> cycleStats;

  const _WorkoutCompletionChart({required this.cycleStats});

  @override
  Widget build(BuildContext context) {
    final completedInCycle = cycleStats['completed'] ?? 0;
    final skippedInCycle = cycleStats['skipped'] ?? 0;
    final remainingInCycle = cycleStats['remaining'] ?? 0;
    final totalWorkoutsInCycle = cycleStats['totalInCycle'] ?? 0;

    if (totalWorkoutsInCycle == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Current Cycle Workout Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('No workout data available for the cycle.'),
            ],
          ),
        ),
      );
    }

    final chartSections = <PieChartSectionData>[];

    if (completedInCycle > 0) {
      chartSections.add(
        PieChartSectionData(
          value: completedInCycle.toDouble(),
          title: 'Completed\n$completedInCycle',
          color: Colors.green,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (skippedInCycle > 0) {
      chartSections.add(
        PieChartSectionData(
          value: skippedInCycle.toDouble(),
          title: 'Skipped\n$skippedInCycle',
          color: Colors.orange,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (remainingInCycle > 0) {
      chartSections.add(
        PieChartSectionData(
          value: remainingInCycle.toDouble(),
          title: 'Remaining\n$remainingInCycle',
          color: Colors.blueGrey,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    // Handle empty state
    if (chartSections.isEmpty && totalWorkoutsInCycle > 0) {
      chartSections.add(
        PieChartSectionData(
          value: totalWorkoutsInCycle.toDouble(),
          title: 'Remaining\n$totalWorkoutsInCycle',
          color: Colors.blueGrey,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
            const Text(
              'Current Cycle Workout Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: chartSections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImprovementCard extends StatelessWidget {
  final Map<String, double> improvements;

  const _ImprovementCard({required this.improvements});

  @override
  Widget build(BuildContext context) {
    if (improvements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Exercise Improvements',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.trending_up, size: 64, color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'Complete multiple fit tests to see improvements',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final sortedImprovements = improvements.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exercise Improvements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...sortedImprovements.map((entry) {
              return _ImprovementItem(
                exerciseName: _ExerciseNames.getDisplayName(entry.key),
                improvement: entry.value,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ImprovementItem extends StatelessWidget {
  final String exerciseName;
  final double improvement;

  const _ImprovementItem({
    required this.exerciseName,
    required this.improvement,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = improvement > 0;
    final color = isPositive
        ? Colors.green
        : (improvement < 0 ? Colors.red : Colors.grey);
    final icon = isPositive
        ? Icons.trending_up
        : (improvement < 0 ? Icons.trending_down : Icons.trending_flat);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(exerciseName)),
          Text(
            '${improvement > 0 ? '+' : ''}${improvement.toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _DetailedStatsCard extends StatelessWidget {
  final List<dynamic> fitTests;
  final FitTestProvider fitTestProvider;
  final int currentStreak;

  const _DetailedStatsCard({
    required this.fitTests,
    required this.fitTestProvider,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    final latestFitTest = fitTestProvider.getLatestFitTest();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _DetailedStatRow(
              label: 'Total Fit Tests',
              value: '${fitTests.length}',
            ),
            _DetailedStatRow(
              label: 'Current Streak',
              value: '$currentStreak days',
            ),
            if (latestFitTest != null) ...[
              _DetailedStatRow(
                label: 'Latest Total Reps',
                value: '${latestFitTest.totalReps}',
              ),
              _DetailedStatRow(
                label: 'Last Fit Test',
                value: _DateFormatter.format(latestFitTest.testDate),
              ),
            ],
            if (fitTests.length >= 2) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Best Improvements',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._getBestImprovements(fitTestProvider).map((improvement) {
                return _DetailedStatRow(
                  label: improvement['exercise'] ?? 'Unknown',
                  value: improvement['improvement'] ?? '0%',
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _getBestImprovements(
    FitTestProvider fitTestProvider,
  ) {
    final improvements = fitTestProvider.getImprovementPercentages();

    if (improvements.isEmpty) return [];

    final sortedImprovements = improvements.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedImprovements.take(3).map((entry) {
      return {
        'exercise': _ExerciseNames.getDisplayName(entry.key),
        'improvement':
            '${entry.value > 0 ? '+' : ''}${entry.value.toStringAsFixed(1)}%',
      };
    }).toList();
  }
}

class _DetailedStatRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailedStatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StartDateDisplay extends StatelessWidget {
  final WorkoutProvider workoutProvider;

  const _StartDateDisplay({required this.workoutProvider});

  @override
  Widget build(BuildContext context) {
    final startDateProvider = StartDateProvider();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Program Started:', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            UtilsProvider.formatDate(
              UtilsProvider.formatDateForDisplay(
                workoutProvider.programStartDate,
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 20, color: Colors.grey[600]),
            tooltip: 'Change Start Date',
            onPressed: () => startDateProvider.pickProgramStartDate(
              context,
              workoutProvider,
            ),
          ),
        ],
      ),
    );
  }
}

// Utility classes for better organization
class _ExerciseNames {
  static const Map<String, String> _displayNames = {
    'switchKicks': 'Switch Kicks',
    'powerJacks': 'Power Jacks',
    'powerKnees': 'Power Knees',
    'powerJumps': 'Power Jumps',
    'globeJumps': 'Globe Jumps',
    'suicideJumps': 'Suicide Jumps',
    'pushupJacks': 'Pushup Jacks',
    'lowPlankOblique': 'Low Plank Oblique',
  };

  static String getDisplayName(String key) {
    return _displayNames[key] ?? key;
  }
}

class _DateFormatter {
  static const List<String> _months = [
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

  static String format(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }
}
