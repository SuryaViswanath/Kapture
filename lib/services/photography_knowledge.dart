// lib/services/photography_knowledge.dart

class PhotographyKnowledge {
  static const Map<String, String> knowledgeBase = {
    'iso': '''
ISO controls your camera's sensitivity to light. 
- Low ISO (100-400): Use in bright conditions, produces cleanest images
- Medium ISO (400-800): Good for cloudy days or indoor with windows
- High ISO (800-3200+): Low light situations, but increases grain/noise
Rule of thumb: Use the lowest ISO possible for your lighting conditions.
''',
    'aperture': '''
Aperture (f-stop) controls depth of field and light intake.
- Large aperture (f/1.4-f/2.8): Blurry background, more light, good for portraits
- Medium aperture (f/4-f/8): Balanced, good for general photography
- Small aperture (f/11-f/22): Everything sharp, less light, good for landscapes
Lower f-number = larger opening = more light = blurrier background
''',
    'shutter speed': '''
Shutter speed controls motion blur and light exposure.
- Fast (1/500s+): Freeze action, sports, wildlife
- Medium (1/60s-1/250s): General photography, handheld shots
- Slow (1/30s-): Motion blur, waterfalls, night photography (needs tripod)
Rule: For handheld, use at least 1/focal_length (e.g., 50mm lens = 1/50s minimum)
''',
    'golden hour': '''
Golden hour is the period shortly after sunrise or before sunset.
Benefits:
- Soft, warm, flattering light
- Long shadows for depth
- Beautiful sky colors
Tips:
- Arrive 30 minutes early to prepare
- Shoot with sun at 45° angle
- Use reflectors to fill shadows
- Works great for portraits and landscapes
''',
    'composition': '''
Key composition techniques:
1. Rule of Thirds: Place subjects on intersecting lines
2. Leading Lines: Use roads, rivers, fences to guide eye
3. Framing: Use natural frames (windows, arches)
4. Symmetry: Create balance in the image
5. Negative Space: Let subject breathe
6. Foreground Interest: Add depth to landscapes
''',
    'white balance': '''
White balance adjusts color temperature.
- Auto: Let camera decide (works 80% of time)
- Daylight (5500K): Sunny outdoor conditions
- Cloudy (6500K): Overcast days
- Shade (7500K): Open shade
- Tungsten (3200K): Indoor incandescent lights
- Fluorescent (4000K): Office lighting
Tip: Shoot RAW to adjust later
''',
    'exposure triangle': '''
The Exposure Triangle balances three elements:
1. ISO: Sensitivity to light
2. Aperture: Size of lens opening
3. Shutter Speed: How long sensor exposed

They work together:
- Increase ISO → Can use faster shutter or smaller aperture
- Larger aperture → Can use lower ISO or faster shutter
- Slower shutter → Can use lower ISO or smaller aperture

Master this and you control your camera!
''',
  };

  static String search(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Simple keyword matching
    for (var entry in knowledgeBase.entries) {
      if (lowerQuery.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Fuzzy matching for common questions
    if (lowerQuery.contains('night') || lowerQuery.contains('dark')) {
      return knowledgeBase['iso']!;
    }
    if (lowerQuery.contains('blur') || lowerQuery.contains('background')) {
      return knowledgeBase['aperture']!;
    }
    if (lowerQuery.contains('motion') || lowerQuery.contains('freeze') || lowerQuery.contains('action')) {
      return knowledgeBase['shutter speed']!;
    }
    if (lowerQuery.contains('sunset') || lowerQuery.contains('sunrise')) {
      return knowledgeBase['golden hour']!;
    }
    if (lowerQuery.contains('color') || lowerQuery.contains('temperature')) {
      return knowledgeBase['white balance']!;
    }
    
    return '';
  }

  static List<String> getSuggestedQuestions() {
    return [
      'What ISO should I use?',
      'Explain aperture',
      'Best time for portraits?',
      'How to freeze motion?',
      'Rule of thirds explained',
      'What is white balance?',
    ];
  }
}