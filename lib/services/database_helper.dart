// lib/services/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kapture.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL DEFAULT 0';

    // Users table
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        username $textType,
        email $textType,
        profile_picture $textTypeNullable,
        photography_style $textType,
        skill_level $textType,
        days_per_week $intType,
        created_at $textType
      )
    ''');

    // Learning tracks/plans
    await db.execute('''
      CREATE TABLE tracks (
        id $idType,
        user_id $intType,
        name $textType,
        style $textType,
        level $textType,
        duration_days $intType,
        is_active $boolType,
        created_at $textType,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Daily challenges
    await db.execute('''
      CREATE TABLE challenges (
        id $idType,
        track_id $intType,
        day_number $intType,
        title $textType,
        description $textType,
        tips $textTypeNullable,
        completed $boolType,
        completed_at $textTypeNullable,
        FOREIGN KEY (track_id) REFERENCES tracks (id)
      )
    ''');

    // Sub-tasks for each challenge
    await db.execute('''
      CREATE TABLE subtasks (
        id $idType,
        challenge_id $intType,
        title $textType,
        description $textTypeNullable,
        order_index $intType,
        completed $boolType,
        FOREIGN KEY (challenge_id) REFERENCES challenges (id)
      )
    ''');

    // Photo submissions
    await db.execute('''
      CREATE TABLE submissions (
        id $idType,
        challenge_id $intType,
        photo_paths $textType,
        submitted_at $textTypeNullable,
        validated $boolType,
        FOREIGN KEY (challenge_id) REFERENCES challenges (id)
      )
    ''');

    // Feedback from cloud validation
    await db.execute('''
      CREATE TABLE feedback (
        id $idType,
        submission_id $intType,
        validation_result $textType,
        technical_notes $textTypeNullable,
        suggestions $textTypeNullable,
        created_at $textType,
        FOREIGN KEY (submission_id) REFERENCES submissions (id)
      )
    ''');

    // RAG knowledge chunks (optional - for reference)
    await db.execute('''
      CREATE TABLE knowledge_chunks (
        id $idType,
        source $textType,
        content $textType,
        chunk_index $intType
      )
    ''');

    // Chat history
    await db.execute('''
      CREATE TABLE chat_messages (
        id $idType,
        user_id $intType,
        role $textType,
        content $textType,
        created_at $textType,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}