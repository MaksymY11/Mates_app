import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class ApartmentService {
  /// All furniture grouped by zone → category (no auth required).
  static Future<Map<String, dynamic>> getCatalog() async {
    final res = await http.get(
      Uri.parse('${ApiService.baseUrl}/apartments/catalog'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load catalog: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Style presets grouped by zone (no auth required).
  static Future<Map<String, dynamic>> getPresets() async {
    final res = await http.get(
      Uri.parse('${ApiService.baseUrl}/apartments/presets'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load presets: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Create apartment for the current user (idempotent).
  static Future<Map<String, dynamic>> createApartment() async {
    return ApiService.post('/apartments/');
  }

  /// Apply a style preset to a zone — replaces all items in that zone.
  static Future<Map<String, dynamic>> applyPreset(int presetId) async {
    return ApiService.post(
      '/apartments/apply-preset',
      body: {'preset_id': presetId},
    );
  }

  /// Current user's apartment + placed items.
  static Future<Map<String, dynamic>> getMyApartment() async {
    return ApiService.get('/apartments/me');
  }

  /// View another user's apartment.
  static Future<Map<String, dynamic>> getUserApartment(int userId) async {
    return ApiService.get('/apartments/$userId');
  }

  /// Place a furniture item in a zone.
  static Future<Map<String, dynamic>> placeItem(
    int furnitureId,
    String zone,
  ) async {
    return ApiService.post(
      '/apartments/items',
      body: {
        'furniture_id': furnitureId,
        'zone': zone,
        'position_x': 0,
        'position_y': 0,
      },
    );
  }

  /// Remove a placed item.
  static Future<Map<String, dynamic>> removeItem(int itemId) async {
    return ApiService.delete('/apartments/items/$itemId');
  }
}
