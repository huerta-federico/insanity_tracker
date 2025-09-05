import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/workout_provider.dart';
import 'providers/fit_test_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => FitTestProvider()),
      ],
      child: MaterialApp(
        title: 'Insanity Tracker',
        theme: ThemeData(
          primarySwatch: Colors.red,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize providers when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutProvider>().initialize();
      context.read<FitTestProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insanity Tracker'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<WorkoutProvider, FitTestProvider>(
        builder: (context, workoutProvider, fitTestProvider, child) {
          if (workoutProvider.isLoading || fitTestProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Today's Workout Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Workout',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          workoutProvider.getTodaysWorkout()?.name ?? 'No workout scheduled',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _completeWorkout(context),
                              child: const Text('Complete'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _skipWorkout(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                              ),
                              child: const Text('Skip'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Progress Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Overall Progress: ${workoutProvider.getOverallProgress().toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fit Tests Completed: ${fitTestProvider.fitTests.length}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Database Test Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Database Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Workouts loaded: ${workoutProvider.workouts.length}'),
                        Text('Sessions logged: ${workoutProvider.sessions.length}'),
                        Text('Fit tests: ${fitTestProvider.fitTests.length}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _completeWorkout(BuildContext context) {
    final workoutProvider = context.read<WorkoutProvider>();
    final todaysWorkout = workoutProvider.getTodaysWorkout();

    if (todaysWorkout != null) {
      workoutProvider.completeWorkout(todaysWorkout.id, notes: 'Completed via home screen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Completed: ${todaysWorkout.name}')),
      );
    }
  }

  void _skipWorkout(BuildContext context) {
    final workoutProvider = context.read<WorkoutProvider>();
    final todaysWorkout = workoutProvider.getTodaysWorkout();

    if (todaysWorkout != null) {
      workoutProvider.skipWorkout(todaysWorkout.id, reason: 'Skipped via home screen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skipped: ${todaysWorkout.name}')),
      );
    }
  }
}