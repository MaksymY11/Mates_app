import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'apartment/apartment_builder_page.dart';
import 'discovery/neighborhood_page.dart';
import 'quickpicks/matches_page.dart';
import 'services/quickpick_service.dart';

/// Entry point for logged-in users.
/// Shows a bottom nav with 5 tabs; the center (index 2) is the Home/Profiles feed.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Apartment builder is the default landing tab (center)
  int _currentIndex = 2;
  bool _hasMatchBadge = false;

  final _profileKey = GlobalKey<ProfilePageState>();
  final _discoveryKey = GlobalKey<NeighborhoodPageState>();
  final _matchesKey = GlobalKey<MatchesPageState>();

  // Keep pages alive with an IndexedStack
  late final List<Widget> _pages = [
    NeighborhoodPage(key: _discoveryKey),
    MatchesPage(key: _matchesKey),
    const ApartmentBuilderPage(), // center
    const NotificationsPage(),
    ProfilePage(key: _profileKey),
  ];

  @override
  void initState() {
    super.initState();
    _checkMatchBadge();
  }

  /// Checks for any mutual matches with pending Quick Picks.
  /// Shows a badge dot on the Matches tab so the user knows to look there.
  Future<void> _checkMatchBadge() async {
    try {
      final data = await QuickPickService.getMutualInterests();
      final matches = data['matches'] as List<dynamic>? ?? [];
      // Badge shows when user has Quick Picks to answer or unviewed results
      final hasPending = matches.any((m) {
        return (m as Map<String, dynamic>)['my_action_needed'] == true;
      });
      if (mounted) setState(() => _hasMatchBadge = hasPending);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) _discoveryKey.currentState?.refreshNeighborhood();
          if (i == 1) _matchesKey.currentState?.refreshMatches();
          if (i == 4) _profileKey.currentState?.refreshProfile();
          _checkMatchBadge();
        },
        items: [
          const _BottomNavItem(icon: Icons.explore, semanticLabel: 'Discover'),
          _BottomNavItem(
            icon: Icons.handshake_rounded,
            semanticLabel: 'Matches',
            showBadge: _hasMatchBadge,
          ),
          const _BottomNavItem(icon: Icons.home_rounded, semanticLabel: 'Apartment'),
          const _BottomNavItem(icon: Icons.notifications, semanticLabel: 'Alerts'),
          const _BottomNavItem(icon: Icons.person, semanticLabel: 'Profile'),
        ],
        selectedScale: 1.25,
        unselectedScale: 1.0,
        selectedColor: brand,
        unselectedColor: Colors.black54,
      ),
    );
  }
}

/// Lightweight custom bottom nav with a subtle scale animation on the selected icon.
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_BottomNavItem> items;
  final double selectedScale;
  final double unselectedScale;
  final Color selectedColor;
  final Color unselectedColor;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.selectedScale = 1.2,
    this.unselectedScale = 1.0,
    required this.selectedColor,
    required this.unselectedColor,
  });

  @override
  Widget build(BuildContext context) {
    // Option A: no gap at bottom
    return SafeArea(
      top: false,
      bottom: false, // prevents extra padding at the bottom
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = i == currentIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? selectedScale : unselectedScale,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          items[i].icon,
                          color: selected ? selectedColor : unselectedColor,
                          semanticLabel: items[i].semanticLabel,
                          size: 26,
                        ),
                        if (items[i].showBadge)
                          Positioned(
                            top: -2,
                            right: -4,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final IconData icon;
  final String semanticLabel;
  final bool showBadge;
  const _BottomNavItem({required this.icon, required this.semanticLabel, this.showBadge = false});
}

/// -------- Pages (stubs — expanded in future sessions) --------

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _CenterLabel(icon: Icons.notifications, label: 'Notifications');
}

class _CenterLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CenterLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: brand),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
