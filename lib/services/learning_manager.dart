// lib/services/learning_manager.dart

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

  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ LLM already initialized');
      return;
    }

    try {
      print('📥 Starting model download...');
      
      // Download the model (using qwen3-0.6 as recommended by Cactus docs)
      await _llm.downloadModel(
        model: "local-lfm2-vl-450m",
        downloadProcessCallback: (progress, status, isError) {
          if (isError) {
            print('❌ Download error: $status');
          } else {
            final percentage = progress != null ? '(${(progress * 100).toInt()}%)' : '';
            print('📥 $status $percentage');
          }
        },
      );

      print('🔧 Initializing model...');
      
      // Initialize the model
      await _llm.initializeModel(
        params: CactusInitParams(
          model: "local-lfm2-vl-450m",
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
    print('🎯 Generating plan: $style, $level, $durationDays days');

    // Ensure LLM is initialized
    await initialize();

    final prompt = _buildPrompt(style, level, durationDays);

    try {
      print('💬 Sending prompt to LLM...');
      
      final messages = [
        ChatMessage(
          role: 'system',
          content: 'You are an expert photography instructor. You create structured, progressive daily challenges. You MUST respond with ONLY valid JSON, no other text, no markdown formatting, no explanations.',
        ),
        ChatMessage(
          role: 'user',
          content: '/no_think' + prompt,
        ),
      ];

      final result = await _llm.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(
          maxTokens: 2000,
          temperature: 0.7,
          stopSequences: ["<|im_end|>", "<end_of_turn>"],
        ),
      );

      if (!result.success) {
        throw Exception('LLM generation failed');
      }

      print('✅ Received response from LLM');
      print('📝 Raw response: ${result.response.substring(0, 200)}...');

      // Clean the response
      String cleanedResponse = result.response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      // Remove any leading/trailing text that's not JSON
      final jsonStart = cleanedResponse.indexOf('{');
      final jsonEnd = cleanedResponse.lastIndexOf('}');
      
      if (jsonStart != -1 && jsonEnd != -1) {
        cleanedResponse = cleanedResponse.substring(jsonStart, jsonEnd + 1);
      }

      print('🧹 Cleaned response: ${cleanedResponse.substring(0, 200)}...');

      // Parse JSON
      final planData = jsonDecode(cleanedResponse);
      
      print('✅ JSON parsed successfully');
      print('📊 Generated ${(planData['challenges'] as List).length} challenges');

      // Save to database
      await _savePlanToDatabase(userId, style, level, durationDays, planData);

      return planData;
    } catch (e) {
      print('❌ Error generating plan: $e');
      print('💡 Falling back to mock data...');
      
      // Fallback to mock data if AI fails
      final mockPlan = _generateMockPlan(style, level, durationDays);
      await _savePlanToDatabase(userId, style, level, durationDays, mockPlan);
      return mockPlan;
    }
  }

  String _buildPrompt(String style, String level, int durationDays) {
    return '''
Create a $durationDays-day $style photography learning plan for a $level level photographer.

CRITICAL INSTRUCTIONS:
1. Generate EXACTLY $durationDays challenges (one per day)
2. Each challenge must be progressive (build on previous days)
3. Respond with ONLY valid JSON - no markdown, no explanations, no extra text
4. Follow the exact format below

Required JSON format:
{
  "plan_name": "$style Photography - $durationDays Day Challenge",
  "challenges": [
    {
      "day": 1,
      "title": "Challenge title (max 6 words)",
      "description": "What the user should photograph today (2-3 sentences)",
      "tips": ["Practical tip 1", "Practical tip 2", "Practical tip 3"],
      "subtasks": [
        {"title": "Step 1 description", "order": 1},
        {"title": "Step 2 description", "order": 2},
        {"title": "Step 3 description", "order": 3},
        {"title": "Step 4 description", "order": 4}
      ]
    }
  ]
}

Guidelines for $level level:
${_getLevelGuidelines(level)}

Focus areas for $style photography:
${_getStyleGuidelines(style)}

Generate the JSON now:''';
  }

  String _getLevelGuidelines(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return '''- Start with basic camera settings and composition
- Focus on one concept per day
- Use simple, clear instructions
- Encourage experimentation
- Build confidence gradually''';
      case 'intermediate':
        return '''- Assume understanding of basic exposure triangle
- Introduce advanced composition techniques
- Challenge creative thinking
- Combine multiple concepts
- Push technical boundaries''';
      case 'advanced':
        return '''- Focus on artistic vision and style
- Master challenging lighting conditions
- Explore creative post-processing
- Develop signature techniques
- Professional-level execution''';
      default:
        return '- Balanced approach to learning photography';
    }
  }

  String _getStyleGuidelines(String style) {
    final guidelines = {
      'Street': 'candid moments, urban environments, storytelling, decisive moment, light and shadow',
      'Portrait': 'lighting techniques, posing, depth of field, eye contact, environmental context',
      'Landscape': 'golden hour, leading lines, foreground interest, wide angles, weather conditions',
      'Wildlife': 'patience, telephoto techniques, animal behavior, natural habitat, action shots',
      'Architecture': 'lines and geometry, perspective, symmetry, detail shots, urban patterns',
      'Sports': 'fast shutter speeds, anticipation, peak action, continuous focus, motion blur',
      'Automotive': 'angles and reflections, motion panning, detail shots, environmental context',
      'Event': 'storytelling, candid moments, key moments, lighting challenges, wide and tight shots',
      'Product': 'clean backgrounds, lighting control, detail focus, styling, multiple angles',
    };
    
    return guidelines[style] ?? 'general photography techniques and principles';
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
          {'title': 'Scout and plan your location', 'order': 1},
          {'title': 'Setup camera with proper settings', 'order': 2},
          {'title': 'Capture 3 different photos', 'order': 3},
          {'title': 'Review and adjust technique', 'order': 4}
        ]
      };
    });

    return {
      'plan_name': '$style Photography - $durationDays Day Challenge',
      'challenges': challenges,
    };
  }

  String _getMockTitle(String style, int day) {
    final titles = {
      'Street': ['Urban Geometry', 'People in Motion', 'Street Patterns', 'City Lights', 'Urban Contrast', 'Candid Moments', 'Architecture Details'],
      'Portrait': ['Natural Light Portrait', 'Golden Hour Glow', 'Indoor Portrait', 'Environmental Portrait', 'Close-up Details', 'Depth of Field', 'Expression Study'],
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

  Future<void> _savePlanToDatabase(
    int userId,
    String style,
    String level,
    int durationDays,
    Map<String, dynamic> planData,
  ) async {
    final db = await DatabaseHelper.instance.database;

    // Deactivate all current active tracks
    await db.update(
      'tracks',
      {'is_active': 0},
      where: 'user_id = ? AND is_active = ?',
      whereArgs: [userId, 1],
    );

    // Create new track
    final track = Track(
      userId: userId,
      name: planData['plan_name'] ?? '$style Photography - $durationDays Days',
      style: style,
      level: level,
      durationDays: durationDays,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final trackId = await db.insert('tracks', track.toMap());
    print('✅ Track saved to database (ID: $trackId)');

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
    
    print('✅ All challenges and subtasks saved');
  }

  void dispose() {
    if (_isInitialized) {
      _llm.unload();
      _isInitialized = false;
      print('🔄 LLM unloaded');
    }
  }
}