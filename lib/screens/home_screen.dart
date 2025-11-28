// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../services/track_service.dart';
import '../models/user.dart';
import '../models/track.dart';
import '../models/challenge.dart';
import 'new_track_screen.dart';
import 'active_track_screen.dart';
import 'profile_screen.dart';
import 'model_status_screen.dart';
import 'chat_screen.dart';
import 'ai_debug_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? currentUser;
  Track? activeTrack;
  Challenge? todayChallenge;
  Map<String, dynamic> trackProgress = {};
  List<Challenge> recentChallenges = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    currentUser = await TrackService.instance.getCurrentUser();
    
    if (currentUser != null) {
      activeTrack = await TrackService.instance.getActiveTrack(currentUser!.id!);
      
      if (activeTrack != null) {
        todayChallenge = await TrackService.instance.getTodayChallenge(activeTrack!.id!);
        trackProgress = await TrackService.instance.getTrackProgress(activeTrack!.id!);
        recentChallenges = await TrackService.instance.getRecentChallenges(activeTrack!.id!);
      }
    }

    setState(() => isLoading = false);
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
  leading: const Icon(Icons.menu),
  title: const Text('Kapture'),
  actions: [
    // ADD THIS DEBUG BUTTON
    IconButton(
    icon: const Icon(Icons.bug_report),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AIDebugScreen()),
      );
    },
  ),
    IconButton(
      icon: const Icon(Icons.storage),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ModelStatusScreen()),
        );
      },
    ),
    IconButton(
      icon: const Icon(Icons.person),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      },
    ),
  ],
),
      body: activeTrack == null ? _buildNoTrackView() : _buildTrackView(),
      floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
  },
  child: const Icon(Icons.chat),
),
    );
  }

  Widget _buildNoTrackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'No Active Track',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create your first practice track to start learning!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NewTrackScreen()),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.add),
              label: const Text('Create New Track'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackView() {
    final progress = trackProgress['progress'] ?? 0.0;
    final currentDay = trackProgress['currentDay'] ?? 0;
    final totalDays = trackProgress['totalDays'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Section
            Text(
              '📅 Day $currentDay of $totalDays',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toInt()}% complete',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 32),

            // Today's Challenge
            const Text(
              'Today\'s Challenge 🎯',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (todayChallenge != null)
              _buildChallengeCard(todayChallenge!)
            else
              _buildNoChallengeCard(),

            const SizedBox(height: 32),

            // Recent Activity
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...recentChallenges.take(3).map((challenge) => _buildActivityItem(challenge)),

            const SizedBox(height: 24),

            // Create New Track Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NewTrackScreen()),
                  ).then((_) => _loadData());
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Custom Track'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveTrackScreen(challenge: challenge),
            ),
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                challenge.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                challenge.description,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              // Subtasks preview (we'll add this later)
              const Row(
                children: [
                  Icon(Icons.check_box_outline_blank, size: 20),
                  SizedBox(width: 8),
                  Text('Setup shot'),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.check_box_outline_blank, size: 20),
                  SizedBox(width: 8),
                  Text('Capture photos (0/3)'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActiveTrackScreen(challenge: challenge),
                      ),
                    ).then((_) => _loadData());
                  },
                  child: const Text('Start Challenge'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoChallengeCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No challenge for today. Great job staying ahead!',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(Challenge challenge) {
    return ListTile(
      leading: Icon(
        challenge.completed ? Icons.check_circle : Icons.schedule,
        color: challenge.completed ? Colors.green : Colors.orange,
      ),
      title: Text('Day ${challenge.dayNumber}: ${challenge.title}'),
      subtitle: Text(challenge.completed ? 'Completed' : 'Pending'),
    );
  }
}