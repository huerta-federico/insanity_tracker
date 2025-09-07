// lib/models/fit_test.dart
class FitTest {
  final int? id; // Nullable for new tests not yet in DB
  final String testDate; // ISO date format (YYYY-MM-DD)
  final int testNumber; // This will be the chronologically accurate number
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
    required this.testNumber, // Ensure this is always provided
    required this.switchKicks,
    required this.powerJacks,
    required this.powerKnees,
    required this.powerJumps,
    required this.globeJumps,
    required this.suicideJumps,
    required this.pushupJacks,    required this.lowPlankOblique,
    this.notes,
  });

  factory FitTest.fromMap(Map<String, dynamic> map) {
    return FitTest(
      id: map['id'],
      testDate: map['test_date'],
      // The test_number from the DB is used here, but the provider will re-evaluate it.
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

  Map<String, dynamic> toMap() {
    // Create a new map to avoid modifying the original if it was from a state object
    final map = <String, dynamic>{
      // 'id' is not included if null (for new inserts, DB handles it)
      'test_date': testDate,
      'test_number': testNumber, // This is the provisional number for new inserts
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
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  int get totalReps {
    return switchKicks + powerJacks + powerKnees + powerJumps +
        globeJumps + suicideJumps + pushupJacks + lowPlankOblique;
  }

  // Optional: copyWith for easier manipulation if needed,
  // though the provider re-creates objects during renumbering.
  FitTest copyWith({
    int? id,
    String? testDate,
    int? testNumber,
    int? switchKicks,
    int? powerJacks,
    int? powerKnees,
    int? powerJumps,
    int? globeJumps,
    int? suicideJumps,
    int? pushupJacks,
    int? lowPlankOblique,
    String? notes,
    bool allowNullNotes = false, // To explicitly set notes to null
  }) {
    return FitTest(
      id: id ?? this.id,
      testDate: testDate ?? this.testDate,
      testNumber: testNumber ?? this.testNumber,
      switchKicks: switchKicks ?? this.switchKicks,
      powerJacks: powerJacks ?? this.powerJacks,
      powerKnees: powerKnees ?? this.powerKnees,
      powerJumps: powerJumps ?? this.powerJumps,
      globeJumps: globeJumps ?? this.globeJumps,
      suicideJumps: suicideJumps ?? this.suicideJumps,
      pushupJacks: pushupJacks ?? this.pushupJacks,
      lowPlankOblique: lowPlankOblique ?? this.lowPlankOblique,
      notes: allowNullNotes ? notes : (notes ?? this.notes),
    );
  }
}
