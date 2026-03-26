import 'package:flutter/material.dart';
import '../apartment/apartment_view_page.dart';
import '../services/api_service.dart';
import '../services/quickpick_service.dart';
import '../quickpicks/quick_pick_page.dart';

class NeighborCard extends StatefulWidget {
  final int userId;
  final String? name;
  final String? avatarUrl;
  final String? city;
  final String? state;
  final int? budget;
  final String? moveInDate;
  final List<String> vibeLabels;
  final double similarityScore;
  final bool initialWaved;

  const NeighborCard({
    super.key,
    required this.userId,
    this.name,
    this.avatarUrl,
    this.city,
    this.state,
    this.budget,
    this.moveInDate,
    required this.vibeLabels,
    required this.similarityScore,
    this.initialWaved = false,
  });

  @override
  State<NeighborCard> createState() => _NeighborCardState();
}

class _NeighborCardState extends State<NeighborCard> {
  bool _waved = false;
  bool _waving = false;

  @override
  void initState() {
    super.initState();
    _waved = widget.initialWaved;
  }

  @override
  void didUpdateWidget(NeighborCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWaved != widget.initialWaved) {
      _waved = widget.initialWaved;
    }
  }

  Future<void> _toggleWave() async {
    if (_waving) return;

    // If already waved, tapping again withdraws interest
    if (_waved) {
      setState(() => _waving = true);
      try {
        await QuickPickService.withdrawInterest(widget.userId);
        if (mounted) {
          setState(() { _waved = false; _waving = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Withdrew wave from ${widget.name ?? 'user'}')),
          );
        }
      } catch (e) {
        if (mounted) setState(() => _waving = false);
      }
      return;
    }

    setState(() => _waving = true);
    try {
      final result = await QuickPickService.expressInterest(widget.userId);
      if (!mounted) return;
      setState(() { _waved = true; _waving = false; });

      if (result['mutual'] == true) {
        _showMutualDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You waved at ${widget.name ?? 'them'}! If they wave back, you\'ll be matched.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _waving = false);
    }
  }

  void _showMutualDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final brand = Theme.of(ctx).colorScheme.primary;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.celebration, color: brand),
              const SizedBox(width: 8),
              const Text('It\'s mutual!'),
            ],
          ),
          content: Text(
            '${widget.name ?? "They"} waved back! Answer 5 quick questions to break the ice.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuickPickPage(
                      otherUserId: widget.userId,
                      otherUserName: widget.name,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white),
              child: const Text('Quick Picks'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;
    final pct = (widget.similarityScore * 100).round();

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ApartmentViewPage(
              userId: widget.userId,
              userName: widget.name,
            ),
          ),
        );
        // Refresh wave state in case user waved from ApartmentViewPage
        try {
          final sent = await QuickPickService.getSentInterests();
          if (mounted) {
            final sentTo = List<int>.from(sent['sent_to'] ?? []);
            setState(() => _waved = sentTo.contains(widget.userId));
          }
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.all(12),
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
                CircleAvatar(
                  radius: 22,
                  backgroundColor: brandLight.withValues(alpha: 0.3),
                  backgroundImage: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                      ? NetworkImage('${ApiService.baseUrl}${widget.avatarUrl}')
                      : null,
                  child: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                      ? Icon(Icons.person, size: 22, color: brand)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$pct% match',
                        style: TextStyle(
                          fontSize: 12,
                          color: brand,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.city != null || widget.state != null)
                        Text(
                          [widget.city, widget.state].where((s) => s != null && s.isNotEmpty).join(', '),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                // Wave/interest button — lets users express interest from discovery
                GestureDetector(
                  onTap: _toggleWave,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _waved ? Icons.waving_hand : Icons.waving_hand_outlined,
                      key: ValueKey(_waved),
                      size: 22,
                      color: _waved ? Colors.amber[700] : Colors.grey[400],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
              ],
            ),
            if (widget.budget != null || widget.moveInDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (widget.budget != null) ...[
                    Icon(Icons.attach_money, size: 13, color: Colors.grey[500]),
                    Text(
                      '\$${widget.budget}/mo',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (widget.moveInDate != null) ...[
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(
                      widget.moveInDate!.length >= 10
                          ? widget.moveInDate!.substring(0, 10)
                          : widget.moveInDate!,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
            if (widget.vibeLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: widget.vibeLabels.take(4).map((label) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 11, color: brand, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
