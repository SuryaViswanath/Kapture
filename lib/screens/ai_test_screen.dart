// lib/screens/ai_test_screen.dart

import 'package:flutter/material.dart';
import '../services/learning_manager.dart';

class AITestScreen extends StatefulWidget {
  const AITestScreen({Key? key}) : super(key: key);

  @override
  State<AITestScreen> createState() => _AITestScreenState();
}

class _AITestScreenState extends State<AITestScreen> {
  String selectedStyle = 'Portrait';
  String selectedDifficulty = 'Beginner';
  int numberOfDays = 7;

  String? outputText;
  bool isGenerating = false;
  String? error;

  final List<String> styles = ['Street', 'Portrait', 'Landscape', 'Wildlife'];
  final List<String> difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  Future<void> _generate() async {
    setState(() {
      isGenerating = true;
      outputText = null;
      error = null;
    });

    try {
      final text = await LearningManager.instance.generateText(
        style: selectedStyle,
        difficulty: selectedDifficulty,
        days: numberOfDays,
      );

      if (mounted) {
        setState(() {
          outputText = text;
          isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Test'),
      ),
      body: Column(
        children: [
          // Input Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Style:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: selectedStyle,
                  isExpanded: true,
                  items: styles.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (value) => setState(() => selectedStyle = value!),
                ),
                const SizedBox(height: 16),
                
                const Text('Difficulty:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: selectedDifficulty,
                  isExpanded: true,
                  items: difficulties.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (value) => setState(() => selectedDifficulty = value!),
                ),
                const SizedBox(height: 16),
                
                Text('Days: $numberOfDays', style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: numberOfDays.toDouble(),
                  min: 3,
                  max: 30,
                  divisions: 27,
                  label: '$numberOfDays',
                  onChanged: (value) => setState(() => numberOfDays = value.toInt()),
                ),
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isGenerating ? null : _generate,
                    child: const Text('Generate'),
                  ),
                ),
              ],
            ),
          ),

          // Output Section
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: isGenerating
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Generating...'),
                        ],
                      ),
                    )
                  : error != null
                      ? Center(
                          child: Text(
                            'Error: $error',
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : outputText != null
                          ? SingleChildScrollView(
                              child: SelectableText(
                                outputText!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : const Center(
                              child: Text('Press Generate to see AI output'),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}