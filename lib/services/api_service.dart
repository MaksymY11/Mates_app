import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../login_page.dart';

class ApiService {
  static final String baseUrl =
      kIsWeb
          ? 'https://mates-backend-dxma.onrender.com'
          : Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const _storage = FlutterSecureStorage();
  static Completer<bool>? _refreshCompleter;

  /// Stores the JWT access token in secure storage.
  static Future<void> setToken(
    String token, {
    String key = 'auth_token',
  }) async {
    await _storage.write(key: key, value: token);
  }

  /// Retrieves the JWT access token from secure storage, or null if not set.
  static Future<String?> getToken({String key = 'auth_token'}) async {
    return await _storage.read(key: key);
  }

  /// Removes the JWT access token from secure storage.
  static Future<void> clearToken({String key = 'auth_token'}) async {
    await _storage.delete(key: key);
  }

  /// Clears the stored token and redirects to the login page.
  /// Called when authentication fails and refresh is not possible.
  static Future<void> handleUnauthorized() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'refresh_token');
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  /// Authenticated GET request. Times out after 30 seconds.
  static Future<Map<String, dynamic>> get(String path) async {
    final token = await getToken();
    if (token == null) {
      await handleUnauthorized();
      throw Exception("Session expired. Please log in again.");
    }
    final res = await http
        .get(
          Uri.parse('$baseUrl$path'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await handleUnauthorized();
        throw Exception("Session expired. Please log in again.");
      }
      // Retry the original request with new token
      final newToken = await getToken();

      final retry = await http
          .get(
            Uri.parse('$baseUrl$path'),
            headers: {'Authorization': 'Bearer $newToken'},
          )
          .timeout(const Duration(seconds: 30));

      return jsonDecode(retry.body) as Map<String, dynamic>;
    }

    if (res.statusCode != 200) {
      throw Exception('GET $path failed: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Authenticated POST request. Times out after 30 seconds.
  /// Set [requiresAuth] to false for unauthenticated endpoints (login, register).
  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final headers = {'Content-Type': 'application/json'};

    if (requiresAuth) {
      final token = await getToken();
      if (token == null) {
        await handleUnauthorized();
        throw Exception("Session expired. Please log in again.");
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final res = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401 && requiresAuth) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await handleUnauthorized();
        throw Exception("Session expired. Please log in again.");
      }
      // Retry the original request with new token
      final newToken = await getToken();

      final retry = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $newToken',
              'Content-Type': 'application/json',
            },
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));

      return jsonDecode(retry.body) as Map<String, dynamic>;
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('POST $path failed: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Authenticated DELETE request. Times out after 30 seconds.
  static Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await getToken();
    if (token == null) {
      await handleUnauthorized();
      throw Exception("Session expired. Please log in again.");
    }
    final headers = <String, String>{'Authorization': 'Bearer $token'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final res = await http
        .delete(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await handleUnauthorized();
        throw Exception("Session expired. Please log in again.");
      }
      // Retry the original request with new token
      final newToken = await getToken();

      final retry = await http
          .delete(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $newToken',
              'Content-Type': 'application/json',
            },
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));

      return jsonDecode(retry.body) as Map<String, dynamic>;
    }

    if (res.statusCode != 200) {
      throw Exception('DELETE $path failed: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Authenticated multipart file upload. Times out after 60 seconds.
  static Future<Map<String, dynamic>> uploadFile(
    String path, {
    required Uint8List bytes,
    required String filename,
    MediaType? contentType,
  }) async {
    final token = await getToken();
    if (token == null) {
      await handleUnauthorized();
      throw Exception("Session expired. Please log in again.");
    }
    final uri = Uri.parse('$baseUrl$path');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: contentType ?? MediaType('image', 'jpeg'),
      ),
    );
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (!refreshed) {
        await handleUnauthorized();
        throw Exception("Session expired. Please log in again.");
      }
      // Retry the original request with new token
      final newToken = await getToken();

      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $newToken';
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: contentType ?? MediaType('image', 'jpeg'),
        ),
      );
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final retry = await http.Response.fromStream(streamed);

      return jsonDecode(retry.body) as Map<String, dynamic>;
    }

    if (res.statusCode != 200) {
      throw Exception('Upload $path failed: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Attempts to refresh the access token using the stored refresh token.
  /// Concurrent callers share the same refresh attempt via [Completer].
  static Future<bool> _tryRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<bool>();
    bool success = false;
    try {
      final refreshToken = await getToken(key: 'refresh_token');
      if (refreshToken != null) {
        final res = await http
            .post(
              Uri.parse('$baseUrl/refreshToken'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          await setToken(data['access_token']);
          await setToken(data['refresh_token'], key: 'refresh_token');
          success = true;
        }
      }
    } catch (_) {
    } finally {
      _refreshCompleter!.complete(success);
      _refreshCompleter = null;
    }
    return success;
  }
}
