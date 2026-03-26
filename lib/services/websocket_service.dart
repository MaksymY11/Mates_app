import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> connect() async {
    _intentionalClose = false;
    _reconnectDelay = 1;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    // Build WS URL from the REST base URL
    final base = ApiService.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$base/ws?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
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
      onDone: () {
        if (_channel?.closeCode == 4001) {
          // Auth failure — redirect to login, don't reconnect
          ApiService.handleUnauthorized();
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

  void send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _doConnect();
    });
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s
    _reconnectDelay = (_reconnectDelay * 2).clamp(1, 30);
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
