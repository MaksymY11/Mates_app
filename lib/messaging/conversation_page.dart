import 'dart:async';
import 'package:flutter/material.dart';
import '../services/messaging_service.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import '../apartment/apartment_view_page.dart';

class ConversationPage extends StatefulWidget {
  final int conversationId;
  final String title;
  final String? avatarUrl;
  final bool isGroup;
  final int? otherUserId;

  const ConversationPage({
    super.key,
    required this.conversationId,
    required this.title,
    this.avatarUrl,
    this.isGroup = false,
    this.otherUserId,
  });

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _typingUser;
  Timer? _typingTimer;
  Timer? _typingDisplayTimer;
  StreamSubscription? _wsSub;
  int? _currentUserId;
  DateTime? _lastLoadTime;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMessages();
    _subscribeWs();
    _markRead();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _typingDisplayTimer?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final data = await ApiService.get('/me');
      if (mounted) setState(() => _currentUserId = data['id'] as int?);
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final data = await MessagingService.getMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(
          (data['messages'] as List<dynamic>).cast<Map<String, dynamic>>(),
        );
        _loading = false;
        _hasMore = _messages.length >= 50;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Fetches older messages for cursor-based pagination.
  /// Debounced to 1 second to prevent duplicate loads from rapid scrolling.
  Future<void> _loadOlderMessages() async {
    if (_lastLoadTime != null &&
        DateTime.now().difference(_lastLoadTime!) < Duration(seconds: 1)) {
      return;
    }
    _lastLoadTime = DateTime.now();
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);

    final oldestId = _messages.first['id'] as int;
    try {
      final data = await MessagingService.getMessages(
        widget.conversationId,
        before: oldestId,
      );
      if (!mounted) return;
      final older =
          (data['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
      setState(() {
        _messages.insertAll(0, older);
        _loadingMore = false;
        _hasMore = older.length >= 50;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _subscribeWs() {
    _wsSub = WebSocketService.instance.messages.listen((data) {
      if (!mounted) return;
      final type = data['type'] as String?;

      if (type == 'message') {
        final msg = data['message'] as Map<String, dynamic>?;
        if (msg != null && msg['conversation_id'] == widget.conversationId) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
          _markRead();
        }
      } else if (type == 'typing') {
        if (data['conversation_id'] == widget.conversationId) {
          setState(() => _typingUser = data['user_name'] as String?);
          _typingDisplayTimer?.cancel();
          _typingDisplayTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _typingUser = null);
          });
        }
      }
    });
  }

  void _markRead() async {
    try {
      await MessagingService.markRead(widget.conversationId);
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 50) {
      _loadOlderMessages();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTextChanged(String _) {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {});
    WebSocketService.instance.send({
      'type': 'typing',
      'conversation_id': widget.conversationId,
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Show immediately — server won't echo back to sender
    setState(() {
      _messages.add({
        'conversation_id': widget.conversationId,
        'sender_id': _currentUserId,
        'body': text,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    WebSocketService.instance.send({
      'type': 'message',
      'conversation_id': widget.conversationId,
      'body': text,
    });
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap:
              !widget.isGroup && widget.otherUserId != null
                  ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => ApartmentViewPage(
                              userId: widget.otherUserId!,
                              userName: widget.title,
                            ),
                      ),
                    );
                  }
                  : null,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: brandLight.withValues(alpha: 0.3),
                backgroundImage:
                    widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                        ? NetworkImage(
                          '${ApiService.baseUrl}${widget.avatarUrl}',
                        )
                        : null,
                child:
                    widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                        ? Icon(
                          widget.isGroup ? Icons.groups_rounded : Icons.person,
                          size: 18,
                          color: brand,
                        )
                        : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_typingUser != null)
                      Text(
                        '$_typingUser is typing...',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                    ? Center(
                      child: Text(
                        'No messages yet. Say hi!',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: _messages.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loadingMore && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final msgIndex = _loadingMore ? index - 1 : index;
                        return _buildBubble(
                          _messages[msgIndex],
                          brand,
                          brandLight,
                        );
                      },
                    ),
          ),

          // Typing indicator bar
          if (_typingUser != null && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$_typingUser is typing...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _sendMessage(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: Icon(Icons.send_rounded, color: brand),
                    style: IconButton.styleFrom(
                      backgroundColor: brandLight.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, Color brand, Color brandLight) {
    final senderId = msg['sender_id'] as int?;
    final isMe = senderId == _currentUserId;
    final body = msg['body'] as String? ?? '';
    final senderName = msg['sender_name'] as String?;
    final senderAvatar = msg['sender_avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && widget.isGroup)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: brandLight.withValues(alpha: 0.3),
                backgroundImage:
                    senderAvatar != null && senderAvatar.isNotEmpty
                        ? NetworkImage('${ApiService.baseUrl}$senderAvatar')
                        : null,
                child:
                    senderAvatar == null || senderAvatar.isEmpty
                        ? Icon(Icons.person, size: 14, color: brand)
                        : null,
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? brand.withValues(alpha: 0.12) : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && widget.isGroup && senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: brand,
                        ),
                      ),
                    ),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? brand : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
