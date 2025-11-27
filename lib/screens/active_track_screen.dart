// lib/screens/active_track_screen.dart - COMPLETE REPLACEMENT

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/challenge.dart';
import '../models/subtask.dart';
import '../services/subtask_service.dart';
import '../services/database_helper.dart';
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
    await _loadData(); // Reload to update UI
  }

  Future<void> _pickPhoto() async {
    if (photoPaths.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
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
        
        // Save to database
        await _savePhotos();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo added!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    if (photoPaths.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo added!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _savePhotos() async {
    final db = await DatabaseHelper.instance.database;
    
    // Check if submission exists
    final existing = await db.query(
      'submissions',
      where: 'challenge_id = ?',
      whereArgs: [widget.challenge.id],
    );
    
    final photoPathsString = photoPaths.join(',');
    
    if (existing.isEmpty) {
      // Create new submission
      await db.insert('submissions', {
        'challenge_id': widget.challenge.id,
        'photo_paths': photoPathsString,
        'submitted_at': null,
        'validated': 0,
      });
    } else {
      // Update existing
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
        const SnackBar(content: Text('Please upload 3 photos before submitting')),
      );
      return;
    }

    // Check if all subtasks are completed
    final allCompleted = await SubtaskService.instance.areAllSubtasksCompleted(widget.challenge.id!);
    
    if (!allCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all subtasks first')),
      );
      return;
    }

    // Mark as submitted (cloud validation will come later)
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'submissions',
      {'submitted_at': DateTime.now().toIso8601String()},
      where: 'challenge_id = ?',
      whereArgs: [widget.challenge.id],
    );

    // Mark challenge as completed
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
        const SnackBar(content: Text('✅ Challenge completed! (Cloud validation coming soon)')),
      );
      Navigator.pop(context); // Go back to home
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
        title: Text('Day ${widget.challenge.dayNumber}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Challenge Title
            Text(
              widget.challenge.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Challenge Description
            const Text(
              'Challenge Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.challenge.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Tips Section
            if (widget.challenge.tips != null && widget.challenge.tips!.isNotEmpty) ...[
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Tips',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '• ${widget.challenge.tips}',
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Subtasks Section
            const Text(
              'Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            ...subtasks.map((subtask) => _buildSubtaskCard(subtask)),

            const SizedBox(height: 24),

            // Photos Section
            Text(
              'Photos (${photoPaths.length}/3)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _buildPhotoGrid(),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: photoPaths.length == 3 ? _submitForReview : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Submit for Review',
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
      ),
      floatingActionButton: FloatingActionButton(  // <-- ADD THIS
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChatScreen()),
      );
    },
    child: const Icon(Icons.chat),
    backgroundColor: Colors.blue,
  ),
    );
  }

  Widget _buildSubtaskCard(Subtask subtask) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: CheckboxListTile(
        value: subtask.completed,
        onChanged: (value) => _toggleSubtask(subtask),
        title: Text(subtask.title),
        subtitle: subtask.description != null ? Text(subtask.description!) : null,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photoPaths.length + (photoPaths.length < 3 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < photoPaths.length) {
          // Show existing photo
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(photoPaths[index]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removePhoto(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
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
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400, width: 2),
              ),
              child: const Icon(
                Icons.add_photo_alternate,
                size: 40,
                color: Colors.grey,
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }
}