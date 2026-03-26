import 'package:flutter/material.dart';
import '../services/quickpick_service.dart';
import '../services/household_service.dart';
import '../services/messaging_service.dart';
import '../messaging/conversation_page.dart';

/// Shows side-by-side results for a completed Quick Picks session.
///
/// Green = agreement (reinforces compatibility).
/// Orange = divergence (framed as conversation starters, not red flags).
/// Bottom CTA placeholder for future messaging.
class QuickPickResultsPage extends StatefulWidget {
  final int sessionId;
  final String? otherUserName;

  const QuickPickResultsPage({
    super.key,
    required this.sessionId,
    this.otherUserName,
  });

  @override
  State<QuickPickResultsPage> createState() => _QuickPickResultsPageState();
}

class _QuickPickResultsPageState extends State<QuickPickResultsPage> {
  bool _loading = true;
  String? _error;

  String _summary = '';
  int _agreeCount = 0;
  int _total = 0;
  List<dynamic> _comparisons = [];
  Map<String, dynamic> _otherUser = {};
  bool _canInviteToHousehold = false;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      // Fire results + household data in parallel so both CTAs appear together
      final futures = await Future.wait([
        QuickPickService.getResults(widget.sessionId),
        _fetchEligibleIds(),
      ]);
      if (!mounted) return;

      final data = futures[0] as Map<String, dynamic>;
      final eligibleIds = futures[1] as Set<int>;
      final otherUser = data['other_user'] as Map<String, dynamic>? ?? {};
      final otherId = otherUser['id'] as int?;

      setState(() {
        _summary = data['summary'] as String? ?? '';
        _agreeCount = data['agree_count'] as int? ?? 0;
        _total = data['total'] as int? ?? 0;
        _comparisons = data['comparisons'] as List<dynamic>? ?? [];
        _otherUser = otherUser;
        _canInviteToHousehold = otherId != null && eligibleIds.contains(otherId);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  /// Returns the set of user IDs eligible for household invite.
  /// Returns empty set if user has no household.
  Future<Set<int>> _fetchEligibleIds() async {
    try {
      final results = await Future.wait([
        HouseholdService.getMyHousehold(),
        HouseholdService.getEligibleConnections(),
      ]);
      final household = results[0]['household'];
      if (household == null) return {};
      final eligible = results[1]['eligible'] as List<dynamic>? ?? [];
      return eligible.map((u) => (u as Map)['id'] as int).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _inviteToHousehold() async {
    final otherId = _otherUser['id'] as int?;
    if (otherId == null) return;
    try {
      await HouseholdService.inviteUser(otherId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to ${_otherUser['name'] ?? 'them'}!')),
        );
        setState(() => _canInviteToHousehold = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;
    final otherName = widget.otherUserName ?? _otherUser['name'] ?? 'Them';

    return Scaffold(
      appBar: AppBar(
        title: Text('Results with $otherName'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildResults(brand, brandLight, otherName),
    );
  }

  Widget _buildResults(Color brand, Color brandLight, String otherName) {
    return Column(
      children: [
        // Summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: _agreeCount >= 4
              ? Colors.green.withValues(alpha: 0.08)
              : _agreeCount >= 3
                  ? brandLight.withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.08),
          child: Column(
            children: [
              Text(
                'You agreed on $_summary questions',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              // Visual dots for agreement
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_total, (i) {
                  final comp = i < _comparisons.length
                      ? _comparisons[i] as Map<String, dynamic>
                      : null;
                  final agreed = comp?['agreed'] == true;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: agreed ? Colors.green : Colors.orange,
                    ),
                    child: Icon(
                      agreed ? Icons.check : Icons.close,
                      size: 10,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        // Question comparisons list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _comparisons.length + 1, // +1 for bottom CTA
            itemBuilder: (context, index) {
              if (index == _comparisons.length) {
                return _buildBottomCta(brand, brandLight);
              }
              return _buildComparisonCard(
                _comparisons[index] as Map<String, dynamic>,
                otherName,
                brand,
                brandLight,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonCard(
    Map<String, dynamic> comp,
    String otherName,
    Color brand,
    Color brandLight,
  ) {
    final prompt = comp['prompt'] as String? ?? '';
    final myText = comp['my_text'] as String? ?? '';
    final theirText = comp['their_text'] as String? ?? '';
    final agreed = comp['agreed'] == true;
    final starter = comp['conversation_starter'] as String?;
    final accentColor = agreed ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question prompt
          Text(
            prompt,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // Side-by-side answers
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildAnswerChip(
                  label: 'You',
                  answer: myText,
                  color: brand,
                  bgColor: brandLight.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAnswerChip(
                  label: otherName,
                  answer: theirText,
                  color: brand,
                  bgColor: brandLight.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Agreement/divergence indicator
          if (agreed)
            Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  'You agree!',
                  style: TextStyle(
                    fontSize: 13,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (starter != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Worth discussing!',
                    style: TextStyle(
                      fontSize: 13,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAnswerChip({
    required String label,
    required String answer,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta(Color brand, Color brandLight) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 16),
          if (_canInviteToHousehold) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _inviteToHousehold,
                icon: const Icon(Icons.groups_rounded),
                label: const Text('Invite to Household'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final otherId = _otherUser['id'] as int?;
                if (otherId == null) return;
                try {
                  final result = await MessagingService.createDm(otherId);
                  if (!mounted) return;
                  final convId = result['conversation_id'] as int;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ConversationPage(
                        conversationId: convId,
                        title: widget.otherUserName ?? _otherUser['name'] ?? 'Chat',
                        avatarUrl: _otherUser['avatar_url'] as String?,
                        otherUserId: otherId,
                      ),
                    ),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Start a conversation'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
