import 'api_service.dart';

/// Wraps household API calls — CRUD, invites, house rules, eligible connections.
class HouseholdService {
  /// Create a household with the given name.
  static Future<Map<String, dynamic>> createHousehold(String name) async {
    return ApiService.post('/households/', body: {'name': name});
  }

  /// Get current user's household (members + rules). Returns {household: ...} or {household: null}.
  static Future<Map<String, dynamic>> getMyHousehold() async {
    return ApiService.get('/households/me');
  }

  /// Leave current household.
  static Future<Map<String, dynamic>> leaveHousehold() async {
    return ApiService.post('/households/leave');
  }

  /// Delete household (creator only).
  static Future<Map<String, dynamic>> deleteHousehold(int householdId) async {
    return ApiService.delete('/households/$householdId');
  }

  /// Invite a user to the current household.
  static Future<Map<String, dynamic>> inviteUser(int userId) async {
    return ApiService.post('/households/invite/$userId');
  }

  /// List pending invites (sent and received).
  static Future<Map<String, dynamic>> getInvites() async {
    return ApiService.get('/households/invites');
  }

  /// Accept a household invite.
  static Future<Map<String, dynamic>> acceptInvite(int inviteId) async {
    return ApiService.post('/households/invites/$inviteId/accept');
  }

  /// Decline a household invite.
  static Future<Map<String, dynamic>> declineInvite(int inviteId) async {
    return ApiService.post('/households/invites/$inviteId/decline');
  }

  /// List all rules for a household.
  static Future<Map<String, dynamic>> getRules(int householdId) async {
    return ApiService.get('/households/$householdId/rules');
  }

  /// Propose a new house rule.
  static Future<Map<String, dynamic>> proposeRule(int householdId, String text) async {
    return ApiService.post('/households/$householdId/rules', body: {'text': text});
  }

  /// Vote on a house rule (true = yes, false = no).
  static Future<Map<String, dynamic>> voteOnRule(int ruleId, bool vote) async {
    return ApiService.post('/households/rules/$ruleId/vote', body: {'vote': vote});
  }

  /// Propose removal of an accepted rule (starts a removal vote).
  static Future<Map<String, dynamic>> proposeRemoval(int ruleId) async {
    return ApiService.post('/households/rules/$ruleId/propose-removal');
  }

  /// Delete a house rule.
  static Future<Map<String, dynamic>> deleteRule(int ruleId) async {
    return ApiService.delete('/households/rules/$ruleId');
  }

  /// List eligible connections (completed Quick Picks, not in a household).
  static Future<Map<String, dynamic>> getEligibleConnections() async {
    return ApiService.get('/households/eligible');
  }
}
