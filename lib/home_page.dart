import 'package:flutter/material.dart';
import 'profile_page.dart';

/// Entry point for logged-in users.
/// Shows a bottom nav with 5 tabs; the center (index 2) is the Home/Profiles feed.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Center tab is the default (= Home / profiles feed)
  int _currentIndex = 2;

  // Keep pages alive with an IndexedStack
  late final List<Widget> _pages = const [
    MatchingPage(),
    ChatsPage(),
    HomeFeedPage(), // center
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
          _BottomNavItem(icon: Icons.favorite, semanticLabel: 'Matching'),
          _BottomNavItem(
            icon: Icons.chat_bubble_rounded,
            semanticLabel: 'Chats',
          ),
          _BottomNavItem(icon: Icons.people_alt_rounded, semanticLabel: 'Home'),
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

/// -------- Pages (stubs you can expand) --------

/// Center tab: show other user profiles as cards.
class HomeFeedPage extends StatelessWidget {
  const HomeFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;

    // Mock profiles
    final profiles = [
      const _Profile(
        name: 'Ava',
        age: 24,
        city: 'Seattle',
        bio: 'Early bird, loves hiking and coffee.',
      ),
      const _Profile(
        name: 'Noah',
        age: 26,
        city: 'San Jose',
        bio: 'Night owl dev, tidy, gym 5x/week.',
      ),
      const _Profile(
        name: 'Mia',
        age: 23,
        city: 'San Diego',
        bio: 'Student, plants & pilates fan.',
      ),
      const _Profile(
        name: 'Ethan',
        age: 29,
        city: 'Los Angeles',
        bio: 'Chef, neat, enjoys board games.',
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      itemBuilder:
          (context, i) => _ProfileCard(profile: profiles[i], brand: brand),
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemCount: profiles.length,
    );
  }
}

class _Profile {
  final String name;
  final int age;
  final String city;
  final String bio;
  const _Profile({
    required this.name,
    required this.age,
    required this.city,
    required this.bio,
  });
}

class _ProfileCard extends StatelessWidget {
  final _Profile profile;
  final Color brand;
  const _ProfileCard({required this.profile, required this.brand});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // TODO: open profile details
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: brand.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, size: 36, color: brand),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.name}, ${profile.age}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.city,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.favorite_border),
                color: brand,
                onPressed: () {
                  // TODO: like/save profile
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MatchingPage extends StatelessWidget {
  const MatchingPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const _CenterLabel(icon: Icons.favorite, label: 'Matching');
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
