import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mates/verify_email_page.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class WebSocketService {
  WebSocketService._();
  static final WebSocketService instance = WebSocketService._();

  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  bool _intentionalClose = false;
  int _reconnectDelay = 1;
  Timer? _reconnectTimer;

  /// Opens the WebSocket connection and resets the reconnect backoff.
  Future<void> connect() async {
    _intentionalClose = false;
    _reconnectDelay = 1;
    await _doConnect();
  }

  /// Establishes the WebSocket connection, sends auth frame, and listens for messages.
  /// On failure or disconnect, schedules a reconnect (unless intentionally closed or auth rejected).
  Future<void> _doConnect() async {
    final token = await ApiService.getToken();
    if (token == null) {
      ApiService.handleUnauthorized();
      return;
    }

    // Build WS URL from the REST base URL
    final base = ApiService.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$base/ws');

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    _reconnectDelay = 1; // Reset on successful connect

    _channel!.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          _controller.add(decoded);
        } catch (_) {}
      },
      onDone: () async {
        if (_channel?.closeCode == 4001) {
          // Auth failure: redirect to login, don't reconnect
          ApiService.handleUnauthorized();
          return;
        }
        if (_channel?.closeCode == 4003) {
          // Email is not verified: redirect to VerifyEmailPage
          _intentionalClose = true;
          try {
            final me = await ApiService.get('/me');
            final email = me['email'] as String;
            ApiService.navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => VerifyEmailPage(email: email)),
              (route) => false,
            );
          } catch (_) {
            ApiService.handleUnauthorized();
          }
          return;
        }
        if (!_intentionalClose) {
          _scheduleReconnect();
        }
      },
      onError: (_) {
        if (!_intentionalClose) {
          _scheduleReconnect();
        }
      },
    );
  }

  /// Sends a JSON-encoded message over the WebSocket.
  void send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  /// Closes the connection and cancels any pending reconnect.
  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
  }

  /// Schedules a reconnection attempt with exponential backoff (1s → 2s → 4s → ... → 30s max)
  /// Skips if a reconnect is already pending. Backoff resets on successful connect.
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) {
      return; // If a reconnect is already scheduled, do nothing
    }
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _doConnect();
      _reconnectDelay = (_reconnectDelay * 2).clamp(1, 30);
    });
  }

  /// Disconnects and closes the message stream permanently.
  void dispose() {
    disconnect();
    _controller.close();
  }
}
