// lib/models/user.dart

class User {
  final int? id;
  final String username;
  final String email;
  final String? profilePicture;
  final List<String> photographyStyles;  // Changed to List
  final String skillLevel;
  final int daysPerWeek;
  final DateTime createdAt;

  User({
    this.id,
    required this.username,
    required this.email,
    this.profilePicture,
    required this.photographyStyles,
    required this.skillLevel,
    required this.daysPerWeek,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'profile_picture': profilePicture,
      'photography_style': photographyStyles.join(','),  // Store as comma-separated
      'skill_level': skillLevel,
      'days_per_week': daysPerWeek,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      profilePicture: map['profile_picture'],
      photographyStyles: (map['photography_style'] as String).split(','),  // Parse back to list
      skillLevel: map['skill_level'],
      daysPerWeek: map['days_per_week'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}