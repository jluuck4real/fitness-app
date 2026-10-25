class WorkoutHistoryModel {
  final int? id;
  final String workoutName;
  final int duration;
  final int calories;
  final String date;

  WorkoutHistoryModel({
    this.id,
    required this.workoutName,
    required this.duration,
    required this.calories,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutName': workoutName,
      'duration': duration,
      'calories': calories,
      'date': date,
    };
  }

  factory WorkoutHistoryModel.fromMap(Map<String, dynamic> map) {
    return WorkoutHistoryModel(
      id: map['id'] as int?,
      workoutName: map['workoutName'] as String,
      duration: map['duration'] as int,
      calories: map['calories'] as int,
      date: map['date'] as String,
    );
  }
}
