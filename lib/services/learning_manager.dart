// lib/services/learning_manager.dart - COMPLETE REPLACEMENT

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
  
  // TEMPORARY: Use mock data until network is stable
  static const bool USE_MOCK_DATA = true;

  Future<void> initialize() async {
    if (USE_MOCK_DATA) {
      print('⚠️ Using mock data mode - AI model download skipped');
      return;
    }
    
    try {
      await _llm.downloadModel(
        model: "qwen3-0.6",
        downloadProcessCallback: (progress, status, isError) {
          if (isError) {
            print('❌ Download error: $status');
          } else {
            print('📥 $status ${progress != null ? '(${(progress * 100).toInt()}%)' : ''}');
          }
        },
      );

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

  Future<Map<String, dynamic>> generatePlan({
    required int userId,
    required String style,
    required String level,
    required int durationDays,
  }) async {
    if (USE_MOCK_DATA) {
      print('📝 Generating mock plan for $style ($level, $durationDays days)');
      await Future.delayed(const Duration(seconds: 2)); // Simulate generation
      final plan = _generateMockPlan(style, level, durationDays);
      await _savePlanToDatabase(userId, style, level, durationDays, plan);
      return plan;
    }

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

      String cleanedResponse = result.response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final planData = jsonDecode(cleanedResponse);
      await _savePlanToDatabase(userId, style, level, durationDays, planData);

      return planData;
    } catch (e) {
      print('❌ Error generating plan: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _generateMockPlan(String style, String level, int durationDays) {
    final challenges = List.generate(durationDays, (index) {
      final day = index + 1;
      return {
        'day': day,
        'title': _getMockTitle(style, day),
        'description': _getMockDescription(style, level, day),
        'tips': _getMockTips(style, day),
        'subtasks': [
          {'title': 'Scout and plan location', 'order': 1},
          {'title': 'Setup camera and composition', 'order': 2},
          {'title': 'Capture 3 photos', 'order': 3},
          {'title': 'Review and adjust', 'order': 4}
        ]
      };
    });

    return {
      'plan_name': '$style Photography - $durationDays Days',
      'challenges': challenges,
    };
  }

  String _getMockTitle(String style, int day) {
    final titles = {
      'Street': ['Urban Lines', 'People in Motion', 'Street Patterns', 'City Lights', 'Urban Contrast', 'Candid Moments', 'Architecture Details'],
      'Portrait': ['Natural Light Portrait', 'Golden Hour', 'Indoor Portrait', 'Environmental Portrait', 'Close-up Details', 'Depth of Field', 'Expression Study'],
      'Landscape': ['Golden Hour Magic', 'Leading Lines', 'Water Reflections', 'Sky Drama', 'Foreground Interest', 'Wide Angle', 'Natural Frames'],
      'Wildlife': ['Bird Behavior', 'Action Shots', 'Natural Habitat', 'Macro Details', 'Silhouettes', 'Eye Focus', 'Environmental Context'],
    };
    
    final styleList = titles[style] ?? titles['Street']!;
    return 'Day $day: ${styleList[(day - 1) % styleList.length]}';
  }

  String _getMockDescription(String style, String level, int day) {
    return 'Practice $style photography focusing on ${_getMockFocus(day)}. Capture 3 compelling photos that demonstrate your understanding of this technique. ${level == "Beginner" ? "Take your time and experiment with different settings." : "Challenge yourself to push creative boundaries."}';
  }

  List<String> _getMockTips(String style, int day) {
    final allTips = [
      'Use the golden hour for softer, warmer light',
      'Pay attention to your composition and rule of thirds',
      'Experiment with different angles and perspectives',
      'Focus on your subject\'s eyes for portraits',
      'Use leading lines to draw viewer attention',
      'Watch your background for distractions',
      'Adjust ISO based on lighting conditions',
      'Use aperture to control depth of field',
      'Consider the story you want to tell',
      'Practice manual focus for precision',
    ];
    
    return [
      allTips[day % allTips.length],
      allTips[(day + 3) % allTips.length],
      allTips[(day + 7) % allTips.length],
    ];
  }

  String _getMockFocus(int day) {
    final focuses = [
      'composition and framing',
      'natural lighting techniques',
      'depth of field control',
      'leading lines and geometry',
      'golden hour photography',
      'perspective and angles',
      'color and contrast',
      'storytelling elements',
      'technical precision',
      'creative expression',
    ];
    return focuses[day % focuses.length];
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

    await db.update(
      'tracks',
      {'is_active': 0},
      where: 'user_id = ? AND is_active = ?',
      whereArgs: [userId, 1],
    );

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
    if (!USE_MOCK_DATA) {
      _llm.unload();
    }
  }
}