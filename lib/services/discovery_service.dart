import 'api_service.dart';

class DiscoveryService {
  /// Current user's neighborhood: name, vibe_description, neighbors list.
  static Future<Map<String, dynamic>> getNeighborhood() async {
    return ApiService.get('/discovery/neighborhood');
  }

  /// 2–3 nearby neighborhoods for exploration.
  static Future<Map<String, dynamic>> getNearby() async {
    return ApiService.get('/discovery/nearby');
  }

  /// Full profile summary for a user (apartment items, vibe labels, scenario answers).
  static Future<Map<String, dynamic>> getUserSummary(int userId) async {
    return ApiService.get('/discovery/user/$userId/summary');
  }

  /// Force re-clustering (debug/admin).
  static Future<Map<String, dynamic>> recalculate() async {
    return ApiService.post('/discovery/recalculate');
  }
}
