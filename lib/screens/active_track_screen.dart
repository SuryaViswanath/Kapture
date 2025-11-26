// lib/screens/active_track_screen.dart
import 'package:flutter/material.dart';
import '../models/challenge.dart';

class ActiveTrackScreen extends StatelessWidget {
  final Challenge challenge;
  
  const ActiveTrackScreen({Key? key, required this.challenge}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Day ${challenge.dayNumber}')),
      body: Center(child: Text('Active Track Screen - Coming Soon!')),
    );
  }
}