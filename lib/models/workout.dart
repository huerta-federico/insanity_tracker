class Workout {
  final int id;
  final String name;
  final int dayNumber;
  final int weekNumber;
  final String workoutType; // 'workout', 'fit_test', 'rest'

  Workout({
    required this.id,
    required this.name,
    required this.dayNumber,
    required this.weekNumber,
    required this.workoutType,
  });

  // Convert from database map
  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'],
      name: map['name'],
      dayNumber: map['day_number'],
      weekNumber: map['week_number'],
      workoutType: map['workout_type'],
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'day_number': dayNumber,
      'week_number': weekNumber,
      'workout_type': workoutType,
    };
  }
}
