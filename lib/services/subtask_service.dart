// lib/services/subtask_service.dart

import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import '../models/subtask.dart';

class SubtaskService {
  static final SubtaskService instance = SubtaskService._init();
  SubtaskService._init();

  // Get subtasks for a challenge
  Future<List<Subtask>> getChallengeSubtasks(int challengeId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'subtasks',
      where: 'challenge_id = ?',
      whereArgs: [challengeId],
      orderBy: 'order_index ASC',
    );
    
    return result.map((map) => Subtask.fromMap(map)).toList();
  }

  // Toggle subtask completion
  Future<void> toggleSubtask(int subtaskId, bool completed) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'subtasks',
      {'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [subtaskId],
    );
  }

  // Check if all subtasks are completed
  Future<bool> areAllSubtasksCompleted(int challengeId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total, SUM(completed) as completed FROM subtasks WHERE challenge_id = ?',
      [challengeId],
    );
    
    if (result.isEmpty) return false;
    final total = result.first['total'] as int;
    final completed = result.first['completed'] as int? ?? 0;
    
    return total > 0 && total == completed;
  }
}