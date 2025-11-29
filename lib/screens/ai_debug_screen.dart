// lib/screens/ai_debug_screen.dart

import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';

class AIDebugScreen extends StatefulWidget {
  const AIDebugScreen({Key? key}) : super(key: key);

  @override
  State<AIDebugScreen> createState() => _AIDebugScreenState();
}

class _AIDebugScreenState extends State<AIDebugScreen> {
  final CactusLM _llm = CactusLM();
  bool _isInitialized = false;
  String _output = '';
  bool _isLoading = false;

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    try {
      await _llm.downloadModel(
        model: "gemma3-270m",
        downloadProcessCallback: (progress, status, isError) {
          setState(() {
            _output += '$status ${progress != null ? '(${(progress * 100).toInt()}%)' : ''}\n';
          });
        },
      );

      await _llm.initializeModel(
        params: CactusInitParams(
          model: "gemma3-270m",
          contextSize: 2048,
        ),
      );

      _isInitialized = true;
      setState(() {
        _output += '\n✅ Model initialized!\n\n';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _output += '\n❌ Error: $e\n';
        _isLoading = false;
      });
    }
  }

  Future<void> _testCompletion() async {
    if (!_isInitialized) {
      setState(() => _output += '\n❌ Model not initialized\n');
      return;
    }

    setState(() {
      _isLoading = true;
      _output += '\n🤖 Generating...\n';
    });

    try {
      final messages = [
        ChatMessage(
          role: 'user',
          content: 'Generate a simple JSON with 2 photography challenges. Format: {"challenges": [{"day": 1, "title": "Challenge 1"}, {"day": 2, "title": "Challenge 2"}]}',
        ),
      ];

      final result = await _llm.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(
          maxTokens: 500,
          temperature: 0.3,
        ),
      );

      setState(() {
        _output += '\n📝 RAW OUTPUT:\n';
        _output += '='*50 + '\n';
        _output += result.response;
        _output += '\n' + '='*50 + '\n';
        _output += '\nSuccess: ${result.success}\n';
        _output += 'Tokens/sec: ${result.tokensPerSecond}\n\n';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _output += '\n❌ Error: $e\n';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() => _output = '');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _initialize,
                    child: const Text('1. Initialize Model'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isInitialized && !_isLoading) ? _testCompletion : null,
                    child: const Text('2. Test Completion'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _output.isEmpty ? 'Press "Initialize Model" to start' : _output,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _llm.unload();
    }
    super.dispose();
  }
}