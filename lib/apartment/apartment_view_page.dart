import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/apartment_service.dart';
import '../services/vibe_service.dart';
import '../services/scenario_service.dart';
import '../services/quickpick_service.dart';
import '../services/household_service.dart';
import '../quickpicks/quick_pick_page.dart';
import 'furniture_picker.dart' show iconFor;

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

class ApartmentViewPage extends StatefulWidget {
  final int userId;
  final String? userName;

  const ApartmentViewPage({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  State<ApartmentViewPage> createState() => _ApartmentViewPageState();
}

class _ApartmentViewPageState extends State<ApartmentViewPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  List<dynamic> _items = [];
  Map<int, Map<String, dynamic>> _furnitureLookup = {};

  List<dynamic> _similarities = [];
  List<String> _conversationStarters = [];
  List<String> _theirVibeLabels = [];
  bool _vibeLoaded = false;

  // Scenario comparison
  List<dynamic> _scenarioComparisons = [];
  bool _scenariosLoaded = false;

  // Interest/wave state
  bool _waved = false;
  bool _waving = false;

  // Household invite
  bool _canInviteToHousehold = false;

  int? _activeZone;
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

  Future<void> _init() async {
    try {
      final results = await Future.wait([
        ApartmentService.getUserApartment(widget.userId),
        ApartmentService.getCatalog(),
        QuickPickService.getSentInterests(),
      ]);

      final apartment = results[0];
      final catalog = results[1];
      final sentData = results[2];
      final sentIds = Set<int>.from(
        (sentData['sent_to'] as List<dynamic>? ?? []).map((e) => e as int),
      );

      final lookup = <int, Map<String, dynamic>>{};
      for (final zoneEntry in catalog.entries) {
        final categories = zoneEntry.value as Map<String, dynamic>;
        for (final catEntry in categories.entries) {
          for (final item in catEntry.value as List<dynamic>) {
            final f = item as Map<String, dynamic>;
            lookup[f['id'] as int] = f;
          }
        }
      }

      if (mounted) {
        setState(() {
          _items = apartment['items'] as List<dynamic>? ?? [];
          _furnitureLookup = lookup;
          _waved = sentIds.contains(widget.userId);
          _loading = false;
        });
        _fetchComparison();
        _checkHouseholdInviteEligibility();
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

  Future<void> _fetchComparison() async {
    try {
      final comparison = await VibeService.compareVibe(widget.userId);
      if (mounted) {
        setState(() {
          _similarities = comparison['similarities'] as List<dynamic>? ?? [];
          _conversationStarters =
              List<String>.from(comparison['conversation_starters'] ?? []);
          final theirVibe =
              comparison['their_vibe'] as Map<String, dynamic>? ?? {};
          _theirVibeLabels =
              List<String>.from(theirVibe['vibe_labels'] ?? []);
          _vibeLoaded = true;
        });
      }
    } catch (_) {}

    try {
      final scenarioData = await ScenarioService.compare(widget.userId);
      if (mounted) {
        setState(() {
          _scenarioComparisons =
              scenarioData['comparisons'] as List<dynamic>? ?? [];
          _scenariosLoaded = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkHouseholdInviteEligibility() async {
    try {
      final results = await Future.wait([
        HouseholdService.getMyHousehold(),
        HouseholdService.getEligibleConnections(),
      ]);
      final household = results[0]['household'];
      if (household == null || !mounted) return;
      final eligible = results[1]['eligible'] as List<dynamic>? ?? [];
      final canInvite = eligible.any((u) => (u as Map)['id'] == widget.userId);
      if (mounted) setState(() => _canInviteToHousehold = canInvite);
    } catch (_) {}
  }

  Future<void> _inviteToHousehold() async {
    try {
      await HouseholdService.inviteUser(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to ${widget.userName ?? 'them'}!')),
        );
        setState(() => _canInviteToHousehold = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _toggleWave() async {
    if (_waving) return;

    if (_waved) {
      setState(() => _waving = true);
      try {
        await QuickPickService.withdrawInterest(widget.userId);
        if (mounted) {
          setState(() { _waved = false; _waving = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Withdrew wave from ${widget.userName ?? 'user'}')),
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
              'You waved at ${widget.userName ?? 'them'}! If they wave back, you\'ll be matched.',
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
            '${widget.userName ?? "They"} waved back! Answer 5 quick questions to break the ice.',
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
                      otherUserName: widget.userName,
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

  List<dynamic> _itemsForZone(String zone) {
    return _items
        .where((item) => (item as Map<String, dynamic>)['zone'] == zone)
        .toList();
  }

  void _selectZone(int index) {
    setState(() => _activeZone = index);
    _zoomController.forward();
  }

  void _zoomOut() {
    _zoomController.reverse().then((_) {
      if (mounted) setState(() => _activeZone = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.userName != null
        ? "${widget.userName}'s Apartment"
        : 'Apartment';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          if (_canInviteToHousehold)
            IconButton(
              onPressed: _inviteToHousehold,
              tooltip: 'Invite to Household',
              icon: const Icon(Icons.group_add_rounded),
            ),
          IconButton(
            onPressed: _waving ? null : _toggleWave,
            tooltip: _waved ? 'Withdraw wave' : 'Wave',
            icon: Icon(
              _waved ? Icons.waving_hand : Icons.waving_hand_outlined,
              color: _waved ? Colors.amber[700] : null,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                              _loading = true;
                              _error = null;
                            });
                            _init();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    _buildApartmentView(),
                    if (_activeZone == null && _vibeLoaded)
                      _buildVibeComparison(),
                    if (_activeZone != null) _buildBackButton(),
                    if (_activeZone != null) _buildZoneLabel(),
                    if (_activeZone != null) _buildItemsPanel(),
                  ],
                ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 12,
      left: 12,
      child: Material(
        color: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _zoomOut,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.arrow_back, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildZoneLabel() {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _zoomAnimation.value,
          duration: Duration.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: Text(
              _zoneLabels[_activeZone!],
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApartmentView() {
    final brand = Theme.of(context).colorScheme.primary;
    final size = MediaQuery.of(context).size;
    final gridSize = math.min(size.width * 0.85, size.height * 0.55);

    final zoom = _zoomAnimation.value;
    final scale = 1.0 + zoom * 1.2;
    final tiltAngle = -(45.0 - zoom * 25.0) * math.pi / 180.0;

    double offsetX = 0;
    double offsetY = 0;
    if (_activeZone != null) {
      final row = _activeZone! < 2 ? -1.0 : 1.0;
      final col = _activeZone! % 2 == 0 ? -1.0 : 1.0;
      offsetX = -col * gridSize * 0.25 * zoom;
      offsetY = -row * gridSize * 0.25 * zoom;
    }

    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
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
    final opacity =
        _activeZone == null ? 1.0 : (isActive ? 1.0 : 1.0 - zoom * 0.7);

    final roomColors = [
      const Color(0xFFF3E8FF),
      const Color(0xFFE8F5E9),
      const Color(0xFFFFF8E1),
      const Color(0xFFE3F2FD),
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: zoneItems.isEmpty
                      ? Center(
                          child: Icon(_zoneIcons[index],
                              size: 28, color: Colors.grey[300]),
                        )
                      : Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: zoneItems.map((item) {
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
                                child: Icon(iconFor(iconName),
                                    size: 16, color: brand),
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

  Widget _buildVibeComparison() {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;
    final hasContent = _theirVibeLabels.isNotEmpty ||
        _similarities.isNotEmpty ||
        _conversationStarters.isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Their vibe labels
              if (_theirVibeLabels.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: brand),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.userName ?? "Their"} Vibe',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _theirVibeLabels.map((label) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: brandLight.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: brandLight.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: brand,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              // Similarities
              if (_similarities.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.handshake, size: 18, color: Colors.green),
                    const SizedBox(width: 6),
                    const Text(
                      'In common',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...(_similarities).map((s) {
                  final sim = s as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'You both value ${sim["label"]}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              // Conversation starters
              if (_conversationStarters.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 18, color: Colors.orange),
                    const SizedBox(width: 6),
                    const Text(
                      'Worth discussing',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...(_conversationStarters).map((starter) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            starter,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              // Scenario answer comparisons
              if (_scenariosLoaded && _scenarioComparisons.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.quiz_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    const Text(
                      'Scenario Answers',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._scenarioComparisons.map((c) {
                  final comp = c as Map<String, dynamic>;
                  final prompt = comp['prompt'] as String? ?? '';
                  final myAnswer = comp['my_answer'] as String? ?? '';
                  final theirAnswer = comp['their_answer'] as String? ?? '';
                  final agreed = comp['agreed'] == true;
                  final starter = comp['conversation_starter'] as String?;
                  final accentColor =
                      agreed ? Colors.green : Colors.orange;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prompt,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('You: ',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Expanded(
                                child: Text(myAnswer,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.userName ?? "Them"}: ',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                              Expanded(
                                child: Text(theirAnswer,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          if (agreed) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.check_circle,
                                    size: 14, color: accentColor),
                                const SizedBox(width: 4),
                                Text(
                                  'You agree on this one!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (!agreed && starter != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb_outline,
                                    size: 14, color: accentColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    starter,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: accentColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Read-only panel showing placed items (no edit controls).
  Widget _buildItemsPanel() {
    final brand = Theme.of(context).colorScheme.primary;
    final zone = _zoneKeys[_activeZone!];
    final zoneItems = _itemsForZone(zone);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 300),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.35,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Text(
                'Placed furniture',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              if (zoneItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Nothing placed here yet.',
                    style: TextStyle(color: Colors.grey[500]),
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
                      final furnitureId = i['furniture_id'] as int;
                      final furniture = _furnitureLookup[furnitureId];
                      final name =
                          furniture?['name'] as String? ?? 'Unknown';
                      final desc =
                          furniture?['description'] as String? ?? '';
                      final iconName =
                          furniture?['icon_name'] as String? ?? '';

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: brand.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(iconFor(iconName),
                                color: brand, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (desc.isNotEmpty)
                                    Text(
                                      desc,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
