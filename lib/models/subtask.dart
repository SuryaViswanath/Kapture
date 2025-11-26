// lib/models/subtask.dart

class Subtask {
  final int? id;
  final int challengeId;
  final String title;
  final String? description;
  final int orderIndex;
  final bool completed;

  Subtask({
    this.id,
    required this.challengeId,
    required this.title,
    this.description,
    required this.orderIndex,
    this.completed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'challenge_id': challengeId,
      'title': title,
      'description': description,
      'order_index': orderIndex,
      'completed': completed ? 1 : 0,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'],
      challengeId: map['challenge_id'],
      title: map['title'],
      description: map['description'],
      orderIndex: map['order_index'],
      completed: map['completed'] == 1,
    );
  }
}