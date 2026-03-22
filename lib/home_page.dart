import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'apartment/apartment_builder_page.dart';

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

  // Keep pages alive with an IndexedStack
  late final List<Widget> _pages = const [
    DiscoveryPage(),        // placeholder — Session 5: Neighborhoods
    ChatsPage(),
    ApartmentBuilderPage(), // center
    NotificationsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          _BottomNavItem(icon: Icons.explore, semanticLabel: 'Discover'),
          _BottomNavItem(
            icon: Icons.chat_bubble_rounded,
            semanticLabel: 'Chats',
          ),
          _BottomNavItem(icon: Icons.home_rounded, semanticLabel: 'Apartment'),
          _BottomNavItem(icon: Icons.notifications, semanticLabel: 'Alerts'),
          _BottomNavItem(icon: Icons.person, semanticLabel: 'Profile'),
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
                    child: Icon(
                      items[i].icon,
                      color: selected ? selectedColor : unselectedColor,
                      semanticLabel: items[i].semanticLabel,
                      size: 26,
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
  const _BottomNavItem({required this.icon, required this.semanticLabel});
}

/// -------- Pages (stubs — expanded in future sessions) --------

class DiscoveryPage extends StatelessWidget {
  const DiscoveryPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _CenterLabel(icon: Icons.explore, label: 'Discover');
}

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _CenterLabel(icon: Icons.chat_bubble_rounded, label: 'Chats');
}

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
