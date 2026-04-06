import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/apartment_service.dart';
import '../services/vibe_service.dart';
import '../services/scenario_service.dart';
import 'furniture_picker.dart';
import 'vibe_picker_page.dart';

const List<String> _zoneKeys = [
  'bedroom',
  'living_room',
  'kitchen',
  'bathroom',
];
const List<String> _zoneLabels = [
  'Bedroom',
  'Living Room',
  'Kitchen',
  'Bathroom',
];
const List<IconData> _zoneIcons = [
  Icons.bed,
  Icons.weekend,
  Icons.kitchen,
  Icons.bathtub,
];

class ApartmentBuilderPage extends StatefulWidget {
  const ApartmentBuilderPage({super.key});

  @override
  State<ApartmentBuilderPage> createState() => _ApartmentBuilderPageState();
}

class _ApartmentBuilderPageState extends State<ApartmentBuilderPage>
    with SingleTickerProviderStateMixin {
  bool _initialLoading = true;
  String? _error;

  List<dynamic> _items = [];
  Map<String, dynamic> _catalog = {};
  Map<String, dynamic> _presets = {};
  Map<int, Map<String, dynamic>> _furnitureLookup = {};

  List<String> _vibeLabels = [];

  // Daily scenario state
  Map<String, dynamic>? _dailyScenario;
  bool _scenarioCompletedToday = false;
  bool _scenarioAllAnswered = false;
  bool _scenarioRequiresSubstitution = false;
  List<dynamic> _scenarioCurrentResponses = [];

  /// Currently zoomed zone index, or null for overview.
  int? _activeZone;
  bool _sideMenuOpen = false;
  bool _bottomPanelOpen = false;

  late final AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _zoomAnimation = CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOut,
    );
    _zoomController.addListener(() => setState(() {}));
    _init();
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  /// Loads apartment, catalog, and presets in parallel.
  /// Catalog and apartment are required; presets degrade gracefully to empty.
  Future<void> _init() async {
    try {
      Future<T?> tryFetch<T>(Future<T> future) async {
        try {
          return await future;
        } catch (_) {
          return null;
        }
      }

      final results = await Future.wait([
        tryFetch(ApartmentService.createApartment()),
        tryFetch(ApartmentService.getCatalog()),
        tryFetch(ApartmentService.getPresets()),
      ]);
      if (!mounted) return;

      final apartment = results[0];
      final catalog = results[1];
      final presets = results[2];

      final lookup = <int, Map<String, dynamic>>{};
      if (apartment == null || catalog == null) {
        setState(() {
          _error = 'Failed to load apartment data. Please try again.';
          _initialLoading = false;
        });
        return;
      }
      for (final zoneEntry in catalog.entries) {
        final categories = zoneEntry.value as Map<String, dynamic>;
        for (final catEntry in categories.entries) {
          for (final item in catEntry.value as List<dynamic>) {
            final f = item as Map<String, dynamic>;
            lookup[f['id'] as int] = f;
          }
        }
      }

      setState(() {
        _items = apartment['items'] as List<dynamic>? ?? [];
        _catalog = catalog;
        _presets = presets ?? {};
        _furnitureLookup = lookup;
        _initialLoading = false;
      });
      _fetchVibe();
      _fetchDailyScenario();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _initialLoading = false;
      });
    }
  }

  Future<void> _fetchVibe() async {
    try {
      final vibe = await VibeService.getMyVibe();
      if (mounted) {
        setState(() {
          _vibeLabels = List<String>.from(vibe['vibe_labels'] ?? []);
        });
      }
    } catch (_) {
      // Non-critical — vibe card simply won't show
    }
  }

  Future<void> _fetchDailyScenario() async {
    try {
      final data = await ScenarioService.getDaily();
      if (mounted) {
        setState(() {
          _dailyScenario = data['scenario'] as Map<String, dynamic>?;
          _scenarioCompletedToday = data['completed_today'] == true;
          _scenarioAllAnswered = data['all_answered'] == true;
          _scenarioRequiresSubstitution = data['requires_substitution'] == true;
          _scenarioCurrentResponses =
              data['current_responses'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _openScenarioSheet() async {
    if (_dailyScenario == null) return;

    final scenario = _dailyScenario!;
    final prompt = scenario['prompt'] as String? ?? '';
    final options = scenario['options'] as List<dynamic>? ?? [];
    final scenarioId = scenario['id'] as int;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _ScenarioBottomSheet(
            prompt: prompt,
            options: options,
            requiresSubstitution: _scenarioRequiresSubstitution,
            currentResponses: _scenarioCurrentResponses,
            onAnswer: (String selectedOption, int? replaceScenarioId) async {
              await ScenarioService.answer(
                scenarioId: scenarioId,
                selectedOption: selectedOption,
                replaceScenarioId: replaceScenarioId,
              );
              if (mounted) {
                _fetchDailyScenario();
              }
            },
            onSkip: () async {
              await ScenarioService.skip();
              if (mounted) {
                _fetchDailyScenario();
              }
            },
          ),
    );
  }

  void _updateApartment(Map<String, dynamic> apartment) {
    if (!mounted) return;
    setState(() {
      _items = apartment['items'] as List<dynamic>? ?? [];
    });
    _fetchVibe();
  }

  List<dynamic> _itemsForZone(String zone) {
    return _items
        .where((item) => (item as Map<String, dynamic>)['zone'] == zone)
        .toList();
  }

  Set<int> _placedFurnitureIdsForZone(String zone) {
    return _itemsForZone(zone)
        .map((item) => (item as Map<String, dynamic>)['furniture_id'] as int)
        .toSet();
  }

  void _selectZone(int index) {
    setState(() {
      _activeZone = index;
      _bottomPanelOpen = true;
      _sideMenuOpen = false;
    });
    _zoomController.forward();
  }

  void _zoomOut() {
    _zoomController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _activeZone = null;
          _bottomPanelOpen = false;
        });
      }
    });
  }

  Future<void> _removeItem(int itemId) async {
    try {
      await ApartmentService.removeItem(itemId);
      final apartment = await ApartmentService.getMyApartment();
      if (mounted) {
        _updateApartment(apartment);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update apartment. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _openFurniturePicker(String zone) async {
    final zoneCategories = _catalog[zone] as Map<String, dynamic>?;
    if (zoneCategories == null) return;

    final beforeCount = _itemsForZone(zone).length;

    final result = await showFurniturePicker(
      context,
      zone: zone,
      zoneCategories: zoneCategories,
      placedFurnitureIds: _placedFurnitureIdsForZone(zone),
      furnitureLookup: _furnitureLookup,
    );
    if (result != null && mounted) {
      _updateApartment(result);
      // If item count didn't increase, a constraint group swap happened.
      final afterCount = _itemsForZone(zone).length;
      if (afterCount <= beforeCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Replaced with your new choice')),
        );
      }
    }
  }

  Future<void> _openPresetPicker(String zone) async {
    final zonePresets = _presets[zone] as List<dynamic>?;
    if (zonePresets == null || zonePresets.isEmpty) return;

    final result = await showPresetPicker(
      context,
      zone: zone,
      presets: zonePresets,
    );
    if (result != null && mounted) _updateApartment(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
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
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _initialLoading = true;
                    _error = null;
                  });
                  _init();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Apartment viewport
            _buildApartmentView(),
            // Side menu
            _buildSideMenu(),
            // Side menu toggle
            if (_activeZone == null)
              Positioned(
                top: 12,
                left: 12,
                child: _circleButton(
                  icon: _sideMenuOpen ? Icons.close : Icons.menu,
                  onTap: () => setState(() => _sideMenuOpen = !_sideMenuOpen),
                ),
              ),
            // Back button when zoomed
            if (_activeZone != null)
              Positioned(
                top: 12,
                left: 12,
                child: _circleButton(icon: Icons.arrow_back, onTap: _zoomOut),
              ),
            // Zone label when zoomed
            if (_activeZone != null)
              Positioned(
                top: 52,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _zoomAnimation.value,
                    duration: Duration.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Text(
                        _zoneLabels[_activeZone!],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Vibe summary card (always visible when labels exist)
            if (_vibeLabels.isNotEmpty) _buildVibeCard(),
            // Daily scenario banner
            if (_dailyScenario != null &&
                !_scenarioCompletedToday &&
                _activeZone == null)
              _buildScenarioBanner(),
            // All scenarios answered
            if (_scenarioAllAnswered &&
                _dailyScenario == null &&
                !_scenarioCompletedToday &&
                _activeZone == null)
              _buildAllAnsweredBanner(),
            // Bottom panel
            if (_activeZone != null) _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }

  // ─── Apartment isometric view ────────────────────────────────────

  Widget _buildApartmentView() {
    final brand = Theme.of(context).colorScheme.primary;
    final size = MediaQuery.of(context).size;
    final gridSize = math.min(size.width * 0.85, size.height * 0.55);

    // Zoom: interpolate from overview to focused room.
    final zoom = _zoomAnimation.value;
    final scale = 1.0 + zoom * 1.2;
    // Negative X rotation = top tilts away, grid lays flat like a floor.
    final tiltAngle = -(45.0 - zoom * 25.0) * math.pi / 180.0;

    // Offset to center the active zone when zoomed.
    double offsetX = 0;
    double offsetY = 0;
    if (_activeZone != null) {
      // Quadrant offsets: 0=topLeft, 1=topRight, 2=bottomLeft, 3=bottomRight
      final row = _activeZone! < 2 ? -1.0 : 1.0;
      final col = _activeZone! % 2 == 0 ? -1.0 : 1.0;
      offsetX = -col * gridSize * 0.25 * zoom;
      offsetY = -row * gridSize * 0.25 * zoom;
    }

    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform:
            Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(tiltAngle)
              ..scaleByDouble(scale, scale, scale, 1.0)
              ..translateByDouble(offsetX, offsetY, 0.0, 1.0),
        child: SizedBox(
          width: gridSize,
          height: gridSize,
          child: _buildRoomGrid(gridSize, brand),
        ),
      ),
    );
  }

  Widget _buildRoomGrid(double gridSize, Color brand) {
    final roomSize = gridSize / 2;

    return Stack(
      children: [
        // Floor/shadow
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
        ),
        // 4 rooms in a 2x2 grid
        for (int i = 0; i < 4; i++)
          Positioned(
            left: (i % 2) * roomSize,
            top: (i ~/ 2) * roomSize,
            width: roomSize,
            height: roomSize,
            child: _buildRoom(i, brand),
          ),
      ],
    );
  }

  Widget _buildRoom(int index, Color brand) {
    final zone = _zoneKeys[index];
    final label = _zoneLabels[index];
    final zoneItems = _itemsForZone(zone);
    final isActive = _activeZone == index;
    final zoom = _zoomAnimation.value;
    final brandLight = Theme.of(context).colorScheme.secondary;

    // Dim non-active rooms when zoomed.
    final opacity =
        _activeZone == null ? 1.0 : (isActive ? 1.0 : 1.0 - zoom * 0.7);

    // Room colors.
    final roomColors = [
      const Color(0xFFF3E8FF), // bedroom — soft lavender
      const Color(0xFFE8F5E9), // living room — soft green
      const Color(0xFFFFF8E1), // kitchen — soft warm yellow
      const Color(0xFFE3F2FD), // bathroom — soft blue
    ];

    return GestureDetector(
      onTap: _activeZone == null ? () => _selectZone(index) : null,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: roomColors[index],
            border: Border.all(
              color: isActive ? brandLight : Colors.grey[400]!,
              width: isActive ? 2.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room label
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                // Furniture icons
                Expanded(
                  child:
                      zoneItems.isEmpty
                          ? Center(
                            child: Icon(
                              _zoneIcons[index],
                              size: 28,
                              color: Colors.grey[300],
                            ),
                          )
                          : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children:
                                zoneItems.map((item) {
                                  final f = item as Map<String, dynamic>;
                                  final fId = f['furniture_id'] as int;
                                  final furniture = _furnitureLookup[fId];
                                  final iconName =
                                      furniture?['icon_name'] as String? ?? '';
                                  return Tooltip(
                                    message:
                                        furniture?['name'] as String? ?? '',
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: brand.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        iconFor(iconName),
                                        size: 16,
                                        color: brand,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Side menu ───────────────────────────────────────────────────

  Widget _buildSideMenu() {
    final brand = Theme.of(context).colorScheme.primary;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      left: _sideMenuOpen ? 0 : -220,
      top: 60,
      bottom: 0,
      width: 220,
      child: Material(
        elevation: 4,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Rooms',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < 4; i++)
                ListTile(
                  leading: Icon(_zoneIcons[i], color: brand),
                  title: Text(_zoneLabels[i]),
                  dense: true,
                  onTap: () => _selectZone(i),
                ),
              const Divider(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Quick setup',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 4),
              for (int i = 0; i < 4; i++)
                ListTile(
                  leading: const Icon(Icons.style, size: 20),
                  title: Text(
                    '${_zoneLabels[i]} preset',
                    style: const TextStyle(fontSize: 13),
                  ),
                  dense: true,
                  onTap: () {
                    setState(() => _sideMenuOpen = false);
                    _openPresetPicker(_zoneKeys[i]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Vibe summary strip ─────────────────────────────────────────

  Widget _buildVibeCard() {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;
    return Positioned(
      left: 56,
      right: 0,
      top: 14,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 4, right: 16),
          itemCount: _vibeLabels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: brandLight.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: brandLight.withValues(alpha: 0.5)),
              ),
              child: Text(
                _vibeLabels[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: brand,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Bottom panel (furniture picker + placed items) ──────────────

  Widget _buildBottomPanel() {
    if (_activeZone == null) return const SizedBox.shrink();

    final brand = Theme.of(context).colorScheme.primary;
    final zone = _zoneKeys[_activeZone!];
    final zoneItems = _itemsForZone(zone);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        offset: Offset(0, _bottomPanelOpen ? 0 : 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 200) {
              setState(() => _bottomPanelOpen = false);
            }
          },
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openFurniturePicker(zone),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add furniture'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openPresetPicker(zone),
                          icon: const Icon(Icons.style, size: 18),
                          label: const Text('Use preset'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: brand,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Placed items list
                if (zoneItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No furniture placed yet. Tap "Add furniture" to start!',
                      style: TextStyle(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: zoneItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final i = zoneItems[index] as Map<String, dynamic>;
                        final itemId = i['id'] as int;
                        final furnitureId = i['furniture_id'] as int;
                        final furniture = _furnitureLookup[furnitureId];
                        final name = furniture?['name'] as String? ?? 'Unknown';
                        final iconName =
                            furniture?['icon_name'] as String? ?? '';

                        return Material(
                          color: brand.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(iconFor(iconName), color: brand, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _removeItem(itemId),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Scenario banners ────────────────────────────────────────────

  Widget _buildAllAnsweredBanner() {
    return Positioned(
      left: 16,
      right: 16,
      top: _vibeLabels.isNotEmpty ? 52 : 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.grey[400], size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "You've answered all available scenarios!",
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioBanner() {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;
    final prompt = _dailyScenario?['prompt'] as String? ?? '';

    return Positioned(
      left: 16,
      right: 16,
      top: _vibeLabels.isNotEmpty ? 52 : 14,
      child: GestureDetector(
        onTap: _openScenarioSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: brandLight.withValues(alpha: 0.5)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.quiz_outlined, color: brand, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Daily Scenario',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: brand,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prompt,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Scenario Bottom Sheet ──────────────────────────────────────────

class _ScenarioBottomSheet extends StatefulWidget {
  final String prompt;
  final List<dynamic> options;
  final bool requiresSubstitution;
  final List<dynamic> currentResponses;
  final Future<void> Function(String selectedOption, int? replaceScenarioId)
  onAnswer;
  final Future<void> Function() onSkip;

  const _ScenarioBottomSheet({
    required this.prompt,
    required this.options,
    required this.requiresSubstitution,
    required this.currentResponses,
    required this.onAnswer,
    required this.onSkip,
  });

  @override
  State<_ScenarioBottomSheet> createState() => _ScenarioBottomSheetState();
}

class _ScenarioBottomSheetState extends State<_ScenarioBottomSheet> {
  String? _selectedOption;
  bool _showSubstitution = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (!_showSubstitution) ...[
              // Step 1: Show scenario + options
              Row(
                children: [
                  Icon(Icons.quiz_outlined, color: brand, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Daily Scenario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.prompt,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 18),
              ...widget.options.map((opt) {
                final o = opt as Map<String, dynamic>;
                final id = o['id'] as String;
                final text = o['text'] as String;
                final isSelected = _selectedOption == id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap:
                        _submitting
                            ? null
                            : () {
                              setState(() => _selectedOption = id);
                            },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? brandLight.withValues(alpha: 0.2)
                                : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? brand : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? brand : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _selectedOption == null || _submitting
                          ? null
                          : () async {
                            if (widget.requiresSubstitution) {
                              setState(() => _showSubstitution = true);
                            } else {
                              setState(() => _submitting = true);
                              final nav = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await widget.onAnswer(_selectedOption!, null);
                                if (mounted) nav.pop();
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                  setState(() => _submitting = false);
                                }
                              }
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _submitting
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'Confirm Answer',
                            style: TextStyle(fontSize: 15),
                          ),
                ),
              ),
            ] else ...[
              // Step 2: Substitution — pick which of the 3 to replace
              Row(
                children: [
                  Icon(Icons.swap_horiz, color: brand, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Replace an answer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'You already have 3 scenario answers on your profile. '
                'Tap one to replace it with your new answer, or keep your current ones.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ...widget.currentResponses.map((r) {
                final resp = r as Map<String, dynamic>;
                final scenarioId = resp['scenario_id'] as int;
                final prompt = resp['prompt'] as String? ?? '';
                final selectedText = resp['selected_text'] as String? ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap:
                        _submitting
                            ? null
                            : () async {
                              setState(() => _submitting = true);
                              final nav = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await widget.onAnswer(
                                  _selectedOption!,
                                  scenarioId,
                                );
                                if (mounted) nav.pop();
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                  setState(() => _submitting = false);
                                }
                              }
                            },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prompt,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 14,
                                color: brand,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  selectedText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: brand,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.swap_horiz,
                                size: 18,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed:
                      _submitting
                          ? null
                          : () async {
                            setState(() => _submitting = true);
                            final nav = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await widget.onSkip();
                              if (mounted) nav.pop();
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                                setState(() => _submitting = false);
                              }
                            }
                          },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Keep my current answers',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
