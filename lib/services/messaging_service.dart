import 'api_service.dart';

class MessagingService {
  static Future<Map<String, dynamic>> getConversations() async {
    return ApiService.get('/conversations');
  }

  static Future<Map<String, dynamic>> getMessages(
    int conversationId, {
    int? before,
  }) async {
    final query = before != null ? '?before=$before' : '';
    return ApiService.get('/conversations/$conversationId/messages$query');
  }

  static Future<Map<String, dynamic>> createDm(int userId) async {
    return ApiService.post('/conversations/dm/$userId');
  }

  static Future<Map<String, dynamic>> markRead(int conversationId) async {
    return ApiService.post('/conversations/$conversationId/read');
  }
}
