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
      
      await _llm.downloadModel(
        model: "qwen3-0.6",
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
      
      await _llm.initializeModel(
        params: CactusInitParams(
          model: "qwen3-0.6",
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

    await initialize();

    try {
      print('💬 Generating AI challenges...');
      
      // Generate challenges one at a time for better reliability
      final challenges = <Map<String, dynamic>>[];
      
      for (int day = 1; day <= durationDays; day++) {
        print('📝 Generating day $day/$durationDays...');
        
        try {
          final challenge = await _generateSingleChallenge(
            style: style,
            level: level,
            day: day,
            totalDays: durationDays,
          );
          challenges.add(challenge);
          print('✅ Day $day generated');
        } catch (e) {
          print('❌ Failed to generate day $day, using mock: $e');
          challenges.add(_generateMockChallenge(style, level, day));
        }
        
        // Small delay to prevent overwhelming the model
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final planData = {
        'plan_name': '$style Photography - $durationDays Day Challenge',
        'challenges': challenges,
      };

      print('✅ Plan generation complete');
      print('📊 Generated ${challenges.length} challenges');

      await _savePlanToDatabase(userId, style, level, durationDays, planData);

      return planData;
    } catch (e) {
      print('❌ Error generating plan: $e');
      print('💡 Falling back to full mock data.. .');
      
      final mockPlan = _generateMockPlan(style, level, durationDays);
      await _savePlanToDatabase(userId, style, level, durationDays, mockPlan);
      return mockPlan;
    }
  }

  Future<Map<String, dynamic>> _generateSingleChallenge({
    required String style,
    required String level,
    required int day,
    required int totalDays,
  }) async {
    final prompt = _buildChallengePrompt(style, level, day, totalDays);

    final messages = [
      ChatMessage(
        role: 'system',
        content: 'You are a photography instructor.  You MUST follow the exact format given. Do not add extra text or explanations.',
      ),
      ChatMessage(
        role: 'user',
        content: prompt,
      ),
    ];

    final result = await _llm.generateCompletion(
      messages: messages,
      params: CactusCompletionParams(
        maxTokens: 400,
        temperature: 0.5,
        stopSequences: ["---", "\n\n\n", "<|im_end|>"],
      ),
    );

    if (! result.success) {
      throw Exception('LLM generation failed');
    }

    print('🔍 Day $day raw output:');
    print('─' * 50);
    print(result.response);
    print('─' * 50);

    // Parse the text response into structured data
    return _parseTextResponse(result.response, style, level, day);
  }

  String _buildChallengePrompt(String style, String level, int day, int totalDays) {
    return '''Create a $style photography challenge for day $day ($level level).  

STRICT FORMAT - Follow exactly:

TITLE: [Maximum 3-5 words only]
TASK: [Exactly 1-2 sentences about what to photograph]
TIP1: [One tip, max 15 words]
TIP2: [One tip, max 15 words]
TIP3: [One tip, max 15 words]
STEP1: [First action step, max 10 words]
STEP2: [Second action step, max 10 words]
STEP3: [Third action step, max 10 words]
STEP4: [Fourth action step, max 10 words]

RULES:
- TITLE must be 3-5 words MAXIMUM
- Use simple, clear language
- Each TIP must be actionable
- Each STEP must be a specific action
- Do not add extra text before or after

Example format:
TITLE: Golden Hour Portraits
TASK: Photograph a person during golden hour focusing on natural lighting.  Capture their face with warm, soft light.
TIP1: Shoot 1 hour before sunset
TIP2: Position subject facing the light
TIP3: Use a wide aperture
STEP1: Find outdoor location with open space
STEP2: Position subject and check eye focus
STEP3: Take multiple shots with different poses
STEP4: Review lighting and expression

Now create the challenge:''';
  }

  Map<String, dynamic> _parseTextResponse(String text, String style, String level, int day) {
    try {
      print('🔧 Parsing response for day $day...');
      
      // Clean the text aggressively
      text = text. replaceAll('<|im_end|>', '')
                 .replaceAll('```', '')
                 .replaceAll('Example format:', '')
                 .trim();
      
      // Remove any text before "TITLE:"
      final titleIndex = text.indexOf(RegExp(r'TITLE:', caseSensitive: false));
      if (titleIndex > 0) {
        text = text.substring(titleIndex);
      }
      
      // Extract using strict regex patterns
      final titleMatch = RegExp(r'TITLE:\s*([^\n]+)', caseSensitive: false).firstMatch(text);
      final taskMatch = RegExp(r'TASK:\s*([^\n]+(?:\n(?!TIP|STEP)[^\n]+)*)', caseSensitive: false, multiLine: true).firstMatch(text);
      final tip1Match = RegExp(r'TIP1:\s*([^\n]+)', caseSensitive: false).firstMatch(text);
      final tip2Match = RegExp(r'TIP2:\s*([^\n]+)', caseSensitive: false).firstMatch(text);
      final tip3Match = RegExp(r'TIP3:\s*([^\n]+)', caseSensitive: false).firstMatch(text);
      final step1Match = RegExp(r'STEP1:\s*([^\n]+)', caseSensitive: false).firstMatch(text);
      final step2Match = RegExp(r'STEP2:\s*([^\n]+)', caseSensitive: false).firstMatch(text);
      final step3Match = RegExp(r'STEP3:\s*([^\n]+)', caseSensitive: false). firstMatch(text);
      final step4Match = RegExp(r'STEP4:\s*([^\n]+)', caseSensitive: false).firstMatch(text);
      
      String title;
      String description;
      List<String> tips = [];
      List<Map<String, dynamic>> subtasks = [];
      
      // Extract title
      if (titleMatch != null) {
        title = _cleanAndShortenTitle(titleMatch.group(1)!. trim());
        print('  ✅ Extracted title: $title');
      } else {
        print('  ⚠️ No title found, using default');
        title = _getDefaultTitle(style, day);
      }
      
      // Extract description
      if (taskMatch != null) {
        description = taskMatch.group(1)!. trim(). replaceAll('\n', ' ');
        print('  ✅ Extracted task');
      } else {
        print('  ⚠️ No task found, using default');
        description = _getDefaultDescription(style, level, day);
      }
      
      // Extract tips
      if (tip1Match != null) tips.add(_cleanTip(tip1Match.group(1)!.trim()));
      if (tip2Match != null) tips.add(_cleanTip(tip2Match.group(1)!.trim()));
      if (tip3Match != null) tips. add(_cleanTip(tip3Match.group(1)!. trim()));
      
      print('  ✅ Extracted ${tips.length} tips');
      
      // Fill in missing tips with defaults
      final defaultTips = _getDefaultTips(style);
      while (tips.length < 3) {
        tips.add(defaultTips[tips.length % defaultTips.length]);
      }
      
      // Extract subtasks/steps
      int stepOrder = 1;
      if (step1Match != null) {
        subtasks.add({
          'title': _cleanStep(step1Match.group(1)!.trim()),
          'order': stepOrder++,
        });
      }
      if (step2Match != null) {
        subtasks.add({
          'title': _cleanStep(step2Match.group(1)! .trim()),
          'order': stepOrder++,
        });
      }
      if (step3Match != null) {
        subtasks.add({
          'title': _cleanStep(step3Match.group(1)!.trim()),
          'order': stepOrder++,
        });
      }
      if (step4Match != null) {
        subtasks. add({
          'title': _cleanStep(step4Match.group(1)!.trim()),
          'order': stepOrder++,
        });
      }
      
      print('  ✅ Extracted ${subtasks.length} subtasks');
      
      // Fill in missing subtasks with defaults
      if (subtasks.length < 4) {
        final defaultSubtasks = _getDefaultSubtasks(style);
        while (subtasks.length < 4) {
          subtasks. add(defaultSubtasks[subtasks.length]);
        }
      }
      
      print('  Final title: $title (${title.split(' '). length} words)');
      print('  Final tips: ${tips.length} total');
      print('  Final subtasks: ${subtasks.length} total');

      return {
        'day': day,
        'title': title,
        'description': description,
        'tips': tips. take(3).toList(),
        'subtasks': subtasks. take(4).toList(),
      };
    } catch (e) {
      print('❌ Parse error: $e');
      return _generateMockChallenge(style, level, day);
    }
  }

  String _cleanAndShortenTitle(String title) {
    // Remove common prefixes and suffixes
    title = title
        .replaceAll(RegExp(r'^(Day \d+:?  |TITLE:? |Challenge:? )\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[:\-]\s*$'), '')
        .trim();
    
    // Remove quotes
    title = title.replaceAll(RegExp(r'''^["\']|["\']$'''), '');
    
    // Take only first 5 words maximum
    final words = title.split(RegExp(r'\s+'));
    if (words.length > 5) {
      title = words.take(5).join(' ');
    }
    
    // Capitalize properly
    if (title.isNotEmpty) {
      final titleWords = title.split(' ');
      title = titleWords.map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1). toLowerCase();
      }).join(' ');
    }
    
    return title;
  }

  String _cleanTip(String tip) {
    // Remove tip numbering
    tip = tip.replaceAll(RegExp(r'^(TIP\d+:? |\d+\.) \s*', caseSensitive: false), '');
    
    // Capitalize first letter
    if (tip.isNotEmpty) {
      tip = tip[0].toUpperCase() + tip.substring(1);
    }
    
    // Ensure it ends with period if it doesn't have punctuation
    if (tip.isNotEmpty && !tip.endsWith('.') && !tip.endsWith('!') && !tip.endsWith('? ')) {
      tip += '.';
    }
    
    return tip;
  }

  String _cleanStep(String step) {
    // Remove step numbering and prefixes
    step = step.replaceAll(RegExp(r'^(STEP\d+:? |\d+\. )\s*', caseSensitive: false), '');
    
    // Capitalize first letter
    if (step.isNotEmpty) {
      step = step[0].toUpperCase() + step. substring(1);
    }
    
    return step;
  }

  String _generateTitleFromText(String text, String style) {
    // Extract key photography terms
    final keywords = {
      'bird': 'Bird Photography',
      'flight': 'Capturing Flight',
      'sunset': 'Sunset Magic',
      'sunrise': 'Sunrise Glory',
      'portrait': 'Portrait Study',
      'landscape': 'Landscape Capture',
      'architecture': 'Architectural Lines',
      'street': 'Street Moments',
      'night': 'Night Photography',
      'golden hour': 'Golden Hour',
      'light': 'Working with Light',
      'shadow': 'Light and Shadow',
      'color': 'Color Study',
      'pattern': 'Pattern Recognition',
      'texture': 'Texture Focus',
      'detail': 'Detail Work',
      'motion': 'Motion Capture',
      'action': 'Action Shots',
    };
    
    final lowerText = text.toLowerCase();
    for (var entry in keywords.entries) {
      if (lowerText.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Fallback: use first few words
    final words = text. split(' '). take(4).join(' ');
    return words. length > 30 ? words.substring(0, 30) : words;
  }

  String _getStyleContext(String style) {
    final contexts = {
      'Street': 'urban photography, candid moments, city life',
      'Portrait': 'people photography, facial expressions, posing',
      'Landscape': 'nature scenes, wide vistas, natural beauty',
      'Wildlife': 'animals in nature, behavior, natural habitats',
      'Architecture': 'buildings, structures, geometric patterns',
      'Sports': 'action photography, fast movement, athletics',
      'Automotive': 'cars, vehicles, motion, angles',
      'Event': 'gatherings, celebrations, moments',
      'Product': 'commercial photography, clean shots, styling',
    };
    return contexts[style] ?? 'general photography';
  }

  String _getDefaultTitle(String style, int day) {
    final titles = {
      'Street': ['Urban Geometry', 'People in Motion', 'Street Patterns', 'City Lights', 'Urban Contrast', 'Candid Moments', 'Architecture Details'],
      'Portrait': ['Natural Light Portrait', 'Golden Hour Glow', 'Indoor Portrait', 'Environmental Portrait', 'Close-up Details', 'Depth of Field', 'Expression Study'],
      'Landscape': ['Golden Hour Magic', 'Leading Lines', 'Water Reflections', 'Sky Drama', 'Foreground Interest', 'Wide Angle', 'Natural Frames'],
      'Wildlife': ['Bird Behavior', 'Action Shots', 'Natural Habitat', 'Macro Details', 'Silhouettes', 'Eye Focus', 'Environmental Context'],
      'Architecture': ['Lines and Symmetry', 'Urban Patterns', 'Building Details', 'Perspective Play', 'Geometric Forms', 'Structure and Light', 'Architectural Angles'],
      'Sports': ['Freeze the Action', 'Motion Blur', 'Peak Moment', 'Athletic Form', 'Energy Capture', 'Dynamic Movement', 'Sports Emotion'],
      'Automotive': ['Car Angles', 'Motion Panning', 'Detail Shots', 'Environmental Context', 'Reflections', 'Speed Lines', 'Vehicle Character'],
      'Event': ['Key Moments', 'Candid Shots', 'Atmosphere', 'Emotion Capture', 'Story Telling', 'Detail Focus', 'Group Dynamics'],
      'Product': ['Clean Background', 'Lighting Setup', 'Detail Focus', 'Styling', 'Multiple Angles', 'Texture Emphasis', 'Commercial Look'],
    };
    
    final styleList = titles[style] ?? titles['Street']!;
    return styleList[(day - 1) % styleList.length];
  }

  String _getDefaultDescription(String style, String level, int day) {
    return 'Practice $style photography focusing on ${_getMockFocus(day)}. Capture 3 compelling photos that demonstrate your understanding of this technique. ${level == "Beginner" ? "Take your time and experiment with different settings." : "Challenge yourself to push creative boundaries. "}';
  }

  List<String> _getDefaultTips(String style) {
    final tipSets = {
      'Street': [
        'Look for interesting light and shadows',
        'Be patient and wait for the right moment',
        'Pay attention to your background',
      ],
      'Portrait': [
        'Use natural light when possible',
        'Focus on the eyes',
        'Make your subject comfortable',
      ],
      'Landscape': [
        'Shoot during golden hour',
        'Use a tripod for stability',
        'Include foreground interest',
      ],
      'Wildlife': [
        'Be patient and quiet',
        'Use a fast shutter speed',
        'Focus on the animal\'s eyes',
      ],
      'Architecture': [
        'Look for symmetry and lines',
        'Try different angles and perspectives',
        'Watch for interesting light on buildings',
      ],
      'Sports': [
        'Use high shutter speed',
        'Anticipate the action',
        'Focus on facial expressions',
      ],
      'Automotive': [
        'Find interesting angles',
        'Watch for reflections',
        'Use leading lines',
      ],
      'Event': [
        'Capture candid moments',
        'Look for emotions',
        'Tell a story through photos',
      ],
      'Product': [
        'Use clean backgrounds',
        'Control your lighting',
        'Show product details clearly',
      ],
    };

    return tipSets[style] ?? [
      'Pay attention to composition',
      'Use appropriate camera settings',
      'Review and learn from each shot',
    ];
  }

  List<Map<String, dynamic>> _getDefaultSubtasks(String style) {
    final styleSubtasks = {
      'Street': [
        {'title': 'Scout urban location with good foot traffic', 'order': 1},
        {'title': 'Set camera to fast shutter speed', 'order': 2},
        {'title': 'Capture candid moments of people', 'order': 3},
        {'title': 'Review composition and timing', 'order': 4},
      ],
      'Portrait': [
        {'title': 'Find good natural lighting location', 'order': 1},
        {'title': 'Position subject and check focus on eyes', 'order': 2},
        {'title': 'Take multiple shots with different poses', 'order': 3},
        {'title': 'Review expression and lighting', 'order': 4},
      ],
      'Landscape': [
        {'title': 'Scout location during golden hour', 'order': 1},
        {'title': 'Set up tripod and compose with foreground', 'order': 2},
        {'title': 'Capture scene with proper exposure', 'order': 3},
        {'title': 'Review sharpness and composition', 'order': 4},
      ],
      'Wildlife': [
        {'title': 'Research and locate wildlife habitat', 'order': 1},
        {'title': 'Set fast shutter speed and telephoto lens', 'order': 2},
        {'title': 'Patiently capture animal behavior', 'order': 3},
        {'title': 'Review focus and timing', 'order': 4},
      ],
      'Architecture': [
        {'title': 'Find building with interesting geometry', 'order': 1},
        {'title': 'Check angles and perspective', 'order': 2},
        {'title': 'Photograph architectural details', 'order': 3},
        {'title': 'Review lines and symmetry', 'order': 4},
      ],
      'Sports': [
        {'title': 'Position yourself near the action', 'order': 1},
        {'title': 'Set high shutter speed and burst mode', 'order': 2},
        {'title': 'Capture peak moments of movement', 'order': 3},
        {'title': 'Review sharpness and timing', 'order': 4},
      ],
      'Automotive': [
        {'title': 'Find clean location and good angles', 'order': 1},
        {'title': 'Check lighting and reflections', 'order': 2},
        {'title': 'Photograph vehicle from multiple angles', 'order': 3},
        {'title': 'Review details and composition', 'order': 4},
      ],
      'Event': [
        {'title': 'Scout venue and identify key moments', 'order': 1},
        {'title': 'Prepare camera settings for indoor/outdoor', 'order': 2},
        {'title': 'Capture candid and posed moments', 'order': 3},
        {'title': 'Review coverage and emotion', 'order': 4},
      ],
      'Product': [
        {'title': 'Set up clean background and lighting', 'order': 1},
        {'title': 'Position product and check reflections', 'order': 2},
        {'title': 'Photograph from multiple angles', 'order': 3},
        {'title': 'Review details and lighting', 'order': 4},
      ],
    };

    return styleSubtasks[style] ?? [
      {'title': 'Scout and plan your location', 'order': 1},
      {'title': 'Setup camera with proper settings', 'order': 2},
      {'title': 'Capture 3 different photos', 'order': 3},
      {'title': 'Review and adjust technique', 'order': 4},
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

  Map<String, dynamic> _generateMockChallenge(String style, String level, int day) {
    return {
      'day': day,
      'title': _getDefaultTitle(style, day),
      'description': _getDefaultDescription(style, level, day),
      'tips': _getDefaultTips(style),
      'subtasks': _getDefaultSubtasks(style),
    };
  }

  Map<String, dynamic> _generateMockPlan(String style, String level, int durationDays) {
    final challenges = List.generate(durationDays, (index) {
      return _generateMockChallenge(style, level, index + 1);
    });

    return {
      'plan_name': '$style Photography - $durationDays Day Challenge',
      'challenges': challenges,
    };
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
      where: 'user_id = ?  AND is_active = ? ',
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
      final tips = challengeData['tips'] as List;
      final tipsString = tips.map((t) => '• $t').join('\n');
      
      final challenge = Challenge(
        trackId: trackId,
        dayNumber: challengeData['day'],
        title: challengeData['title'],
        description: challengeData['description'],
        tips: tipsString,
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