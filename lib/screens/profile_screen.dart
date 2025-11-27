// lib/screens/profile_screen.dart - COMPLETE REPLACEMENT

import 'package:flutter/material.dart';
import '../services/track_service.dart';
import '../models/user.dart';
import '../models/track.dart';
import 'onboarding_screen.dart';
import '../services/database_helper.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser;
  List<Track> allTracks = [];
  int completedChallenges = 0;
  int currentStreak = 0;
  int totalPhotos = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => isLoading = true);

    currentUser = await TrackService.instance.getCurrentUser();
    
    if (currentUser != null) {
      allTracks = await TrackService.instance.getUserTracks(currentUser!.id!);
      await _calculateStats();
    }

    setState(() => isLoading = false);
  }

  Future<void> _calculateStats() async {
  if (currentUser == null) return;

  // Get database instance
  final db = await DatabaseHelper.instance.database;
  
  // Get completed challenges count
  final completedResult = await db.rawQuery(
    'SELECT COUNT(*) as count FROM challenges WHERE completed = 1',
  );
  completedChallenges = completedResult.first['count'] as int? ?? 0;

  // Get total photos submitted
  final photosResult = await db.rawQuery(
    'SELECT COUNT(*) as count FROM submissions WHERE submitted_at IS NOT NULL',
  );
  totalPhotos = (photosResult.first['count'] as int? ?? 0) * 3; // 3 photos per submission

  // Calculate current streak (simplified - mock for now)
  currentStreak = 5; // TODO: Implement proper streak calculation later
}
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('No user found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Profile Picture & Name
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue.shade100,
              child: currentUser!.profilePicture != null
                  ? ClipOval(
                      child: Image.network(
                        currentUser!.profilePicture!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.person, size: 60, color: Colors.blue),
            ),
            const SizedBox(height: 16),

            Text(
              currentUser!.username,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              currentUser!.email,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 8),

            // Photography Styles
            Wrap(
              spacing: 8,
              children: currentUser!.photographyStyles.map((style) {
                return Chip(
                  label: Text(style),
                  backgroundColor: Colors.blue.shade50,
                );
              }).toList(),
            ),

            const SizedBox(height: 32),
            const Divider(),

            // Statistics Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bar_chart, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildStatRow('Tracks Completed', '${allTracks.where((t) => !t.isActive).length}'),
                  _buildStatRow('Active Tracks', '${allTracks.where((t) => t.isActive).length}'),
                  _buildStatRow('Challenges Completed', '$completedChallenges'),
                  _buildStatRow('Current Streak', '$currentStreak days 🔥'),
                  _buildStatRow('Photos Submitted', '$totalPhotos'),
                  _buildStatRow('Skill Level', currentUser!.skillLevel),
                ],
              ),
            ),

            const Divider(),

            // Settings Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon!')),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Storage'),
                    subtitle: const Text('Manage downloaded models'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon!')),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAboutDialog(),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Preferences Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.palette_outlined, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Preferences',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ListTile(
                    leading: const Icon(Icons.camera_outlined),
                    title: const Text('Change Photography Styles'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon!')),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Restart Onboarding'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _confirmRestartOnboarding(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Sign Out Button (placeholder)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sign out coming soon!')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Sign Out'),
                ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Kapture'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kapture - Offline Photography Learning Assistant'),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 16),
            Text('Learn photography anywhere with AI-powered guidance that works offline.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestartOnboarding() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Onboarding?'),
        content: const Text(
          'This will take you through the setup process again. Your current tracks and progress will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }
}