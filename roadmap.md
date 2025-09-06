# Insanity Workout Tracker - CS50x Final Project Roadmap

## Project Scope (Revised for CS50x)
A focused Flutter mobile app for tracking the Insanity Workout program. The MVP will demonstrate core programming concepts: database management, state management, user interface design, and data persistence.

## Core Features (MVP)
1. **Workout Schedule Display** - Show the 60-day Insanity calendar
2. **Workout Logging** - Mark workouts as completed/skipped with notes
3. **Fit Test Tracking** - Input and track fit test results over time
4. **Basic Progress View** - Simple charts showing improvement
5. **Data Persistence** - All data saved locally with SQLite

## Technical Architecture

### Tech Stack
- **Framework:** Flutter 3.x
- **Database:** SQLite (sqflite package)
- **State Management:** Provider pattern
- **Charts:** fl_chart package

### Simplified Project Structure
```
lib/
├── main.dart
├── models/
│   ├── workout.dart
│   ├── workout_session.dart
│   └── fit_test.dart
├── providers/
│   ├── workout_provider.dart
│   └── fit_test_provider.dart
├── screens/
│   ├── home_screen.dart
│   ├── schedule_screen.dart
│   ├── fit_test_screen.dart
│   └── progress_screen.dart
├── services/
│   └── database_service.dart
└── data/
    └── insanity_schedule.dart
```

## Development Timeline (3-4 Weeks)

### Week 1: Foundation & Setup
**Goal:** Working app with basic navigation and database

**Day 1-2: Environment Setup**
- Install Flutter SDK and Android Studio
- Create new Flutter project
- Set up basic navigation between 4 main screens
- Apply simple Material Design theme

**Day 3-4: Database Foundation**
- Set up SQLite database with 3 tables:
  ```sql
  -- Static workout data
  CREATE TABLE workouts (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    day_number INTEGER,
    week_number INTEGER,
    workout_type TEXT -- 'workout', 'fit_test', 'rest'
  );
  
  -- User workout sessions
  CREATE TABLE workout_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    workout_id INTEGER,
    date TEXT,
    completed BOOLEAN DEFAULT 0,
    notes TEXT,
    FOREIGN KEY (workout_id) REFERENCES workouts (id)
  );
  
  -- Fit test results
  CREATE TABLE fit_test_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    test_date TEXT,
    switch_kicks INTEGER,
    power_jacks INTEGER,
    power_knees INTEGER,
    power_jumps INTEGER,
    globe_jumps INTEGER,
    suicide_jumps INTEGER,
    pushup_jacks INTEGER,
    low_plank_oblique INTEGER
  );
  ```

**Day 5-7: Basic Models & State Management**
- Create Workout, WorkoutSession, and FitTest model classes
- Implement basic Provider classes for state management
- Populate database with Insanity 60-day schedule data
- Test CRUD operations work correctly

### Week 2: Core Functionality
**Goal:** Working workout tracking and fit test input

**Day 1-3: Home & Schedule Screens**
- **Home Screen:** 
  - Show today's scheduled workout
  - Display current week number and day
  - Show basic stats (workouts completed this week)
  - Quick "Complete Workout" and "Skip Workout" buttons

- **Schedule Screen:**
  - 60-day calendar view (simple list or grid)
  - Visual indicators for completed/skipped/upcoming workouts
  - Tap workout to view details or mark complete
  - Show rest days and fit test days clearly

**Day 4-7: Workout Session Management**
- Implement workout completion flow
- Add ability to mark workout as completed with optional notes
- Add ability to mark workout as skipped with reason
- Update schedule view to reflect completion status
- Basic validation and error handling

### Week 3: Fit Test & Progress
**Goal:** Fit test tracking with basic progress visualization

**Day 1-4: Fit Test Screen**
- Create form for 8 Insanity exercises with number inputs
- Add simple timer display (optional - can be basic countdown)
- Save fit test results to database
- Show previous results for comparison
- Basic input validation (positive numbers only)

**Day 5-7: Progress Screen**
- Simple line chart showing fit test improvements over time
- Basic statistics:
  - Total workouts completed
  - Current completion percentage
  - Days since program start
  - Next fit test due date
- List view of all fit test results with dates

### Week 4: Polish & Testing
**Goal:** Bug fixes, testing, and final presentation prep

**Day 1-3: UI Polish**
- Consistent styling across all screens
- Better visual hierarchy and spacing
- Loading states for database operations
- Error handling for edge cases
- Basic form validation

**Day 4-5: Testing & Bug Fixes**
- Test on physical Android device
- Test database operations (create, read, update)
- Test app lifecycle (closing/reopening app)
- Fix any crashes or data loss issues
- Test with missing data scenarios

**Day 6-7: Documentation & Submission Prep**
- Write README.md with project description
- Document how to run the app
- Create brief demo video showing key features
- Code cleanup and comments
- Final testing

## Simplified Database Schema

```sql
-- Only essential tables for MVP
CREATE TABLE workouts (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  day_number INTEGER, -- 1-60
  week_number INTEGER, -- 1-9
  workout_type TEXT CHECK(workout_type IN ('workout', 'fit_test', 'rest'))
);

CREATE TABLE workout_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  workout_id INTEGER,
  date TEXT, -- ISO date format
  completed BOOLEAN DEFAULT 0,
  notes TEXT,
  FOREIGN KEY (workout_id) REFERENCES workouts (id)
);

CREATE TABLE fit_test_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  test_date TEXT,
  switch_kicks INTEGER,
  power_jacks INTEGER,
  power_knees INTEGER,
  power_jumps INTEGER,
  globe_jumps INTEGER,
  suicide_jumps INTEGER,
  pushup_jacks INTEGER,
  low_plank_oblique INTEGER
);
```

## Key Classes (Simplified)

### WorkoutProvider
```dart
class WorkoutProvider extends ChangeNotifier {
  List<Workout> _workouts = [];
  List<WorkoutSession> _sessions = [];
  
  // Essential methods only
  Future<void> loadWorkouts();
  Future<void> completeWorkout(int workoutId, String? notes);
  Future<void> skipWorkout(int workoutId, String? reason);
  Workout? getTodaysWorkout();
  List<WorkoutSession> getThisWeekSessions();
  double getOverallProgress(); // Simple percentage calculation
}
```

### FitTestProvider
```dart
class FitTestProvider extends ChangeNotifier {
  List<FitTestResult> _results = [];
  
  Future<void> saveFitTest(FitTestResult result);
  List<FitTestResult> getAllResults();
  FitTestResult? getMostRecent();
  bool isNextTestDue(DateTime programStart);
}
```

## Success Criteria (MVP)

### Functional Requirements
- ✅ Display complete 60-day Insanity schedule
- ✅ Mark workouts as completed or skipped
- ✅ Save and retrieve workout session data
- ✅ Input and track fit test results
- ✅ Show basic progress charts
- ✅ Data persists between app sessions

### Technical Requirements
- ✅ Proper separation of concerns (models, providers, screens)
- ✅ Working SQLite database with relationships
- ✅ State management using Provider pattern
- ✅ Error handling for database operations
- ✅ Clean, readable code with comments
- ✅ Works on Android device

### CS50x Demonstration Points
- **Problem Solving:** Addresses real-world fitness tracking need
- **Database Design:** Proper relational database with foreign keys
- **Object-Oriented Programming:** Models and provider classes
- **User Interface:** Mobile-first responsive design
- **Data Persistence:** SQLite integration
- **State Management:** Modern Flutter patterns

## What's NOT Included in MVP (Future Enhancements)
- Push notifications
- Data export/backup
- Advanced analytics
- Customizable schedules
- Social features
- Cloud synchronization
- Advanced animations
- Calendar integration

## Estimated Time Investment
- **Total:** 25-35 hours over 3-4 weeks
- **Week 1:** 8-10 hours (setup and foundation)
- **Week 2:** 10-12 hours (core features)
- **Week 3:** 8-10 hours (fit test and progress)
- **Week 4:** 4-6 hours (polish and testing)

This scope is much more realistic for a CS50x final project while still demonstrating solid programming skills and creating something genuinely useful!