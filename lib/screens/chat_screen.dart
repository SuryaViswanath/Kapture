// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart' as cactus;
import '../services/chat_service.dart';
import '../services/track_service.dart';
import '../services/photography_knowledge.dart';
import '../models/challenge.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final Challenge? currentChallenge; // Optional challenge context
  
  const ChatScreen({Key? key, this.currentChallenge}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> messages = [];
  bool isLoading = false;
  bool isSending = false;
  int? currentUserId;
  
  final cactus.CactusLM _llm = cactus.CactusLM();
  bool _isLLMInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadChat();
    _initializeLLM();
  }

  Future<void> _initializeLLM() async {
    try {
      print('🤖 Initializing chat LLM...');
      
      await _llm.downloadModel(
        model: "local-lfm2-vl-450m",
        downloadProcessCallback: (progress, status, isError) {
          if (isError) {
            print('❌ Chat LLM download error: $status');
          } else {
            final percentage = progress != null ? '(${(progress * 100).toInt()}%)' : '';
            print('📥 Chat LLM: $status $percentage');
          }
        },
      );

      await _llm.initializeModel(
        params: cactus.CactusInitParams(
          model: "local-lfm2-vl-450m",
          contextSize: 2048,
        ),
      );

      _isLLMInitialized = true;
      print('✅ Chat LLM initialized successfully');
    } catch (e) {
      print('❌ Error initializing chat LLM: $e');
      // Will fall back to keyword-based responses
    }
  }

  Future<void> _loadChat() async {
    setState(() => isLoading = true);

    final user = await TrackService.instance.getCurrentUser();
    if (user != null) {
      currentUserId = user.id;
      messages = await ChatService.instance.getChatHistory(user.id!);
    }

    setState(() => isLoading = false);
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || currentUserId == null) return;

    final userMessage = ChatMessage(
      userId: currentUserId!,
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() {
      messages.add(userMessage);
      isSending = true;
      _controller.clear();
    });

    await ChatService.instance.saveMessage(userMessage);
    _scrollToBottom();

    String response;

    if (_isLLMInitialized) {
      // Use AI-powered response
      response = await _generateAIResponse(text);
    } else {
      // Fallback to keyword-based response
      response = _generateKeywordResponse(text);
    }

    final assistantMessage = ChatMessage(
      userId: currentUserId!,
      role: 'assistant',
      content: response,
      createdAt: DateTime.now(),
    );

    setState(() {
      messages.add(assistantMessage);
      isSending = false;
    });

    await ChatService.instance.saveMessage(assistantMessage);
    _scrollToBottom();
  }

  Future<String> _generateAIResponse(String userQuery) async {
    try {
      print('💬 Generating AI response...');
      
      // Build context-aware system prompt
      final systemPrompt = _buildSystemPrompt();
      
      // Get conversation history (last 6 messages for context)
      final recentMessages = messages.length > 6 
          ? messages.sublist(messages.length - 6)
          : messages;
      
      // Build message list
      final chatMessages = [
        cactus.ChatMessage(
          role: 'system',
          content: systemPrompt,
        ),
        // Add conversation history
        ...recentMessages.map((msg) => cactus.ChatMessage(
          role: msg.role,
          content: msg.content,
        )),
      ];

      final result = await _llm.generateCompletion(
        messages: chatMessages,
        params: cactus.CactusCompletionParams(
          maxTokens: 500,
          temperature: 0.7,
          stopSequences: ["<|im_end|>", "<end_of_turn>"],
        ),
      );

      if (result.success) {
        print('✅ AI response generated');
        return result.response.trim();
      } else {
        print('❌ AI generation failed, using fallback');
        return _generateKeywordResponse(userQuery);
      }
    } catch (e) {
      print('❌ Error generating AI response: $e');
      return _generateKeywordResponse(userQuery);
    }
  }

  String _buildSystemPrompt() {
    if (widget.currentChallenge != null) {
      // Challenge-specific context
      return '''You are a helpful photography instructor assisting with a specific challenge.

CURRENT CHALLENGE CONTEXT:
- Day: ${widget.currentChallenge!.dayNumber}
- Title: ${widget.currentChallenge!.title}
- Description: ${widget.currentChallenge!.description}
- Tips: ${widget.currentChallenge!.tips ?? 'None provided'}

Your role:
1. Help the user complete THIS specific challenge
2. Answer questions about the challenge requirements
3. Provide technical advice related to this challenge
4. Suggest creative approaches for this specific task
5. Troubleshoot any issues they're facing

Keep responses concise (2-3 paragraphs max), practical, and encouraging. Focus on helping them succeed with today's challenge.''';
    } else {
      // General photography context
      return '''You are a knowledgeable and friendly photography instructor.

Your expertise includes:
- Camera settings (ISO, aperture, shutter speed)
- Composition techniques (rule of thirds, leading lines, framing)
- Lighting (golden hour, natural light, artificial light)
- Different photography styles (portrait, landscape, street, wildlife, etc.)
- Post-processing basics
- Creative techniques and tips

Keep responses:
- Concise (2-3 paragraphs maximum)
- Practical and actionable
- Encouraging and supportive
- Easy to understand for all skill levels

If asked about topics outside photography, politely redirect to photography-related questions.''';
    }
  }

  String _generateKeywordResponse(String query) {
    // First try knowledge base
    final knowledge = PhotographyKnowledge.search(query);
    
    if (knowledge.isNotEmpty) {
      return knowledge.trim();
    }

    // Challenge-specific fallback
    if (widget.currentChallenge != null) {
      return '''I'm here to help with your current challenge: "${widget.currentChallenge!.title}"

${widget.currentChallenge!.description}

${widget.currentChallenge!.tips != null ? 'Tips:\n${widget.currentChallenge!.tips}' : ''}

What specific aspect would you like help with?''';
    }

    // General fallback
    return '''I don't have specific information about that yet. Here are some topics I can help with:

- ISO and exposure settings
- Aperture and depth of field
- Shutter speed and motion
- Golden hour photography
- Composition techniques
- White balance

Try asking about any of these!''';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Icon(
                Icons.smart_toy,
                size: 20,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Photography AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    widget.currentChallenge != null 
                        ? 'Day ${widget.currentChallenge!.dayNumber} Helper'
                        : 'Always here to help',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.textPrimary),
              onPressed: () => _confirmClearChat(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Challenge Context Banner (if in challenge context)
          if (widget.currentChallenge != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(color: AppTheme.accentColor.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentChallenge!.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'I can help with this challenge',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Divider
          if (widget.currentChallenge == null)
            Container(
              height: 1,
              color: AppTheme.borderColor,
            ),

          // Messages List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentColor,
                      strokeWidth: 2,
                    ),
                  )
                : messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(messages[index]);
                        },
                      ),
          ),

          // Suggested Questions (show when empty)
          if (messages.isEmpty && !isLoading) _buildSuggestedQuestions(),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              border: Border(
                top: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !isSending,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.currentChallenge != null
                            ? 'Ask about this challenge...'
                            : 'Ask about photography...',
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.6),
                        ),
                        filled: true,
                        fillColor: AppTheme.cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.accentColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (text) => _sendMessage(text),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: isSending ? null : () => _sendMessage(_controller.text),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSending ? AppTheme.borderColor : AppTheme.accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderColor, width: 2),
              ),
              child: Icon(
                widget.currentChallenge != null ? Icons.camera_alt : Icons.camera_alt,
                size: 48,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.currentChallenge != null 
                  ? 'Challenge Assistant'
                  : 'Photography Assistant',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.currentChallenge != null
                  ? 'Ask me anything about completing\n"${widget.currentChallenge!.title}"'
                  : 'Ask me anything about camera settings,\ntechniques, and photography tips',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    final suggestions = widget.currentChallenge != null
        ? _getChallengeSpecificQuestions()
        : PhotographyKnowledge.getSuggestedQuestions();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor.withOpacity(0.5), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.currentChallenge != null ? 'Ask about this challenge' : 'Quick questions',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((question) {
              return GestureDetector(
                onTap: () {
                  _controller.text = question;
                  _sendMessage(question);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<String> _getChallengeSpecificQuestions() {
    return [
      'What settings should I use?',
      'Where should I shoot this?',
      'How do I compose this shot?',
      'What time of day is best?',
      'Any creative tips?',
    ];
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Icon(
                Icons.smart_toy,
                size: 18,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primaryColor : AppTheme.cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 20 : 4),
                  topRight: Radius.circular(isUser ? 4 : 20),
                  bottomLeft: const Radius.circular(20),
                  bottomRight: const Radius.circular(20),
                ),
                border: Border.all(
                  color: isUser ? AppTheme.accentColor : AppTheme.borderColor,
                  width: isUser ? 2 : 1,
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accentColor, width: 2),
              ),
              child: const Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text(
          'Clear Chat History?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const Text(
          'This will delete all messages. This action cannot be undone.',
          style: TextStyle(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentColor,
            ),
            child: const Text(
              'Clear',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && currentUserId != null) {
      await ChatService.instance.clearHistory(currentUserId!);
      setState(() => messages.clear());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    if (_isLLMInitialized) {
      _llm.unload();
    }
    super.dispose();
  }
}