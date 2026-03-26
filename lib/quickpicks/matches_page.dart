import 'package:flutter/material.dart';
import '../services/quickpick_service.dart';
import '../services/api_service.dart';
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
      final data = await QuickPickService.getMutualInterests();
      if (!mounted) return;
      setState(() {
        _matches = data['matches'] as List<dynamic>? ?? [];
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
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final m = _matches[index] as Map<String, dynamic>;
                      return _buildMatchCard(m, brand, brandLight);
                    },
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
          // User already answered — other user hasn't finished yet.
          // Show a snackbar instead of navigating to QuickPickPage where
          // they'd just see the same "waiting" screen with a loading flash.
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
        // Refresh after returning
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
            // Avatar
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

            // Name + vibe labels
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

            // CTA chip
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
          ],
        ),
      ),
    );
  }
}
