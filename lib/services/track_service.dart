// lib/services/track_service.dart

import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import '../models/track.dart';
import '../models/challenge.dart';
import '../models/user.dart';

class TrackService {
  static final TrackService instance = TrackService._init();
  TrackService._init();

  // Get current user
  Future<User?> getCurrentUser() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', limit: 1);
    
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  // Get active track for user
  Future<Track?> getActiveTrack(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'tracks',
      where: 'user_id = ? AND is_active = ?',
      whereArgs: [userId, 1],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    return Track.fromMap(result.first);
  }

  // Get all tracks for user
  Future<List<Track>> getUserTracks(int userId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'tracks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    
    return result.map((map) => Track.fromMap(map)).toList();
  }

  // Get today's challenge
  Future<Challenge?> getTodayChallenge(int trackId) async {
    final db = await DatabaseHelper.instance.database;
    
    // Get track start date and calculate current day
    final trackResult = await db.query('tracks', where: 'id = ?', whereArgs: [trackId]);
    if (trackResult.isEmpty) return null;
    
    final track = Track.fromMap(trackResult.first);
    final daysPassed = DateTime.now().difference(track.createdAt).inDays + 1;
    
    // Get challenge for current day
    final result = await db.query(
      'challenges',
      where: 'track_id = ? AND day_number = ?',
      whereArgs: [trackId, daysPassed],
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    return Challenge.fromMap(result.first);
  }

  // Get recent completed challenges
  Future<List<Challenge>> getRecentChallenges(int trackId, {int limit = 5}) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'challenges',
      where: 'track_id = ?',
      whereArgs: [trackId],
      orderBy: 'day_number DESC',
      limit: limit,
    );
    
    return result.map((map) => Challenge.fromMap(map)).toList();
  }

  // Calculate track progress
  Future<Map<String, dynamic>> getTrackProgress(int trackId) async {
    final db = await DatabaseHelper.instance.database;
    
    final track = await db.query('tracks', where: 'id = ?', whereArgs: [trackId]);
    if (track.isEmpty) return {};
    
    final totalDays = Track.fromMap(track.first).durationDays;
    final daysPassed = DateTime.now().difference(Track.fromMap(track.first).createdAt).inDays + 1;
    
    final completedCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM challenges WHERE track_id = ? AND completed = 1',
        [trackId],
      ),
    ) ?? 0;
    
    return {
      'currentDay': daysPassed > totalDays ? totalDays : daysPassed,
      'totalDays': totalDays,
      'completedChallenges': completedCount,
      'progress': (daysPassed / totalDays).clamp(0.0, 1.0),
    };
  }
}