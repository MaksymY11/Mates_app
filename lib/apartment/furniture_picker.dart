import 'package:flutter/material.dart';
import '../services/apartment_service.dart';

/// Icon mapping from seed icon_name to Material Icons.
final Map<String, IconData> furnitureIcons = {
  'twin_bed': Icons.single_bed,
  'queen_bed': Icons.bed,
  'loft_bed': Icons.bed_outlined,
  'study_desk': Icons.desk,
  'art_desk': Icons.brush,
  'desk_lamp': Icons.light,
  'fairy_lights': Icons.auto_awesome,
  'led_strip': Icons.highlight,
  'bookshelf': Icons.menu_book,
  'potted_plants': Icons.yard,
  'poster_wall': Icons.image,
  'under_bed_storage': Icons.inventory_2,
  'couch': Icons.weekend,
  'bean_bag': Icons.chair,
  'reading_nook': Icons.chair_alt,
  'tv': Icons.tv,
  'board_games': Icons.casino,
  'record_player': Icons.album,
  'gallery_wall': Icons.photo_library,
  'indoor_plants': Icons.park,
  'shoe_rack': Icons.shelves,
  'yoga_mat': Icons.self_improvement,
  'espresso_machine': Icons.coffee,
  'tea_station': Icons.emoji_food_beverage,
  'blender': Icons.blender,
  'cast_iron_pan': Icons.soup_kitchen,
  'baking_kit': Icons.cake,
  'microwave': Icons.microwave,
  'spice_rack': Icons.kitchen,
  'meal_prep': Icons.lunch_dining,
  'chalkboard_menu': Icons.edit_note,
  'herb_garden': Icons.grass,
  'shower': Icons.shower,
  'spa_shower': Icons.hot_tub,
  'minimal_vanity': Icons.wash,
  'skincare_station': Icons.face_retouching_natural,
  'candle': Icons.local_fire_department,
  'towel_organizer': Icons.dry_cleaning,
  'bathroom_plants': Icons.spa,
  'magazine_rack': Icons.auto_stories,
};

IconData iconFor(String iconName) => furnitureIcons[iconName] ?? Icons.chair;

/// Modal bottom sheet: category list → item list → place item.
/// Returns updated apartment data on placement, or null if dismissed.
Future<Map<String, dynamic>?> showFurniturePicker(
  BuildContext context, {
  required String zone,
  required Map<String, dynamic> zoneCategories,
  required Set<int> placedFurnitureIds,
  required Map<int, Map<String, dynamic>> furnitureLookup,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FurniturePickerSheet(
      zone: zone,
      zoneCategories: zoneCategories,
      placedFurnitureIds: placedFurnitureIds,
      furnitureLookup: furnitureLookup,
    ),
  );
}

class _FurniturePickerSheet extends StatefulWidget {
  final String zone;
  final Map<String, dynamic> zoneCategories;
  final Set<int> placedFurnitureIds;
  final Map<int, Map<String, dynamic>> furnitureLookup;

  const _FurniturePickerSheet({
    required this.zone,
    required this.zoneCategories,
    required this.placedFurnitureIds,
    required this.furnitureLookup,
  });

  @override
  State<_FurniturePickerSheet> createState() => _FurniturePickerSheetState();
}

class _FurniturePickerSheetState extends State<_FurniturePickerSheet> {
  String? _selectedCategory;
  bool _loading = false;

  String get _zoneLabel => widget.zone.replaceAll('_', ' ');

  /// Find the currently placed item in a category (if any).
  Map<String, dynamic>? _placedItemInCategory(List<dynamic> items) {
    for (final item in items) {
      final f = item as Map<String, dynamic>;
      if (widget.placedFurnitureIds.contains(f['id'] as int)) return f;
    }
    return null;
  }

  Future<void> _placeItem(int furnitureId) async {
    setState(() => _loading = true);
    try {
      final apartment = await ApartmentService.placeItem(
        furnitureId,
        widget.zone,
      );
      if (mounted) Navigator.of(context).pop(apartment);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _buildHandle(),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_selectedCategory == null)
              _buildCategoryList(scrollController)
            else
              _buildItemList(scrollController),
          ],
        );
      },
    );
  }

  Widget _buildHandle() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Screen 1: list of categories, each showing the placed item icon if any.
  Widget _buildCategoryList(ScrollController scrollController) {
    final brand = Theme.of(context).colorScheme.primary;
    final categories = widget.zoneCategories.entries.toList();

    return Expanded(
      child: Column(
        children: [
          Text(
            'Add furniture — $_zoneLabel',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final catName = categories[index].key;
                final items = categories[index].value as List<dynamic>;
                final placed = _placedItemInCategory(items);
                final label =
                    catName[0].toUpperCase() + catName.substring(1);

                return Material(
                  color: Colors.white,
                  elevation: 1,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        setState(() => _selectedCategory = catName),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: placed != null
                                  ? brand.withValues(alpha: 0.12)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: placed != null
                                ? Icon(
                                    iconFor(placed['icon_name'] as String),
                                    color: brand,
                                    size: 26,
                                  )
                                : Icon(
                                    Icons.add,
                                    color: Colors.grey[400],
                                    size: 24,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (placed != null)
                                  Text(
                                    placed['name'] as String,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Screen 2: items within the selected category. Placed item shown first.
  Widget _buildItemList(ScrollController scrollController) {
    final brand = Theme.of(context).colorScheme.primary;
    final items =
        widget.zoneCategories[_selectedCategory] as List<dynamic>;
    final label = _selectedCategory![0].toUpperCase() +
        _selectedCategory!.substring(1);

    // Sort: placed item first.
    final sorted = List<Map<String, dynamic>>.from(
      items.map((e) => e as Map<String, dynamic>),
    );
    sorted.sort((a, b) {
      final aPlaced = widget.placedFurnitureIds.contains(a['id'] as int);
      final bPlaced = widget.placedFurnitureIds.contains(b['id'] as int);
      if (aPlaced && !bPlaced) return -1;
      if (!aPlaced && bPlaced) return 1;
      return 0;
    });

    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    setState(() => _selectedCategory = null),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final f = sorted[index];
                final fId = f['id'] as int;
                final isPlaced =
                    widget.placedFurnitureIds.contains(fId);
                final icon = iconFor(f['icon_name'] as String);

                return Material(
                  color: isPlaced
                      ? brand.withValues(alpha: 0.08)
                      : Colors.white,
                  elevation: isPlaced ? 0 : 1,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isPlaced ? null : () => _placeItem(fId),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isPlaced
                                  ? brand.withValues(alpha: 0.15)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: brand, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  f['description'] as String,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPlaced)
                            Icon(
                              Icons.check_circle,
                              color: brand,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
