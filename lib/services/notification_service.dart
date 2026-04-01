import 'api_service.dart';

/// Wraps notification API calls — list, mark read, delete.
class NotificationService {
  static Future<Map<String, dynamic>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    return ApiService.get('/notifications/?limit=$limit&offset=$offset');
  }

  static Future<void> markRead(int id) async {
    await ApiService.post('/notifications/$id/read');
  }

  static Future<void> markAllRead() async {
    await ApiService.post('/notifications/read-all');
  }

  static Future<void> deleteNotification(int id) async {
    await ApiService.delete('/notifications/$id');
  }

  static Future<void> clearAll() async {
    await ApiService.delete('/notifications/');
  }
}
