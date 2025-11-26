// lib/services/learning_manager.dart - CORRECTED

import 'dart:convert';
import 'package:cactus/cactus.dart';
import '../services/database_helper.dart';
import '../models/track.dart';
import '../models/challenge.dart';
import '../models/subtask.dart';

class LearningManager {
  static final LearningManager instance = LearningManager._init();
  LearningManager._init();

  final CactusLM _llm = CactusLM();
  
  // Add this test method to learning_manager.dart temporarily

  Future<void> checkModelStatus() async {
    try {
        final models = await _llm.getModels();
        for (var model in models) {
        print('Model: ${model.name}');
        print('Slug: ${model.slug}');
        print('Downloaded: ${model.isDownloaded}');
        print('---');
        }
    } catch (e) {
        print('Error checking models: $e');
    }
    }

  // Initialize Cactus LLM
  Future<void> initialize() async {
    try {
      // Download model if not already downloaded
      await _llm.downloadModel(
        model: "qwen3-0.6",  // Use the model slug
        downloadProcessCallback: (progress, status, isError) {
          if (isError) {
            print('❌ Download error: $status');
          } else {
            print('📥 $status ${progress != null ? '(${(progress * 100).toInt()}%)' : ''}');
          }
        },
      );

      // Initialize the model
      await _llm.initializeModel(
        params: CactusInitParams(
          model: "qwen3-0.6",
          contextSize: 2048,
        ),
      );

      print('✅ Cactus LLM initialized successfully');
    } catch (e) {
      print('❌ Error initializing LLM: $e');
      rethrow;
    }
  }

  // Generate learning plan
  Future<Map<String, dynamic>> generatePlan({
    required int userId,
    required String style,
    required String level,
    required int durationDays,
  }) async {
    await initialize();

    final prompt = _buildPrompt(style, level, durationDays);

    try {
      final messages = [
        ChatMessage(
          role: 'system',
          content: 'You are a photography instructor creating daily challenges. Respond ONLY with valid JSON, no other text.',
        ),
        ChatMessage(
          role: 'user',
          content: prompt,
        ),
      ];

      final result = await _llm.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(
          maxTokens: 2000,
          temperature: 0.7,
        ),
      );

      if (!result.success) {
        throw Exception('LLM generation failed');
      }

      print('📝 Generated response: ${result.response}');

      // Clean up response (remove markdown code blocks if present)
      String cleanedResponse = result.response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      // Parse JSON response
      final planData = jsonDecode(cleanedResponse);

      // Save to database
      await _savePlanToDatabase(userId, style, level, durationDays, planData);

      return planData;
    } catch (e) {
      print('❌ Error generating plan: $e');
      rethrow;
    }
  }

  String _buildPrompt(String style, String level, int durationDays) {
    return '''
Create a $durationDays-day $style photography learning plan for a $level photographer.

Generate a JSON object with exactly $durationDays challenges. Each challenge should have:
- day: day number (1 to $durationDays)
- title: Short challenge title (max 6 words)
- description: What to capture (2-3 sentences)
- tips: Array of 3 practical tips
- subtasks: Array of 3-4 progressive steps

Format:

{
  "plan_name": "$style Photography - $durationDays Days",
  "challenges": [
    {
      "day": 1,
      "title": "Understanding Light",
      "description": "Capture 3 photos showing different lighting conditions.",
      "tips": ["Shoot during golden hour", "Use manual mode", "Focus on shadows"],
      "subtasks": [
        {"title": "Find location", "order": 1},
        {"title": "Setup camera settings", "order": 2},
        {"title": "Capture 3 photos", "order": 3}
      ]
    }
  ]
}

IMPORTANT: Output ONLY valid JSON, no markdown, no explanations.
''';
  }

  Future<void> _savePlanToDatabase(
    int userId,
    String style,
    String level,
    int durationDays,
    Map<String, dynamic> planData,
  ) async {
    final db = await DatabaseHelper.instance.database;

    // Deactivate existing active tracks
    await db.update(
      'tracks',
      {'is_active': 0},
      where: 'user_id = ? AND is_active = ?',
      whereArgs: [userId, 1],
    );

    // Create new track
    final track = Track(
      userId: userId,
      name: planData['plan_name'] ?? '$style Photography',
      style: style,
      level: level,
      durationDays: durationDays,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final trackId = await db.insert('tracks', track.toMap());

    // Save challenges
    final challenges = planData['challenges'] as List;
    for (var challengeData in challenges) {
      final challenge = Challenge(
        trackId: trackId,
        dayNumber: challengeData['day'],
        title: challengeData['title'],
        description: challengeData['description'],
        tips: (challengeData['tips'] as List).join('\n• '),
      );

      final challengeId = await db.insert('challenges', challenge.toMap());

      // Save subtasks
      final subtasks = challengeData['subtasks'] as List;
      for (var subtaskData in subtasks) {
        final subtask = Subtask(
          challengeId: challengeId,
          title: subtaskData['title'],
          orderIndex: subtaskData['order'],
        );

        await db.insert('subtasks', subtask.toMap());
      }
    }
  }

  void dispose() {
    _llm.unload();
  }
}