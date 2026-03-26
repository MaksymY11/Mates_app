import 'package:flutter/material.dart';
import '../services/quickpick_service.dart';
import '../services/messaging_service.dart';
import '../services/api_service.dart';
import '../messaging/conversation_page.dart';
import 'quick_pick_page.dart';
import 'quick_pick_results_page.dart';

/// Lists all mutual interests (matches) with Quick Picks session status.
///
/// Replaces the Chats stub tab. Each card shows the matched user and
/// the state of their Quick Picks session — tapping navigates to the
/// question flow or results depending on status.
/// In the future, messaging threads will live here too.
class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => MatchesPageState();
}

class MatchesPageState extends State<MatchesPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _matches = [];
  List<dynamic> _dmConversations = [];
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Called by HomeShell via GlobalKey on tab switch to keep data current.
  Future<void> refreshMatches() async {
    await _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        QuickPickService.getMutualInterests(),
        MessagingService.getConversations(),
        ApiService.get('/me'),
      ]);
      if (!mounted) return;

      _currentUserId = results[2]['id'] as int?;
      final allMatches = results[0]['matches'] as List<dynamic>? ?? [];
      final allConvs = results[1]['conversations'] as List<dynamic>? ?? [];
      final dmConvs = allConvs.where((c) => (c as Map)['type'] == 'dm').toList();

      // Collect user IDs that already have a DM conversation
      final dmUserIds = <int>{};
      for (final c in dmConvs) {
        final participants = (c as Map)['participants'] as List<dynamic>? ?? [];
        for (final p in participants) {
          dmUserIds.add((p as Map)['id'] as int);
        }
      }

      // Filter out matches that already have a conversation
      final filteredMatches = allMatches.where((m) {
        final id = (m as Map)['id'] as int;
        return !dmUserIds.contains(id);
      }).toList();

      setState(() {
        _matches = filteredMatches;
        _dmConversations = dmConvs;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load matches. Pull to retry.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(brand)
              : _matches.isEmpty
                  ? _buildEmptyState(brand)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // DM Conversations section
                      if (_dmConversations.isNotEmpty) ...[
                        Text(
                          'Conversations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: brand,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._dmConversations.map((c) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildConversationCard(c as Map<String, dynamic>, brand, brandLight),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Matches section
                      if (_matches.isNotEmpty) ...[
                        if (_dmConversations.isNotEmpty)
                          Text(
                            'Matches',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: brand,
                            ),
                          ),
                        if (_dmConversations.isNotEmpty) const SizedBox(height: 8),
                        ..._matches.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildMatchCard(m as Map<String, dynamic>, brand, brandLight),
                        )),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState(Color brand) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() { _loading = true; _error = null; });
                _load();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(foregroundColor: brand),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color brand) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.waving_hand_rounded, size: 56, color: brand.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text(
              'No matches yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Wave at neighbors you like! When they wave back, you\'ll unlock Quick Picks.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard(
    Map<String, dynamic> conv,
    Color brand,
    Color brandLight,
  ) {
    final participants = (conv['participants'] as List<dynamic>?) ?? [];
    // Find the other participant (not current user) — we'll figure out the current user
    // by seeing which participant name doesn't match the last message sender (fallback: first other)
    final lastMessage = conv['last_message'] as Map<String, dynamic>?;
    final unread = conv['unread_count'] as int? ?? 0;
    final convId = conv['id'] as int;

    // For DM, find the other participant (not current user)
    String otherName = 'Unknown';
    String? otherAvatar;
    int? otherUserId;
    for (final p in participants) {
      final pm = p as Map<String, dynamic>;
      final pid = pm['id'] as int?;
      if (pid != null && pid != _currentUserId) {
        otherName = pm['name'] as String? ?? 'Unknown';
        otherAvatar = pm['avatar_url'] as String?;
        otherUserId = pid;
        break;
      }
    }
    // Fallback if current user ID not loaded yet
    if (otherUserId == null && participants.isNotEmpty) {
      final pm = participants.first as Map<String, dynamic>;
      otherName = pm['name'] as String? ?? 'Unknown';
      otherAvatar = pm['avatar_url'] as String?;
      otherUserId = pm['id'] as int?;
    }

    final preview = lastMessage?['body'] as String? ?? '';
    final senderName = lastMessage?['sender_name'] as String?;
    final previewText = senderName != null ? '$senderName: $preview' : preview;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConversationPage(
              conversationId: convId,
              title: otherName,
              avatarUrl: otherAvatar,
              otherUserId: otherUserId,
            ),
          ),
        );
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: brandLight.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: brandLight.withValues(alpha: 0.3),
              backgroundImage: otherAvatar != null && otherAvatar.isNotEmpty
                  ? NetworkImage('${ApiService.baseUrl}$otherAvatar')
                  : null,
              child: otherAvatar == null || otherAvatar.isEmpty
                  ? Icon(Icons.person, size: 24, color: brand)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  if (previewText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      previewText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: unread > 0 ? Colors.black87 : Colors.grey[500],
                        fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: brand,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard(
    Map<String, dynamic> match,
    Color brand,
    Color brandLight,
  ) {
    final userId = match['id'] as int;
    final name = match['name'] as String? ?? 'Unknown';
    final avatarUrl = match['avatar_url'] as String?;
    final vibeLabels = List<String>.from(match['vibe_labels'] ?? []);
    final sessionId = match['session_id'] as int?;
    final sessionStatus = match['session_status'] as String?;
    final myActionNeeded = match['my_action_needed'] == true;

    // Determine CTA text and action based on session status
    String ctaText;
    Color ctaColor;
    if (sessionStatus == 'completed') {
      ctaText = 'View Results';
      ctaColor = Colors.green;
    } else if (myActionNeeded) {
      ctaText = 'Answer Quick Picks';
      ctaColor = brand;
    } else if (sessionStatus != null) {
      ctaText = 'Waiting for them';
      ctaColor = Colors.grey;
    } else {
      ctaText = 'Quick Picks';
      ctaColor = brand;
    }

    return GestureDetector(
      onTap: () async {
        if (sessionStatus == 'completed' && sessionId != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuickPickResultsPage(
                sessionId: sessionId,
                otherUserName: name,
              ),
            ),
          );
        } else if (sessionStatus != null && !myActionNeeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Waiting for $name to finish their answers')),
          );
          return;
        } else {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuickPickPage(
                otherUserId: userId,
                otherUserName: name,
              ),
            ),
          );
        }
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: brandLight.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: brandLight.withValues(alpha: 0.3),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage('${ApiService.baseUrl}$avatarUrl')
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Icon(Icons.person, size: 26, color: brand)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (vibeLabels.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: vibeLabels.take(3).map((label) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: brandLight.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 10, color: brand, fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            // CTA chips — show "Message" for completed matches, else Quick Picks CTA
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ctaColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ctaColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    ctaText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ctaColor,
                    ),
                  ),
                ),
                if (sessionStatus == 'completed') ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final result = await MessagingService.createDm(userId);
                        if (!mounted) return;
                        final convId = result['conversation_id'] as int;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ConversationPage(
                              conversationId: convId,
                              title: name,
                              avatarUrl: avatarUrl,
                              otherUserId: userId,
                            ),
                          ),
                        );
                        _load();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: brand.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 12, color: brand),
                          const SizedBox(width: 4),
                          Text(
                            'Message',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: brand),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
