import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/workout_provider.dart';
import 'providers/fit_test_provider.dart';
import 'providers/start_date_provider.dart';
// Note: Removed UtilsProvider import since it's now used statically
import 'screens/home_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/fit_test_screen.dart';
import 'screens/progress_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // State management providers for workout and fit test data
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => FitTestProvider()),
        ChangeNotifierProvider(create: (_) => StartDateProvider()),
        // Removed UtilsProvider - it's now a static utility class, no instance needed
      ],
      child: MaterialApp(
        title: 'Insanity Tracker',
        theme: ThemeData(
          // Insanity-inspired red color scheme
          primarySwatch: Colors.red,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
        ),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Main screen with bottom navigation between the four primary screens
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // Current selected tab

  // List of screens for bottom navigation
  final List<Widget> _screens = [
    const HomeScreen(),
    const ScheduleScreen(),
    const FitTestScreen(),
    const ProgressScreen(),
  ];

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
      body: _screens[_currentIndex], // Display current screen
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Fit Test',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}