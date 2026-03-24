import 'package:flutter/material.dart';
import '../apartment/apartment_view_page.dart';
import '../services/api_service.dart';

class NeighborCard extends StatelessWidget {
  final int userId;
  final String? name;
  final String? avatarUrl;
  final String? city;
  final String? state;
  final int? budget;
  final String? moveInDate;
  final List<String> vibeLabels;
  final double similarityScore;

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
  });

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;
    final pct = (similarityScore * 100).round();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ApartmentViewPage(
              userId: userId,
              userName: name,
            ),
          ),
        );
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
                  backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? NetworkImage('${ApiService.baseUrl}$avatarUrl')
                      : null,
                  child: avatarUrl == null || avatarUrl!.isEmpty
                      ? Icon(Icons.person, size: 22, color: brand)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? 'Unknown',
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
                      if (city != null || state != null)
                        Text(
                          [city, state].where((s) => s != null && s.isNotEmpty).join(', '),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
              ],
            ),
            if (budget != null || moveInDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (budget != null) ...[
                    Icon(Icons.attach_money, size: 13, color: Colors.grey[500]),
                    Text(
                      '\$$budget/mo',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (moveInDate != null) ...[
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(
                      moveInDate!.substring(0, 10),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
            if (vibeLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: vibeLabels.take(4).map((label) {
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
