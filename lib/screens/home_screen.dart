// lib/screens/home_screen.dart - COMPLETE REPLACEMENT

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/track_service.dart';
import '../models/user.dart';
import '../models/track.dart';
import '../models/challenge.dart';
import 'new_track_screen.dart';
import 'active_track_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key?  key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  User? currentUser;
  Track? activeTrack;
  List<Track> allTracks = [];
  int currentStreak = 0;
  bool isLoading = true;
  int _currentChallengeIndex = 0;
  
  late AnimationController _rotationController;
  late AnimationController _streakController;
  int _currentPhotoIndex = 0;
  final PageController _photoPageController = PageController();
  final PageController _challengePageController = PageController(viewportFraction: 0.8);

  // Mock data for photos of the week with image paths
  final List<Map<String, String>> photosOfWeek = [
    {
      'user': 'Sarah M.',
      'style': 'Street Photography',
      'image': 'assets/images/pic1.jpg',
    },
    {
      'user': 'John D.',
      'style': 'Portrait',
      'image': 'assets/images/pic2.jpg',
    },
    {
      'user': 'Emma R.',
      'style': 'Landscape',
      'image': 'assets/images/pic3.jpg',
    },
  ];

  @override
  void initState() {
    super. initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    
    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _loadData();
    _startPhotoCarousel();
  }

  void _startPhotoCarousel() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _photoPageController.hasClients) {
        final nextPage = (_currentPhotoIndex + 1) % photosOfWeek.length;
        _photoPageController. animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves. easeInOut,
        );
        setState(() => _currentPhotoIndex = nextPage);
        _startPhotoCarousel();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    currentUser = await TrackService.instance.getCurrentUser();
    
    if (currentUser != null) {
      // Get all tracks (each track is a different photography style/challenge type)
      allTracks = await TrackService.instance.getUserTracks(currentUser!.id! );
      
      // Get active track
      activeTrack = await TrackService.instance.getActiveTrack(currentUser!.id!);
      
      // Mock streak calculation
      currentStreak = 8;
      _streakController.forward();
    }

    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _streakController.dispose();
    _photoPageController.dispose();
    _challengePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: SafeArea(
        child: isLoading ?  _buildLoading() : _buildContent(),
      ),
      floatingActionButton: _buildChatFAB(),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: AppTheme.textPrimary),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text(
            'Kapture',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 8),
              
              // Streak Widget
              _buildStreakWidget(),
              
              const SizedBox(height: 24),
              
              // Photos of the Week
              _buildPhotosOfWeek(),
              
              const SizedBox(height: 32),
              
              // Challenge Carousel
              _buildChallengeCarousel(),
              
              const SizedBox(height: 24),
              
              // New Challenge Button
              _buildNewChallengeButton(),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$currentStreak-day win streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'DONT QUIT!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.5, end: 1.0). animate(
                    CurvedAnimation(
                      parent: _streakController,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '🔥',
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Streak Days Visualization
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final isActive = index < currentStreak % 7;
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive 
                            ? AppTheme. accentColor 
                            : Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isActive
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosOfWeek() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pic of the week',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _photoPageController,
                  itemCount: photosOfWeek.length,
                  onPageChanged: (index) {
                    setState(() => _currentPhotoIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image
                            Image.asset(
                              photosOfWeek[index]['image']!,
                              fit: BoxFit. cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback UI if image fails to load
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors. grey.shade300,
                                        Colors.grey.shade200,
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons. broken_image,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            // Gradient overlay for text readability
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      photosOfWeek[index]['user']!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      photosOfWeek[index]['style']!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                // Page Indicators
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment. center,
                    children: List.generate(
                      photosOfWeek. length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPhotoIndex == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPhotoIndex == index
                              ? AppTheme.primaryColor
                              : Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCarousel() {
    if (allTracks.isEmpty) {
      return _buildNoChallenges();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Your Challenges',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 400,
          child: PageView. builder(
            controller: _challengePageController,
            onPageChanged: (index) {
              setState(() => _currentChallengeIndex = index);
            },
            itemCount: allTracks.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _challengePageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_challengePageController.position.haveDimensions) {
                    value = _challengePageController.page!  - index;
                    value = (1 - (value. abs() * 0.3)).clamp(0.7, 1.0);
                  }
                  
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 380,
                      child: child,
                    ),
                  );
                },
                child: _buildTrackCard(allTracks[index], index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrackCard(Track track, int index) {
    final colors = [
      AppTheme. primaryColor,
      AppTheme. secondaryColor,
      AppTheme.accentColor,
      AppTheme.successColor,
    ];
    final color = colors[index % colors.length];

    // Get icon based on style
    IconData getStyleIcon(String style) {
      switch (style. toLowerCase()) {
        case 'street':
          return Icons.location_city;
        case 'portrait':
          return Icons.person;
        case 'landscape':
          return Icons.landscape;
        case 'wildlife':
          return Icons.pets;
        case 'architecture':
          return Icons.business;
        case 'sports':
          return Icons.sports_soccer;
        case 'automotive':
          return Icons.directions_car;
        case 'event':
          return Icons.celebration;
        case 'product':
          return Icons.inventory_2;
        default:
          return Icons.camera_alt;
      }
    }

    return GestureDetector(
      onTap: () async {
        // Get today's challenge for this track
        final todayChallenge = await TrackService. instance.getTodayChallenge(track.id! );
        if (todayChallenge != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveTrackScreen(challenge: todayChallenge),
            ),
          ). then((_) => _loadData());
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Card(
          elevation: 8,
          shadowColor: color.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.9),
                  color,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                // Background pattern
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          getStyleIcon(track.style),
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Style name
                      Text(
                        track.style,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Track name
                      Text(
                        track.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment. spaceEvenly,
                        children: [
                          _buildStatItem(
                            icon: Icons.calendar_today,
                            label: '${track. durationDays} days',
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          _buildStatItem(
                            icon: Icons.signal_cellular_alt,
                            label: track.level,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Start button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final todayChallenge = await TrackService.instance.getTodayChallenge(track.id!);
                            if (todayChallenge != null && mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ActiveTrackScreen(challenge: todayChallenge),
                                ),
                              ).then((_) => _loadData());
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: color,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Start Challenge',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white. withOpacity(0.9), size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white. withOpacity(0.9),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildNoChallenges() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.layers_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No challenges yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChallengeButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius. circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewTrackScreen(),
                ),
              ). then((_) => _loadData());
            },
            borderRadius: BorderRadius.circular(20),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'New Challenge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            
            // Profile Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primaryColor. withOpacity(0.2),
                    child: const Icon(
                      Icons.person,
                      size: 32,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser?. username ?? 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          currentUser?.email ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors. grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            // Menu Items
            ListTile(
              leading: const Icon(Icons. home_outlined),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard_outlined),
              title: const Text('Leaderboard'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons. settings_outlined),
              title: const Text('Settings'),
              onTap: () {},
            ),
            
            const Spacer(),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Support'),
              onTap: () {},
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildChatFAB() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accentColor,
        boxShadow: [
          BoxShadow(
            color: AppTheme. accentColor.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.chat_bubble_outline, size: 28),
      ),
    );
  }
}