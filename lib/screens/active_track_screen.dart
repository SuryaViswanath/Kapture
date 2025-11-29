// lib/screens/active_track_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/challenge.dart';
import '../models/subtask.dart';
import '../services/subtask_service.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class ActiveTrackScreen extends StatefulWidget {
  final Challenge challenge;
  
  const ActiveTrackScreen({Key? key, required this.challenge}) : super(key: key);

  @override
  State<ActiveTrackScreen> createState() => _ActiveTrackScreenState();
}

class _ActiveTrackScreenState extends State<ActiveTrackScreen> {
  List<Subtask> subtasks = [];
  List<String> photoPaths = [];
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    subtasks = await SubtaskService.instance.getChallengeSubtasks(widget.challenge.id!);
    
    // Load existing photos if any
    final db = await DatabaseHelper.instance.database;
    final submissions = await db.query(
      'submissions',
      where: 'challenge_id = ?',
      whereArgs: [widget.challenge.id],
      limit: 1,
    );
    
    if (submissions.isNotEmpty) {
      final pathsJson = submissions.first['photo_paths'] as String;
      photoPaths = (pathsJson.split(','))
          .where((p) => p.isNotEmpty)
          .toList();
    }
    
    setState(() => isLoading = false);
  }

  Future<void> _toggleSubtask(Subtask subtask) async {
    await SubtaskService.instance.toggleSubtask(subtask.id!, !subtask.completed);
    await _loadData();
  }

  Future<void> _pickPhoto() async {
    if (photoPaths.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum 3 photos allowed'),
          backgroundColor: AppTheme.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          photoPaths.add(photo.path);
        });
        
        await _savePhotos();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Photo added!'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (photoPaths.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum 3 photos allowed'),
          backgroundColor: AppTheme.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          photoPaths.add(photo.path);
        });
        
        await _savePhotos();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Photo added!'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _savePhotos() async {
    final db = await DatabaseHelper.instance.database;
    
    final existing = await db.query(
      'submissions',
      where: 'challenge_id = ?',
      whereArgs: [widget.challenge.id],
    );
    
    final photoPathsString = photoPaths.join(',');
    
    if (existing.isEmpty) {
      await db.insert('submissions', {
        'challenge_id': widget.challenge.id,
        'photo_paths': photoPathsString,
        'submitted_at': null,
        'validated': 0,
      });
    } else {
      await db.update(
        'submissions',
        {'photo_paths': photoPathsString},
        where: 'challenge_id = ?',
        whereArgs: [widget.challenge.id],
      );
    }
  }

  Future<void> _removePhoto(int index) async {
    setState(() {
      photoPaths.removeAt(index);
    });
    await _savePhotos();
  }

  Future<void> _submitForReview() async {
    if (photoPaths.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please upload 3 photos before submitting'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final allCompleted = await SubtaskService.instance.areAllSubtasksCompleted(widget.challenge.id!);
    
    if (!allCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all tasks first'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final db = await DatabaseHelper.instance.database;
    await db.update(
      'submissions',
      {'submitted_at': DateTime.now().toIso8601String()},
      where: 'challenge_id = ?',
      whereArgs: [widget.challenge.id],
    );

    await db.update(
      'challenges',
      {
        'completed': 1,
        'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [widget.challenge.id],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Challenge completed!'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.accentColor,
            strokeWidth: 2,
          ),
        ),
      );
    }

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
            Text(
              'Day ${widget.challenge.dayNumber}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Challenge Title
            Text(
              widget.challenge.title,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -1.0,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 24),

            // Description Section
            _buildSectionHeader('Description', Icons.description),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Text(
                widget.challenge.description,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tips Section
            if (widget.challenge.tips != null && widget.challenge.tips!.isNotEmpty) ...[
              _buildSectionHeader('Pro Tips', Icons.lightbulb_outline),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accentColor, width: 2),
                ),
                child: Text(
                  '• ${widget.challenge.tips}',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Tasks Section
            _buildSectionHeader('Tasks', Icons.checklist),
            const SizedBox(height: 12),
            ...subtasks.map((subtask) => _buildSubtaskCard(subtask)),

            const SizedBox(height: 24),

            // Photos Section
            _buildSectionHeader('Photos (${photoPaths.length}/3)', Icons.photo_library),
            const SizedBox(height: 12),
            _buildPhotoGrid(),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: photoPaths.length == 3 ? _submitForReview : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: photoPaths.length == 3 ? AppTheme.accentColor : AppTheme.borderColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_circle, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Submit Challenge',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.accentColor, width: 2),
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          },
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppTheme.accentColor,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildSubtaskCard(Subtask subtask) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _toggleSubtask(subtask),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: subtask.completed ? AppTheme.primaryColor : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: subtask.completed ? AppTheme.accentColor : AppTheme.borderColor,
              width: subtask.completed ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: subtask.completed 
                      ? AppTheme.accentColor 
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: subtask.completed 
                        ? AppTheme.accentColor 
                        : AppTheme.borderColor,
                    width: 2,
                  ),
                ),
                child: subtask.completed
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtask.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: subtask.completed ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    if (subtask.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtask.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: subtask.completed 
                              ? Colors.white.withOpacity(0.8)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: photoPaths.length + (photoPaths.length < 3 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < photoPaths.length) {
          // Show existing photo
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(photoPaths[index]),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => _removePhoto(index),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppTheme.accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          // Show add photo button
          return GestureDetector(
            onTap: () => _showPhotoOptions(),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor, width: 2),
              ),
              child: const Icon(
                Icons.add_photo_alternate,
                size: 36,
                color: AppTheme.textSecondary,
              ),
            ),
          );
        }
      },
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              _buildPhotoOption(
                icon: Icons.camera_alt,
                title: 'Take Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto();
                },
              ),
              const SizedBox(height: 12),
              _buildPhotoOption(
                icon: Icons.photo_library,
                title: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.accentColor, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}