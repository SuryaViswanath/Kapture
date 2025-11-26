// lib/models/challenge.dart

class Challenge {
  final int? id;
  final int trackId;
  final int dayNumber;
  final String title;
  final String description;
  final String? tips;
  final bool completed;
  final DateTime? completedAt;

  Challenge({
    this.id,
    required this.trackId,
    required this.dayNumber,
    required this.title,
    required this.description,
    this.tips,
    this.completed = false,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'track_id': trackId,
      'day_number': dayNumber,
      'title': title,
      'description': description,
      'tips': tips,
      'completed': completed ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory Challenge.fromMap(Map<String, dynamic> map) {
    return Challenge(
      id: map['id'],
      trackId: map['track_id'],
      dayNumber: map['day_number'],
      title: map['title'],
      description: map['description'],
      tips: map['tips'],
      completed: map['completed'] == 1,
      completedAt: map['completed_at'] != null 
          ? DateTime.parse(map['completed_at']) 
          : null,
    );
  }
}