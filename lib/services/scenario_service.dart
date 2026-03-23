import 'api_service.dart';

class ScenarioService {
  /// Get today's daily scenario (auto-assigns if needed).
  /// Returns scenario, completion state, and substitution info.
  static Future<Map<String, dynamic>> getDaily() async {
    return ApiService.get('/scenarios/daily');
  }

  /// Answer a scenario. If user has 3 active responses,
  /// [replaceScenarioId] must specify which to swap out.
  static Future<Map<String, dynamic>> answer({
    required int scenarioId,
    required String selectedOption,
    int? replaceScenarioId,
  }) async {
    final body = <String, dynamic>{
      'scenario_id': scenarioId,
      'selected_option': selectedOption,
    };
    if (replaceScenarioId != null) {
      body['replace_scenario_id'] = replaceScenarioId;
    }
    return ApiService.post('/scenarios/answer', body: body);
  }

  /// Skip today's scenario without answering.
  static Future<Map<String, dynamic>> skip() async {
    return ApiService.post('/scenarios/skip');
  }

  /// Get current user's active scenario responses (max 3).
  static Future<Map<String, dynamic>> getHistory() async {
    return ApiService.get('/scenarios/history');
  }

  /// Compare scenario answers with another user.
  static Future<Map<String, dynamic>> compare(int userId) async {
    return ApiService.get('/scenarios/compare/$userId');
  }
}
