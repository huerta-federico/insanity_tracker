import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/fit_test_provider.dart';
import '../providers/workout_provider.dart';
// import '../models/fit_test.dart';

/// Progress screen showing workout completion statistics and fit test improvements
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
      ),
      body: Consumer2<WorkoutProvider, FitTestProvider>(
        builder: (context, workoutProvider, fitTestProvider, child) {
          if (workoutProvider.isLoading || fitTestProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall stats card
                _buildOverallStatsCard(workoutProvider),

                const SizedBox(height: 16),

                // Fit test progress chart
                _buildFitTestProgressChart(fitTestProvider),

                const SizedBox(height: 16),

                // Workout completion chart
                _buildWorkoutCompletionChart(workoutProvider),

                const SizedBox(height: 16),

                // Improvement percentages
                _buildImprovementCard(fitTestProvider),

                const SizedBox(height: 16),

                // Detailed statistics
                _buildDetailedStatsCard(workoutProvider, fitTestProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Overall statistics card
  Widget _buildOverallStatsCard(WorkoutProvider workoutProvider) {
    final completedWorkouts = workoutProvider.sessions.where((s) => s.completed).length;
    final totalWorkouts = workoutProvider.workouts.where((w) => w.workoutType == 'workout').length;
    final overallProgress = workoutProvider.getOverallProgress();
    final thisWeekSessions = workoutProvider.getThisWeekSessions();
    final completedThisWeek = thisWeekSessions.where((s) => s.completed).length;

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
            const SizedBox(height: 16),

            // Progress bar
            LinearProgressIndicator(
              value: overallProgress / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              minHeight: 8,
            ),

            const SizedBox(height: 8),

            Text(
              '${overallProgress.toStringAsFixed(1)}% Complete',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // Stats grid
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Completed',
                    '$completedWorkouts',
                    'workouts',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'This Week',
                    '$completedThisWeek',
                    'workouts',
                    Icons.calendar_month,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    '$totalWorkouts',
                    'workouts',
                    Icons.fitness_center,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Fit test progress chart
  Widget _buildFitTestProgressChart(FitTestProvider fitTestProvider) {
    final fitTests = fitTestProvider.getAllResults();

    if (fitTests.length < 2) {
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
                fitTests.isEmpty
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
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < fitTests.length) {
                            return Text('Test ${index + 1}');
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: fitTests.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.totalReps.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.red.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Total Reps per Fit Test',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Workout completion chart
  Widget _buildWorkoutCompletionChart(WorkoutProvider workoutProvider) {
    final completedCount = workoutProvider.sessions.where((s) => s.completed).length;
    final skippedCount = workoutProvider.sessions.where((s) => !s.completed).length;
    final totalWorkouts = workoutProvider.workouts.where((w) => w.workoutType == 'workout').length;
    final remainingCount = totalWorkouts - completedCount - skippedCount;

    if (totalWorkouts == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workout Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    if (completedCount > 0)
                      PieChartSectionData(
                        value: completedCount.toDouble(),
                        title: 'Completed\n$completedCount',
                        color: Colors.green,
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (skippedCount > 0)
                      PieChartSectionData(
                        value: skippedCount.toDouble(),
                        title: 'Skipped\n$skippedCount',
                        color: Colors.orange,
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (remainingCount > 0)
                      PieChartSectionData(
                        value: remainingCount.toDouble(),
                        title: 'Remaining\n$remainingCount',
                        color: Colors.grey,
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
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

  /// Improvement percentages card
  Widget _buildImprovementCard(FitTestProvider fitTestProvider) {
    final improvements = fitTestProvider.getImprovementPercentages();

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

    // Sort improvements by percentage for better display
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
              return _buildImprovementItem(
                _getExerciseDisplayName(entry.key),
                entry.value,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Individual improvement item
  Widget _buildImprovementItem(String exerciseName, double improvement) {
    final isPositive = improvement > 0;
    final color = isPositive ? Colors.green : (improvement < 0 ? Colors.red : Colors.grey);
    final icon = isPositive ? Icons.trending_up : (improvement < 0 ? Icons.trending_down : Icons.trending_flat);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(exerciseName)),
          Text(
            '${improvement > 0 ? '+' : ''}${improvement.toStringAsFixed(1)}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Detailed statistics card
  Widget _buildDetailedStatsCard(WorkoutProvider workoutProvider, FitTestProvider fitTestProvider) {
    final fitTests = fitTestProvider.getAllResults();
    final latestFitTest = fitTestProvider.getLatestFitTest();
    final sessions = workoutProvider.sessions;

    // Calculate streak
    int currentStreak = _calculateCurrentStreak(sessions);

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

            _buildDetailedStatRow('Total Fit Tests', '${fitTests.length}'),
            _buildDetailedStatRow('Current Streak', '$currentStreak days'),

            if (latestFitTest != null) ...[
              _buildDetailedStatRow('Latest Total Reps', '${latestFitTest.totalReps}'),
              _buildDetailedStatRow('Last Fit Test', _formatDate(latestFitTest.testDate)),
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
                return _buildDetailedStatRow(
                    improvement['exercise'] ?? 'Unknown',
                    improvement['improvement'] ?? '0%'
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// Individual detailed stat row
  Widget _buildDetailedStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Individual stat item widget
  Widget _buildStatItem(String label, String value, String unit, IconData icon, Color color) {
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

  /// Calculate current workout streak
  int _calculateCurrentStreak(List<dynamic> sessions) {
    if (sessions.isEmpty) return 0;

    // Sort sessions by date (most recent first)
    final sortedSessions = sessions.toList()
      ..sort((a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));

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

  /// Get best improvements for display
  List<Map<String, String>> _getBestImprovements(FitTestProvider fitTestProvider) {
    final improvements = fitTestProvider.getImprovementPercentages();

    if (improvements.isEmpty) return [];

    final sortedImprovements = improvements.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedImprovements.take(3).map((entry) {
      return {
        'exercise': _getExerciseDisplayName(entry.key),
        'improvement': '${entry.value > 0 ? '+' : ''}${entry.value.toStringAsFixed(1)}%',
      };
    }).toList();
  }

  /// Convert exercise key to display name
  String _getExerciseDisplayName(String key) {
    switch (key) {
      case 'switchKicks':
        return 'Switch Kicks';
      case 'powerJacks':
        return 'Power Jacks';
      case 'powerKnees':
        return 'Power Knees';
      case 'powerJumps':
        return 'Power Jumps';
      case 'globeJumps':
        return 'Globe Jumps';
      case 'suicideJumps':
        return 'Suicide Jumps';
      case 'pushupJacks':
        return 'Pushup Jacks';
      case 'lowPlankOblique':
        return 'Low Plank Oblique';
      default:
        return key;
    }
  }

  /// Format date string for display
  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}