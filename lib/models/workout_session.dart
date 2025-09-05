class WorkoutSession {
  final int? id;
  final int workoutId;
  final String date; // ISO date format (YYYY-MM-DD)
  final bool completed;
  final String? notes;

  WorkoutSession({
    this.id,
    required this.workoutId,
    required this.date,
    this.completed = false,
    this.notes,
  });

  // Convert from database map
  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'],
      workoutId: map['workout_id'],
      date: map['date'],
      completed: map['completed'] == 1, // SQLite stores booleans as integers
      notes: map['notes'],
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workout_id': workoutId,
      'date': date,
      'completed': completed ? 1 : 0, // Convert boolean to integer for SQLite
      'notes': notes,
    };
  }

  // Create a copy with some values changed
  WorkoutSession copyWith({
    int? id,
    int? workoutId,
    String? date,
    bool? completed,
    String? notes,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
    );
  }
}