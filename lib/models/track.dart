// lib/models/track.dart

class Track {
  final int? id;
  final int userId;
  final String name;
  final String style;
  final String level;
  final int durationDays;
  final bool isActive;
  final DateTime createdAt;

  Track({
    this.id,
    required this.userId,
    required this.name,
    required this.style,
    required this.level,
    required this.durationDays,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'style': style,
      'level': level,
      'duration_days': durationDays,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      style: map['style'],
      level: map['level'],
      durationDays: map['duration_days'],
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}