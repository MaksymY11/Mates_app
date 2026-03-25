import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/discovery_service.dart';
import '../services/quickpick_service.dart';
import 'neighbor_card.dart';
import 'neighborhood_card.dart';

class NeighborhoodPage extends StatefulWidget {
  const NeighborhoodPage({super.key});

  @override
  State<NeighborhoodPage> createState() => NeighborhoodPageState();
}

class NeighborhoodPageState extends State<NeighborhoodPage> {
  bool _loading = true;
  String? _error;

  String _locationPref = 'same_city';
  Map<String, dynamic> _neighborhood = {};
  double _mySimilarity = 0.0;
  List<dynamic> _neighbors = [];
  List<dynamic> _nearby = [];
  Set<int> _sentInterestIds = {};

  static const _prefLabels = {
    'same_city': 'Same city',
    'same_state': 'Same state',
    'anywhere': 'Anywhere',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void refreshNeighborhood() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.get('/me'),
        DiscoveryService.getNeighborhood(),
        DiscoveryService.getNearby(),
        QuickPickService.getSentInterests(),
      ]);

      final me = results[0];
      final hoodData = results[1];
      final nearbyData = results[2];
      final sentData = results[3];

      if (mounted) {
        setState(() {
          _locationPref = (me['location_preference'] as String?) ?? 'same_city';
          _neighborhood = hoodData['neighborhood'] as Map<String, dynamic>? ?? {};
          _mySimilarity = (hoodData['my_similarity_score'] as num?)?.toDouble() ?? 0.0;
          _neighbors = hoodData['neighbors'] as List<dynamic>? ?? [];
          _nearby = nearbyData['nearby'] as List<dynamic>? ?? [];
          _sentInterestIds = Set<int>.from(
            (sentData['sent_to'] as List<dynamic>? ?? []).map((e) => e as int),
          );
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateLocationPref(String pref) async {
    setState(() => _locationPref = pref);
    try {
      await ApiService.post('/updateUser', body: {'location_preference': pref});
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final hoodName = _neighborhood['name'] as String? ?? 'Your Neighborhood';
    final hoodDesc = _neighborhood['vibe_description'] as String? ?? '';
    final matchPct = (_mySimilarity * 100).round();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Your Neighborhood header ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  brand.withValues(alpha: 0.12),
                  brandLight.withValues(alpha: 0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: brandLight.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.home_work_rounded, color: brand, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hoodName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: brand,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$matchPct% fit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: brand,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hoodDesc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    hoodDesc,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Location preference picker ──
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                'Show people in:',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: _prefLabels.entries.map((e) {
                return ButtonSegment<String>(
                  value: e.key,
                  label: Text(e.value, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
              selected: {_locationPref},
              onSelectionChanged: (sel) => _updateLocationPref(sel.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Neighbors ──
          if (_neighbors.isNotEmpty) ...[
            Text(
              'Your neighbors',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: brand,
              ),
            ),
            const SizedBox(height: 10),
            ..._neighbors.map((n) {
              final neighbor = n as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeighborCard(
                  userId: neighbor['id'] as int,
                  name: neighbor['name'] as String?,
                  avatarUrl: neighbor['avatar_url'] as String?,
                  city: neighbor['city'] as String?,
                  state: neighbor['state'] as String?,
                  budget: neighbor['budget'] as int?,
                  moveInDate: neighbor['move_in_date'] as String?,
                  vibeLabels: List<String>.from(neighbor['vibe_labels'] ?? []),
                  similarityScore: (neighbor['similarity_score'] as num?)?.toDouble() ?? 0.0,
                  initialWaved: _sentInterestIds.contains(neighbor['id'] as int),
                ),
              );
            }),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No neighbors yet',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Build your apartment to get matched with similar people!',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],

          // ── Explore Nearby ──
          if (_nearby.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Explore nearby',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: brand,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to see who lives here',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 10),
            ..._nearby.map((n) {
              final hood = n as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeighborhoodCard(
                  id: hood['id'] as int,
                  name: hood['name'] as String? ?? '',
                  vibeDescription: hood['vibe_description'] as String? ?? '',
                  memberCount: hood['member_count'] as int? ?? 0,
                  sampleMembers: hood['sample_members'] as List<dynamic>? ?? [],
                  sentInterestIds: _sentInterestIds,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
