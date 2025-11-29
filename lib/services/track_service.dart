// lib/services/track_service. dart

import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import '../models/track.dart';
import '../models/challenge.dart';
import '../models/user.dart';

class TrackService {
  static final TrackService instance = TrackService._init();
  TrackService._init();

  // Get current user
  Future<User? > getCurrentUser() async {
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

  // Get current day number for a track
  Future<int> getCurrentDayNumber(int trackId) async {
    final db = await DatabaseHelper.instance.database;
    
    // Count completed challenges + 1
    final completedCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM challenges WHERE track_id = ? AND completed = 1',
        [trackId],
      ),
    ) ??  0;
    
    // Current day is the next uncompleted day
    return completedCount + 1;
  }

  // Get today's challenge (or next uncompleted challenge)
  Future<Challenge?> getTodayChallenge(int trackId) async {
    final db = await DatabaseHelper.instance.database;
    
    // Get the current day number based on completed challenges
    final currentDay = await getCurrentDayNumber(trackId);
    
    // Get challenge for current day
    final result = await db.query(
      'challenges',
      where: 'track_id = ? AND day_number = ?',
      whereArgs: [trackId, currentDay],
      limit: 1,
    );
    
    if (result.isEmpty) {
      print('⚠️ No challenge found for day $currentDay');
      return null;
    }
    
    print('✅ Found challenge for day $currentDay');
    return Challenge.fromMap(result.first);
  }

  // Get next challenge after completing current one
  Future<Challenge? > getNextChallenge(int trackId) async {
    final db = await DatabaseHelper.instance. database;
    
    // Get next day number
    final nextDay = await getCurrentDayNumber(trackId);
    
    // Get challenge for next day
    final result = await db.query(
      'challenges',
      where: 'track_id = ? AND day_number = ?',
      whereArgs: [trackId, nextDay],
      limit: 1,
    );
    
    if (result. isEmpty) return null;
    return Challenge.fromMap(result.first);
  }

  // Get recent completed challenges
  Future<List<Challenge>> getRecentChallenges(int trackId, {int limit = 5}) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'challenges',
      where: 'track_id = ? AND completed = 1',
      whereArgs: [trackId],
      orderBy: 'day_number DESC',
      limit: limit,
    );
    
    return result.map((map) => Challenge.fromMap(map)). toList();
  }

  // Calculate track progress
  Future<Map<String, dynamic>> getTrackProgress(int trackId) async {
    final db = await DatabaseHelper.instance.database;
    
    final track = await db.query('tracks', where: 'id = ?', whereArgs: [trackId]);
    if (track.isEmpty) return {};
    
    final totalDays = Track.fromMap(track.first). durationDays;
    final currentDay = await getCurrentDayNumber(trackId);
    
    final completedCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM challenges WHERE track_id = ? AND completed = 1',
        [trackId],
      ),
    ) ?? 0;
    
    return {
      'currentDay': currentDay > totalDays ? totalDays : currentDay,
      'totalDays': totalDays,
      'completedChallenges': completedCount,
      'progress': (completedCount / totalDays). clamp(0.0, 1.0),
    };
  }
}