import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../apartment/apartment_view_page.dart';
import '../quickpicks/quick_pick_page.dart';
import '../quickpicks/quick_pick_results_page.dart';
import '../messaging/conversation_page.dart';

class NotificationsPage extends StatefulWidget {
  final void Function(int)? onSwitchTab;

  const NotificationsPage({super.key, this.onSwitchTab});

  @override
  NotificationsPageState createState() => NotificationsPageState();
}

class NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  StreamSubscription? _wsSub;
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> get _unread =>
      _notifications.where((n) => n['read'] != true).toList();

  List<Map<String, dynamic>> get _read =>
      _notifications.where((n) => n['read'] == true).toList();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
    _wsSub = WebSocketService.instance.messages.listen((data) {
      if (data['type'] == 'notification' && mounted) {
        final n = Map<String, dynamic>.from(
          data['notification'] as Map<String, dynamic>,
        );
        n['read'] = false;

        setState(() {
          // For message notifications, check if an existing notification
          // for the same conversation exists — replace it instead of adding
          final eventType = n['event_type'] as String?;
          final nData = n['data'] as Map<String, dynamic>?;
          if ((eventType == 'new_dm_message' || eventType == 'new_group_message') &&
              nData != null &&
              nData['conversation_id'] != null) {
            final convId = nData['conversation_id'];
            _notifications.removeWhere((existing) {
              final eType = existing['event_type'] as String?;
              final eData = existing['data'] as Map<String, dynamic>?;
              return (eType == 'new_dm_message' || eType == 'new_group_message') &&
                  eData != null &&
                  eData['conversation_id'] == convId;
            });
          }

          _notifications.insert(0, n);
          _unreadCount++;
        });
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refreshNotifications() => _load();

  /// Mark all notifications as read locally + on backend.
  void markAllAsRead() {
    if (_unread.isEmpty) return;
    NotificationService.markAllRead();
    setState(() {
      for (final n in _notifications) {
        n['read'] = true;
      }
      _unreadCount = 0;
    });
  }

  Future<void> _load() async {
    try {
      final data = await NotificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications =
            (data['notifications'] as List<dynamic>).cast<Map<String, dynamic>>();
        _unreadCount = data['unread_count'] as int? ?? 0;
        _loading = false;
        _hasMore = _notifications.length >= 50;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final data = await NotificationService.getNotifications(
        offset: _notifications.length,
      );
      final more =
          (data['notifications'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _notifications.addAll(more);
        _hasMore = more.length >= 50;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _clearAll() async {
    await NotificationService.clearAll();
    if (!mounted) return;
    setState(() {
      _notifications.clear();
      _unreadCount = 0;
    });
  }

  Future<void> _onTap(Map<String, dynamic> n) async {
    final id = n['id'] as int;
    // Delete notification and remove from list
    NotificationService.deleteNotification(id);
    setState(() {
      _notifications.removeWhere((item) => item['id'] == id);
      if (n['read'] != true) {
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
      }
    });

    final eventType = n['event_type'] as String;
    final data = n['data'] as Map<String, dynamic>? ?? {};

    switch (eventType) {
      case 'wave_received':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ApartmentViewPage(userId: data['user_id'] as int),
        ));
        break;

      case 'match_unlocked':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => QuickPickPage(otherUserId: data['user_id'] as int),
        ));
        break;

      case 'quickpicks_completed':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => QuickPickResultsPage(sessionId: data['session_id'] as int),
        ));
        break;

      case 'household_invite':
      case 'household_member_joined':
      case 'rule_proposed':
      case 'rule_resolved':
      case 'removal_proposed':
        widget.onSwitchTab?.call(3);
        break;

      case 'new_dm_message':
      case 'new_group_message':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ConversationPage(
            conversationId: data['conversation_id'] as int,
            title: n['title'] as String,
            isGroup: eventType == 'new_group_message',
            otherUserId: data['user_id'] as int,
          ),
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final unread = _unread;
    final read = _read;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No notifications yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text(
                        "You'll see waves, matches, and\nhousehold activity here.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    controller: _scrollController,
                    children: [
                      // Unread section
                      if (unread.isNotEmpty) ...[
                        _buildSectionHeader('Unread', brand, unread.length),
                        ...unread.map((n) => _buildNotificationTile(n, brand)),
                      ],
                      // Read section
                      if (read.isNotEmpty) ...[
                        _buildSectionHeader('Read', Colors.grey, null),
                        ...read.map((n) => _buildNotificationTile(n, brand)),
                      ],
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String label, Color color, int? count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> n, Color brand) {
    final isUnread = n['read'] != true;
    final avatarUrl = n['actor_avatar_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: isUnread ? brand.withValues(alpha: 0.06) : null,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: avatarUrl != null
              ? NetworkImage('${ApiService.baseUrl}$avatarUrl')
              : null,
          child: avatarUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(
          n['title'] as String? ?? '',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          n['body'] as String? ?? '',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _timeAgo(n['created_at'] as String?),
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        onTap: () => _onTap(n),
      ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}
