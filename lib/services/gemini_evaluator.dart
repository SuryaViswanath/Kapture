// lib/services/gemini_evaluator.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/challenge.dart';

class GeminiEvaluationResult {
  final String feedback;
  final DateTime evaluatedAt;

  GeminiEvaluationResult({
    required this.feedback,
    required this.evaluatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'feedback': feedback,
      'evaluated_at': evaluatedAt.toIso8601String(),
    };
  }

  factory GeminiEvaluationResult.fromJson(Map<String, dynamic> json) {
    return GeminiEvaluationResult(
      feedback: json['feedback'] ?? '',
      evaluatedAt: DateTime.parse(json['evaluated_at']),
    );
  }
}

class GeminiEvaluator {
  static final GeminiEvaluator instance = GeminiEvaluator._init();
  GeminiEvaluator._init();

  // IMPORTANT: Replace with your actual API key
  static const String _apiKey = 'AIzaSyDY1g_OffsnZ5z9NX7bmm6952_njSk-V5c';

  Future<GeminiEvaluationResult> evaluatePhotos({
    required Challenge challenge,
    required List<String> photoPaths,
    required String photographyStyle,
    required String skillLevel,
  }) async {
    print('🎯 Evaluating ${photoPaths.length} photos with Gemini API');

    // Build the prompt
    final prompt = _buildEvaluationPrompt(
      challenge: challenge,
      photoCount: photoPaths.length,
      photographyStyle: photographyStyle,
      skillLevel: skillLevel,
    );

    // Convert images to base64
    final imageParts = await _prepareImages(photoPaths);

    // Build request with HIGHER token limit
    final requestBody = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            ...imageParts,
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.7,
        "maxOutputTokens": 2048, // Increased from 1024
      }
    };

    print('📡 Sending request to Gemini API...');

    final url = 'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$_apiKey';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    print('📥 Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      
      // Check if we have candidates
      if (responseData['candidates'] == null || responseData['candidates'].isEmpty) {
        throw Exception('No response generated');
      }
      
      final candidate = responseData['candidates'][0];
      
      // Check finish reason
      if (candidate['finishReason'] == 'MAX_TOKENS') {
        print('⚠️ Warning: Response was truncated (hit token limit)');
      }
      
      // Extract text from content.parts
      final content = candidate['content'];
      
      if (content == null || content['parts'] == null || content['parts'].isEmpty) {
        throw Exception('No text content in response');
      }
      
      final feedback = content['parts'][0]['text'];
      
      print('✅ Evaluation complete');
      print('📝 Feedback length: ${feedback.length} characters');

      return GeminiEvaluationResult(
        feedback: feedback.trim(),
        evaluatedAt: DateTime.now(),
      );
    } else {
      print('❌ Full error response:');
      print(response.body);
      throw Exception('Gemini API error: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> _prepareImages(List<String> photoPaths) async {
    final imageParts = <Map<String, dynamic>>[];

    for (int i = 0; i < photoPaths.length; i++) {
      final imageFile = File(photoPaths[i]);
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      imageParts.add({
        "inline_data": {
          "mime_type": "image/jpeg",
          "data": base64Image,
        }
      });

      print('📸 Prepared photo ${i + 1}/${photoPaths.length}');
    }

    return imageParts;
  }

  String _buildEvaluationPrompt({
    required Challenge challenge,
    required int photoCount,
    required String photographyStyle,
    required String skillLevel,
  }) {
    return '''
You are an expert photography instructor evaluating a student's work.

CHALLENGE DETAILS:
Day: ${challenge.dayNumber}
Title: ${challenge.title}
Style: $photographyStyle
Level: $skillLevel
Description: ${challenge.description}
Tips Given: ${challenge.tips ?? 'None'}

The student has submitted $photoCount photos for this challenge. Please analyze the images and provide comprehensive feedback.

Your feedback should cover:

1. **Overall Assessment**: How well do these photos meet the challenge requirements?

2. **Photo-by-Photo Analysis**: Brief comments on each photo (Photo 1, Photo 2, Photo 3)

3. **What Worked Well**: Specific strengths (composition, lighting, technique, creativity)

4. **Areas to Improve**: Constructive suggestions for growth

5. **Technical Feedback**: Comments on exposure, focus, settings, etc.

6. **Creative Feedback**: Thoughts on artistic choices and storytelling

7. **Next Steps**: Specific actionable advice for continued learning

Keep your feedback:
- Encouraging and supportive
- Specific to what you see in the images
- Appropriate for a $skillLevel level photographer
- Focused on growth and learning
- Natural and conversational in tone

Write comprehensive but concise feedback (aim for 300-400 words).''';
  }
}