import 'package:flutter/material.dart';
import 'neighbor_card.dart';

class NeighborhoodCard extends StatefulWidget {
  final int id;
  final String name;
  final String vibeDescription;
  final int memberCount;
  final List<dynamic> sampleMembers;

  const NeighborhoodCard({
    super.key,
    required this.id,
    required this.name,
    required this.vibeDescription,
    required this.memberCount,
    required this.sampleMembers,
  });

  @override
  State<NeighborhoodCard> createState() => _NeighborhoodCardState();
}

class _NeighborhoodCardState extends State<NeighborhoodCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: brandLight.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: brandLight.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.location_city, color: brand, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${widget.memberCount} ${widget.memberCount == 1 ? 'member' : 'members'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.vibeDescription,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            if (_expanded && widget.sampleMembers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey[200], height: 1),
              const SizedBox(height: 12),
              ...widget.sampleMembers.map((m) {
                final member = m as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeighborCard(
                    userId: member['id'] as int,
                    name: member['name'] as String?,
                    avatarUrl: member['avatar_url'] as String?,
                    vibeLabels: List<String>.from(member['vibe_labels'] ?? []),
                    similarityScore: (member['similarity_score'] as num?)?.toDouble() ?? 0.0,
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
