class FitTest {
  final int? id;
  final String testDate; // ISO date format (YYYY-MM-DD)
  final int testNumber; // 1st, 2nd, 3rd, etc.
  final int switchKicks;
  final int powerJacks;
  final int powerKnees;
  final int powerJumps;
  final int globeJumps;
  final int suicideJumps;
  final int pushupJacks;
  final int lowPlankOblique;
  final String? notes;

  FitTest({
    this.id,
    required this.testDate,
    required this.testNumber,
    required this.switchKicks,
    required this.powerJacks,
    required this.powerKnees,
    required this.powerJumps,
    required this.globeJumps,
    required this.suicideJumps,
    required this.pushupJacks,
    required this.lowPlankOblique,
    this.notes,
  });

  // Convert from database map
  factory FitTest.fromMap(Map<String, dynamic> map) {
    return FitTest(
      id: map['id'],
      testDate: map['test_date'],
      testNumber: map['test_number'],
      switchKicks: map['switch_kicks'],
      powerJacks: map['power_jacks'],
      powerKnees: map['power_knees'],
      powerJumps: map['power_jumps'],
      globeJumps: map['globe_jumps'],
      suicideJumps: map['suicide_jumps'],
      pushupJacks: map['pushup_jacks'],
      lowPlankOblique: map['low_plank_oblique'],
      notes: map['notes'],
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'test_date': testDate,
      'test_number': testNumber,
      'switch_kicks': switchKicks,
      'power_jacks': powerJacks,
      'power_knees': powerKnees,
      'power_jumps': powerJumps,
      'globe_jumps': globeJumps,
      'suicide_jumps': suicideJumps,
      'pushup_jacks': pushupJacks,
      'low_plank_oblique': lowPlankOblique,
      'notes': notes,
    };
  }

  // Get total reps for overall progress tracking
  int get totalReps {
    return switchKicks + powerJacks + powerKnees + powerJumps +
        globeJumps + suicideJumps + pushupJacks + lowPlankOblique;
  }
}