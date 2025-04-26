// lib/models/pulse_entry.dart

class PulseEntry {
  final int pulseRating;        // 1–5
  final String gratitudeNote;   // optional
  final int taskGoal;           // defaults to 5
  final String freeReflection;  // optional
  final DateTime dateLogged;    // auto-filled

  PulseEntry({
    required this.pulseRating,
    this.gratitudeNote = '',
    this.taskGoal = 5,
    this.freeReflection = '',
    DateTime? dateLogged,
  }) : dateLogged = dateLogged ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'pulseRating': pulseRating,
        'gratitudeNote': gratitudeNote,
        'taskGoal': taskGoal,
        'freeReflection': freeReflection,
        'dateLogged': dateLogged.toIso8601String(),
      };

  factory PulseEntry.fromJson(Map<String, dynamic> json) => PulseEntry(
        pulseRating: json['pulseRating'],
        gratitudeNote: json['gratitudeNote'] ?? '',
        taskGoal: json['taskGoal'] ?? 5,
        freeReflection: json['freeReflection'] ?? '',
        dateLogged: DateTime.parse(json['dateLogged']),
      );
}
