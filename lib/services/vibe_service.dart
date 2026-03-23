import 'api_service.dart';

class VibeService {
  /// Current user's vibe profile (weights + labels).
  static Future<Map<String, dynamic>> getMyVibe() async {
    return ApiService.get('/vibe/me');
  }

  /// Another user's vibe profile.
  static Future<Map<String, dynamic>> getVibe(int userId) async {
    return ApiService.get('/vibe/$userId');
  }

  /// Compare current user's vibe with another user's.
  /// Returns similarities, differences, and conversation starters.
  static Future<Map<String, dynamic>> compareVibe(int userId) async {
    return ApiService.get('/vibe/compare/$userId');
  }

  /// Force recalculation of current user's vibe.
  static Future<Map<String, dynamic>> recalculate() async {
    return ApiService.post('/vibe/recalculate');
  }
}
