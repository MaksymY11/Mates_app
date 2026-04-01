import 'dart:async';
import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'apartment/apartment_builder_page.dart';
import 'discovery/neighborhood_page.dart';
import 'quickpicks/matches_page.dart';
import 'household/household_page.dart';
import 'notifications/notifications_page.dart';
import 'services/notification_service.dart';
import 'services/websocket_service.dart';

/// Entry point for logged-in users.
/// Shows a bottom nav with 5 tabs; the center (index 2) is the Apartment builder.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Apartment builder is the default landing tab (center)
  int _currentIndex = 2;
  int _unreadNotificationCount = 0;
  StreamSubscription? _wsSub;

  final _discoveryKey = GlobalKey<NeighborhoodPageState>();
  final _matchesKey = GlobalKey<MatchesPageState>();
  final _householdKey = GlobalKey<HouseholdPageState>();
  final _notificationsKey = GlobalKey<NotificationsPageState>();

  late final List<Widget> _pages = [
    NeighborhoodPage(key: _discoveryKey),
    MatchesPage(key: _matchesKey),
    const ApartmentBuilderPage(), // center
    HouseholdPage(key: _householdKey),
    NotificationsPage(
      key: _notificationsKey,
      onSwitchTab: (idx) => setState(() => _currentIndex = idx),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
    WebSocketService.instance.connect();
    _wsSub = WebSocketService.instance.messages.listen((data) {
      if (data['type'] == 'notification' && mounted) {
        setState(() => _unreadNotificationCount++);
        // Show snackbar if not already on the Notifications tab
        if (_currentIndex != 4) {
          final notif = data['notification'] as Map<String, dynamic>?;
          final title = notif?['title'] as String? ?? 'New notification';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(title), duration: const Duration(seconds: 3)),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    WebSocketService.instance.disconnect();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final data = await NotificationService.getNotifications(limit: 1);
      if (mounted) {
        setState(() {
          _unreadNotificationCount = data['unread_count'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Profile & Settings',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
            },
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          // Mark notifications as read when leaving the Notifications tab
          if (_currentIndex == 4 && i != 4) {
            _notificationsKey.currentState?.markAllAsRead();
          }
          setState(() => _currentIndex = i);
          if (i == 0) _discoveryKey.currentState?.refreshNeighborhood();
          if (i == 1) _matchesKey.currentState?.refreshMatches();
          if (i == 3) _householdKey.currentState?.refreshHousehold();
          if (i == 4) {
            _notificationsKey.currentState?.refreshNotifications();
            setState(() => _unreadNotificationCount = 0);
          }
        },
        items: [
          const _BottomNavItem(icon: Icons.explore, semanticLabel: 'Discover'),
          const _BottomNavItem(
            icon: Icons.handshake_rounded,
            semanticLabel: 'Matches',
          ),
          const _BottomNavItem(
            icon: Icons.home_rounded,
            semanticLabel: 'Apartment',
          ),
          const _BottomNavItem(
            icon: Icons.groups_rounded,
            semanticLabel: 'Household',
          ),
          _BottomNavItem(
            icon: Icons.notifications,
            semanticLabel: 'Notifications',
            showBadge: _unreadNotificationCount > 0,
          ),
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
  const _BottomNavItem({
    required this.icon,
    required this.semanticLabel,
    this.showBadge = false,
  });
}

