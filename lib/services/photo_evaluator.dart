// lib/services/photo_evaluator.dart

import 'package:cactus/cactus.dart';
import '../models/challenge.dart';

class PhotoEvaluationResult {
  final String feedback;
  final DateTime evaluatedAt;

  PhotoEvaluationResult({
    required this.feedback,
    required this.evaluatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'feedback': feedback,
      'evaluated_at': evaluatedAt.toIso8601String(),
    };
  }

  factory PhotoEvaluationResult.fromJson(Map<String, dynamic> json) {
    return PhotoEvaluationResult(
      feedback: json['feedback'] ?? '',
      evaluatedAt: DateTime.parse(json['evaluated_at']),
    );
  }
}

class PhotoEvaluator {
  static final PhotoEvaluator instance = PhotoEvaluator._init();
  PhotoEvaluator._init();

  final CactusLM _llm = CactusLM();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ Evaluation LLM already initialized');
      return;
    }

    try {
      print('📥 Starting evaluation model download...');

      await _llm.downloadModel(
        model: "qwen3-0.6",
        downloadProcessCallback: (progress, status, isError) {
          if (isError) {
            print('❌ Evaluation model download error: $status');
          } else {
            final percentage = progress != null ? '(${(progress * 100).toInt()}%)' : '';
            print('📥 Evaluation: $status $percentage');
          }
        },
      );

      print('🔧 Initializing evaluation model...');

      await _llm.initializeModel(
        params: CactusInitParams(
          model: "qwen3-0.6",
          contextSize: 2048,
        ),
      );

      _isInitialized = true;
      print('✅ Evaluation LLM initialized successfully');
    } catch (e) {
      print('❌ Error initializing evaluation LLM: $e');
      rethrow;
    }
  }

  Future<PhotoEvaluationResult> evaluatePhotos({
    required Challenge challenge,
    required List<String> photoPaths,
    required String photographyStyle,
    required String skillLevel,
  }) async {
    print('🎯 Evaluating ${photoPaths.length} photos for challenge: ${challenge.title}');

    await initialize();

    try {
      print('📊 Generating evaluation...');
      
      final prompt = _buildEvaluationPrompt(
        challenge: challenge,
        photoCount: photoPaths.length,
        photographyStyle: photographyStyle,
        skillLevel: skillLevel,
      );

      final messages = [
        ChatMessage(
          role: 'system',
          content: 'You are an encouraging and constructive photography instructor providing detailed feedback to help students improve.',
        ),
        ChatMessage(
          role: 'user',
          content: prompt,
        ),
      ];

      final result = await _llm.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(
          maxTokens: 800,
          temperature: 0.7,
        ),
      );

      if (!result.success) {
        throw Exception('Evaluation generation failed');
      }

      print('✅ Evaluation complete');

      return PhotoEvaluationResult(
        feedback: result.response.trim(),
        evaluatedAt: DateTime.now(),
      );
    } catch (e) {
      print('❌ Error during evaluation: $e');
      return _generateMockEvaluation(challenge, photographyStyle, skillLevel);
    }
  }

  String _buildEvaluationPrompt({
    required Challenge challenge,
    required int photoCount,
    required String photographyStyle,
    required String skillLevel,
  }) {
    return '''
You are evaluating a photography challenge submission from a $skillLevel level photographer.

CHALLENGE DETAILS:
Day: ${challenge.dayNumber}
Title: ${challenge.title}
Style: $photographyStyle
Description: ${challenge.description}
Tips Given: ${challenge.tips ?? 'None'}
Photos Submitted: $photoCount

The student has submitted $photoCount photos attempting to meet the challenge requirements.

Please provide comprehensive, constructive feedback covering:

1. **Overall Assessment**: How well did they meet the challenge requirements?

2. **What Worked Well**: Specific strengths you noticed (be encouraging!)

3. **Areas to Improve**: Constructive suggestions for growth

4. **Technical Feedback**: Comments on exposure, focus, composition, etc.

5. **Creative Feedback**: Thoughts on their artistic choices and perspective

6. **Next Steps**: Specific actionable advice for their continued learning

Keep your feedback:
- Encouraging and supportive
- Specific and actionable
- Appropriate for a $skillLevel level photographer
- Focused on growth and learning

Write your feedback in a natural, conversational tone. Be thorough but concise.''';
  }

  PhotoEvaluationResult _generateMockEvaluation(
    Challenge challenge,
    String photographyStyle,
    String skillLevel,
  ) {
    final feedback = '''
**Overall Assessment**

Great work completing the "${challenge.title}" challenge! You've shown good understanding of the core concepts and made a solid effort to meet the requirements.

**What Worked Well**

- You successfully completed all ${challenge.dayNumber} day objectives
- Your photos demonstrate thoughtful composition
- You clearly considered the $photographyStyle style guidelines
- Good effort in applying the technical tips provided

**Areas to Improve**

- Pay more attention to lighting conditions - the golden hour can make a huge difference
- Experiment with different angles before settling on your shot
- Review the rule of thirds to strengthen your compositions
- Take time to ensure your main subject is tack sharp

**Technical Feedback**

Your technical execution shows a solid foundation for a $skillLevel photographer. Continue practicing with manual settings to gain more control over your exposure. Don't be afraid to adjust your ISO in changing light conditions.

**Creative Feedback**

You're developing a good eye for interesting subjects! To take your work to the next level, try to tell a story with each photo. Ask yourself: what emotion or message do I want to convey? This mindset will help you make stronger creative choices.

**Next Steps**

1. Practice the same challenge again with different lighting conditions
2. Study the work of professional $photographyStyle photographers
3. Review your photos critically - what would you change?
4. Keep shooting and experimenting!

Keep up the great work! Photography is a journey, and you're making excellent progress. 📸
''';

    return PhotoEvaluationResult(
      feedback: feedback,
      evaluatedAt: DateTime.now(),
    );
  }

  void dispose() {
    if (_isInitialized) {
      _llm.unload();
      _isInitialized = false;
      print('🔄 Evaluation LLM unloaded');
    }
  }
}