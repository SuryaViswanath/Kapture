// lib/services/chat_service.dart

import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';

class ChatMessage {
  final int? id;
  final int userId;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime createdAt;

  ChatMessage({
    this.id,
    required this.userId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'role': role,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      userId: map['user_id'],
      role: map['role'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class ChatService {
  static final ChatService instance = ChatService._init();
  ChatService._init();

  // Get chat history
  Future<List<ChatMessage>> getChatHistory(int userId, {int limit = 50}) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'chat_messages',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return result.map((map) => ChatMessage.fromMap(map)).toList().reversed.toList();
  }

  // Save message
  Future<int> saveMessage(ChatMessage message) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('chat_messages', message.toMap());
  }

  // Clear chat history
  Future<void> clearHistory(int userId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'chat_messages',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}