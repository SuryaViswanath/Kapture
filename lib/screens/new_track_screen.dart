// lib/screens/new_track_screen.dart

import 'package:flutter/material.dart';
import '../services/track_service.dart';
import '../services/learning_manager.dart';
import '../models/user.dart';

class NewTrackScreen extends StatefulWidget {
  const NewTrackScreen({Key? key}) : super(key: key);

  @override
  State<NewTrackScreen> createState() => _NewTrackScreenState();
}

class _NewTrackScreenState extends State<NewTrackScreen> {
  User? currentUser;
  String? selectedStyle;
  String selectedFocus = 'Specific technique';
  int selectedDuration = 7;
  String selectedDifficulty = 'Medium';

  bool isLoading = false;
  bool isGenerating = false;

  final List<String> focusAreas = [
    'Specific technique',
    'Camera mastery',
    'Creative composition',
  ];

  final List<int> durations = [7, 14, 21, 30];
  final List<String> difficulties = ['Easy', 'Medium', 'Hard'];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => isLoading = true);
    currentUser = await TrackService.instance.getCurrentUser();
    if (currentUser != null && currentUser!.photographyStyles.isNotEmpty) {
      selectedStyle = currentUser!.photographyStyles.first;
    }
    setState(() => isLoading = false);
  }

    Future<void> _generateTrack() async {
    if (selectedStyle == null) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a photography style')),
        );
        return;
    }

    setState(() => isGenerating = true);

    try {
        final level = selectedDifficulty == 'Easy'
            ? 'Beginner'
            : selectedDifficulty == 'Hard'
                ? 'Advanced'
                : 'Intermediate';

        // Generate plan (download happens inside if needed)
        await LearningManager.instance.generatePlan(
        userId: currentUser!.id!,
        style: selectedStyle!,
        level: level,
        durationDays: selectedDuration,
        );

        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Track created successfully!')),
        );
        Navigator.pop(context);
        }
    } catch (e) {
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error: ${e.toString()}')),
        );
        }
    } finally {
        setState(() => isGenerating = false);
    }
    }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Track'),
      ),
      body: isGenerating ? _buildGeneratingView() : _buildFormView(),
    );
  }

  Widget _buildGeneratingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Generating your personalized track...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'This may take a minute',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photography Style
          const Text(
            'Photography Style',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (currentUser != null)
            Wrap(
              spacing: 8,
              children: currentUser!.photographyStyles.map((style) {
                return ChoiceChip(
                  label: Text(style),
                  selected: selectedStyle == style,
                  onSelected: (selected) {
                    setState(() => selectedStyle = style);
                  },
                );
              }).toList(),
            ),

          const SizedBox(height: 32),

          // Focus Area
          const Text(
            'Focus Area',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: focusAreas.map((focus) {
              return ChoiceChip(
                label: Text(focus),
                selected: selectedFocus == focus,
                onSelected: (selected) {
                  setState(() => selectedFocus = focus);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Duration
          const Text(
            'Duration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: durations.map((days) {
              final isSelected = selectedDuration == days;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => selectedDuration = days);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.blue : null,
                      foregroundColor: isSelected ? Colors.white : null,
                    ),
                    child: Text('$days days'),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Difficulty
          const Text(
            'Difficulty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: difficulties.map((difficulty) {
              final isSelected = selectedDifficulty == difficulty;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => selectedDifficulty = difficulty);
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSelected ? Colors.blue : null,
                      foregroundColor: isSelected ? Colors.white : null,
                    ),
                    child: Text(difficulty),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 48),

          // Generate Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _generateTrack,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Generate Track',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}