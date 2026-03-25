import 'api_service.dart';

/// Wraps interest + Quick Picks API calls.
///
/// Interest endpoints power the "wave" button on neighbor cards and
/// apartment view pages. Quick Picks endpoints power the 5-question
/// rapid-fire flow that unlocks after mutual interest.
class QuickPickService {
  /// Express interest ("wave") at another user.
  /// Returns {mutual: bool, session_id: int?}.
  static Future<Map<String, dynamic>> expressInterest(int userId) async {
    return ApiService.post('/interest/$userId');
  }

  /// Withdraw interest in another user.
  static Future<Map<String, dynamic>> withdrawInterest(int userId) async {
    return ApiService.delete('/interest/$userId');
  }

  /// All user IDs the current user has waved at.
  /// Used to initialize wave button states on neighbor cards.
  static Future<Map<String, dynamic>> getSentInterests() async {
    return ApiService.get('/interest/sent');
  }

  /// List all mutual interests with Quick Picks session status.
  /// Powers the Matches tab.
  static Future<Map<String, dynamic>> getMutualInterests() async {
    return ApiService.get('/interest/mutual');
  }

  /// Get the Quick Picks session between current user and target user.
  /// Returns questions + current user's answers (not the other's until done).
  static Future<Map<String, dynamic>> getSession(int userId) async {
    return ApiService.get('/quickpicks/session/$userId');
  }

  /// Submit an answer to one Quick Picks question.
  static Future<Map<String, dynamic>> submitAnswer({
    required int sessionId,
    required int questionIndex,
    required String selectedOption,
  }) async {
    return ApiService.post('/quickpicks/answer', body: {
      'session_id': sessionId,
      'question_index': questionIndex,
      'selected_option': selectedOption,
    });
  }

  /// Get side-by-side results for a completed session.
  static Future<Map<String, dynamic>> getResults(int sessionId) async {
    return ApiService.get('/quickpicks/results/$sessionId');
  }
}
