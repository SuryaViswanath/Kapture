// lib/services/learning_manager.dart - COMPLETE FILE

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
  bool _isInitialized = false;
  
  static const bool USE_MOCK_DATA = false;  // Set to true if AI keeps failing

  Future<void> initialize() async {
    if (USE_MOCK_DATA) {
      print('⚠️ Using mock data mode');
      return;
    }

    if (_isInitialized) {
      print('✅ LLM already initialized');
      return;
    }

    try {
      print('📥 Downloading model...');
      
      await _llm.downloadModel(
  model: "local-qwen3-0.6",  // lowercase, dash instead of dot
  downloadProcessCallback: (progress, status, isError) {
    if (isError) {
      print('❌ $status');
    } else {
      print('📥 $status ${progress != null ? '(${(progress * 100).toInt()}%)' : ''}');
    }
  },
);

await _llm.initializeModel(
  params: CactusInitParams(
    model: "local-qwen3-0.6",  // Match here too
    contextSize: 2048,
  ),
);

      _isInitialized = true;
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
      print('📝 Generating mock plan');
      await Future.delayed(const Duration(seconds: 2));
      final plan = _generateMockPlan(style, level, durationDays);
      await _savePlanToDatabase(userId, style, level, durationDays, plan);
      return plan;
    }

    try {
      await initialize();

      final prompt = _buildPrompt(style, level, durationDays);
      final messages = [
        ChatMessage(
          role: 'user',
          content: prompt,
        ),
      ];

      print('🤖 Generating plan with AI...');
      
      final result = await _llm.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(
          maxTokens: 2000,
          temperature: 0.5,  // Lower temperature for more consistent JSON
        ),
      );

      if (!result.success) {
        throw Exception('LLM generation failed');
      }

      print('📝 Raw AI Response: ${result.response}');

      // Extract and clean JSON
      final planData = _extractAndParseJSON(result.response, style, durationDays);
      await _savePlanToDatabase(userId, style, level, durationDays, planData);

      return planData;
    } catch (e) {
      print('❌ AI Error: $e');
      print('⚠️ Falling back to mock data');
      final plan = _generateMockPlan(style, level, durationDays);
      await _savePlanToDatabase(userId, style, level, durationDays, plan);
      return plan;
    }
  }

  Map<String, dynamic> _extractAndParseJSON(String response, String style, int durationDays) {
    try {
      // Remove markdown code blocks
      String cleaned = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      // Remove any text after the JSON (like <end_of_turn>)
      final endMarkers = ['<end_of_turn>', '</s>', '<|im_end|>', '<|endoftext|>'];
      for (var marker in endMarkers) {
        if (cleaned.contains(marker)) {
          cleaned = cleaned.substring(0, cleaned.indexOf(marker));
        }
      }
      
      // Try to find JSON object
      final jsonStart = cleaned.indexOf('{');
      final jsonEnd = cleaned.lastIndexOf('}');
      
      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
        cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
      }

      print('🔧 Cleaned JSON: $cleaned');

      // Try parsing
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      
      // Validate structure
      if (!data.containsKey('challenges') || data['challenges'] is! List) {
        throw FormatException('Invalid JSON structure');
      }

      final challenges = data['challenges'] as List;
      if (challenges.length != durationDays) {
        print('⚠️ Expected $durationDays challenges, got ${challenges.length}');
      }

      // Ensure all challenges have required fields
      for (var i = 0; i < challenges.length; i++) {
        final challenge = challenges[i] as Map<String, dynamic>;
        
        if (!challenge.containsKey('day')) challenge['day'] = i + 1;
        if (!challenge.containsKey('title')) challenge['title'] = 'Day ${i + 1} Challenge';
        if (!challenge.containsKey('description')) challenge['description'] = 'Complete photography challenge';
        if (!challenge.containsKey('tips')) challenge['tips'] = ['Practice regularly', 'Experiment with settings', 'Review your work'];
        if (!challenge.containsKey('subtasks')) {
          challenge['subtasks'] = [
            {'title': 'Scout location', 'order': 1},
            {'title': 'Setup camera', 'order': 2},
            {'title': 'Capture photos', 'order': 3},
          ];
        }
      }

      if (!data.containsKey('plan_name')) {
        data['plan_name'] = '$style Photography - $durationDays Days';
      }

      return data;
    } catch (e) {
      print('❌ JSON parsing failed: $e');
      throw FormatException('Failed to parse AI response as JSON');
    }
  }

  String _buildPrompt(String style, String level, int durationDays) {
  // Don't show example - just give clear instructions
  return '''Create a $durationDays-day $style photography learning plan for $level level. 
  Don't ask anymore questions, just generate based on the data provided to you.

Each day needs:
- day: number (1, 2, 3...)
- title: short name (4-6 words)
- description: what to photograph (2 sentences)
- tips: exactly 3 tips as strings
- subtasks: exactly 3 tasks with title and order

Output as JSON with this structure:
{
  "plan_name": "$style Photography - $durationDays Days",
  "challenges": [
    {
      "day": 1,
      "title": "your title here",
      "description": "your description here",
      "tips": ["tip 1", "tip 2", "tip 3"],
      "subtasks": [
        {"title": "task 1", "order": 1},
        {"title": "task 2", "order": 2},
        {"title": "task 3", "order": 3}
      ]
    }
  ]
}

Generate all $durationDays challenges now:''';
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
      'Street': ['Urban Lines', 'People in Motion', 'Street Patterns', 'City Lights', 'Urban Contrast', 'Candid Moments', 'Architecture'],
      'Portrait': ['Natural Light', 'Golden Hour', 'Indoor Portrait', 'Environmental', 'Close-up', 'Depth of Field', 'Expression'],
      'Landscape': ['Golden Hour', 'Leading Lines', 'Reflections', 'Sky Drama', 'Foreground', 'Wide Angle', 'Natural Frames'],
      'Wildlife': ['Bird Behavior', 'Action Shots', 'Habitat', 'Macro Details', 'Silhouettes', 'Eye Focus', 'Environment'],
    };
    final styleList = titles[style] ?? titles['Street']!;
    return 'Day $day: ${styleList[(day - 1) % styleList.length]}';
  }

  String _getMockDescription(String style, String level, int day) {
    return 'Practice $style photography focusing on ${_getMockFocus(day)}. Capture 3 compelling photos that demonstrate your understanding. ${level == "Beginner" ? "Take your time to experiment." : "Push your creative boundaries."}';
  }

  List<String> _getMockTips(String style, int day) {
    final allTips = [
      'Use the golden hour for softer light',
      'Follow the rule of thirds',
      'Experiment with angles',
      'Focus on subject\'s eyes',
      'Use leading lines',
      'Watch your background',
      'Adjust ISO for conditions',
      'Control depth of field',
      'Tell a story',
      'Practice manual focus',
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
      'natural lighting',
      'depth of field',
      'leading lines',
      'golden hour',
      'perspective',
      'color contrast',
      'storytelling',
      'technical precision',
      'creative expression',
    ];
    return focuses[day % focuses.length];
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
    if (_isInitialized) {
      _llm.unload();
    }
  }
}