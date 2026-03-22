// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'package:mates/login_page.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';

const Color kBrand = Color(0xFF7CFF7C);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // display-only
  final _ageCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _moveInCtrl = TextEditingController(); // shows selected date as text
  // In-memory avatar bytes (not persisted). Integrate image_picker/uploader later.
  Uint8List? _avatarData;
  String? _avatarUrl; // Full-size avatar from server
  String? _avatarThumbUrl; // Thumbnail avatar from server
  final ImagePicker _picker = ImagePicker();
  // Local avatar file path key
  static const String _kAvatarPathKey = 'avatar_path';

  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  // Selections
  String? _state;
  DateTime? _moveInDate;

  // Chips data (you can localize/rename freely)
  final List<String> lifestyleOptions = const [
    'Early Bird',
    'Night Owl',
    'Clean',
    'Social',
    'Quiet',
    'Organized',
  ];
  final List<String> activitiesOptions = const [
    'Gym',
    'Cooking',
    'Reading',
    'Gaming',
    'Hiking',
    'Music',
    'Movies',
    'Sports',
    'Yoga',
    'Art',
  ];
  final List<String> prefsOptions = const [
    'Pet Friendly',
    'No Pets',
    'Non-Smoker',
    '420 Friendly',
    'LGBTQ+ Friendly',
    'Vegetarian',
  ];

  final Set<String> lifestyle = {};
  final Set<String> activities = {};
  final Set<String> prefs = {};

  // US states (abbr or full names; pick your style)
  final List<String> states = const [
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
  ];

  @override
  void initState() {
    super.initState();
    // Update UI when about text changes so the word-count updates live.
    _aboutCtrl.addListener(() => setState(() {}));
    _loadProfile();
    _loadLocalAvatar();
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickFromGallery();
                  },
                ),
                if (_avatarData != null)
                  ListTile(
                    leading: const Icon(Icons.delete_forever),
                    title: const Text('Remove Photo'),
                    onTap: () async {
                      await _removeLocalAvatar();
                      Navigator.of(ctx).pop();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _ageCtrl.dispose();
    _cityCtrl.dispose();
    _budgetCtrl.dispose();
    _aboutCtrl.dispose();
    _moveInCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final Map<String, dynamic> j = await ApiService.get('/me');

      // Map server fields to UI. Add null checks for fields not present yet.
      _emailCtrl.text = (j['email'] ?? '').toString();
      _nameCtrl.text = (j['name'] ?? '').toString();
      _ageCtrl.text = (j['age']?.toString() ?? '');
      _cityCtrl.text = (j['city'] ?? '').toString();
      _budgetCtrl.text = (j['budget']?.toString() ?? '');
      _aboutCtrl.text = (j['bio'] ?? j['about'] ?? '').toString();
      _state = (j['state'] ?? '') == '' ? null : j['state'];

      // Avatar URLs from server
      _avatarUrl = j['avatar_url'] as String?;
      _avatarThumbUrl = j['avatar_thumb_url'] as String?;
      if (_avatarUrl != null || _avatarThumbUrl != null) {
        // If server avatar exists, clear local avatar
        setState(() => _avatarData = null);
      }

      // move-in date (expecting ISO 'YYYY-MM-DD' or timestamp)
      final moveIn = j['move_in_date'];
      if (moveIn != null && moveIn.toString().isNotEmpty) {
        try {
          _moveInDate = DateTime.tryParse(moveIn.toString());
          if (_moveInDate != null) {
            _moveInCtrl.text = _fmtDate(_moveInDate!);
          }
        } catch (_) {}
      }

      // Multi-selects (expect arrays of strings)
      lifestyle
        ..clear()
        ..addAll(((j['lifestyle'] ?? []) as List).map((e) => e.toString()));
      activities
        ..clear()
        ..addAll(((j['activities'] ?? []) as List).map((e) => e.toString()));
      prefs
        ..clear()
        ..addAll(((j['prefs'] ?? []) as List).map((e) => e.toString()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      // Enforce 5MB max image size
      const maxBytes = 5 * 1024 * 1024;
      if (bytes.lengthInBytes > maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image too large (max 5MB)')),
          );
        }
        return;
      }
      setState(() => _avatarData = bytes);
      await _saveAvatarLocally(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      const maxBytes = 5 * 1024 * 1024;
      if (bytes.lengthInBytes > maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image too large (max 5MB)')),
          );
        }
        return;
      }
      setState(() => _avatarData = bytes);
      await _saveAvatarLocally(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to take photo: $e')));
      }
    }
  }

  Future<void> _saveAvatarLocally(Uint8List bytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/profile_avatar.jpg');
      await file.writeAsBytes(bytes, flush: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAvatarPathKey, file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save avatar locally: $e')),
        );
      }
    }
  }

  Future<void> _loadLocalAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_kAvatarPathKey);
      if (path == null) return;
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _avatarData = bytes);
      } else {
        await prefs.remove(_kAvatarPathKey);
      }
    } catch (_) {}
  }

  Future<void> _removeLocalAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_kAvatarPathKey);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
        await prefs.remove(_kAvatarPathKey);
      }
      if (mounted) setState(() => _avatarData = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove avatar: $e')));
      }
    }
  }

  Future<String> uploadAvatar(Uint8List bytes) async {
    final j = await ApiService.uploadFile(
      '/uploadAvatar',
      bytes: bytes,
      filename: 'avatar.jpg',
    );
    setState(() {
      _avatarUrl = j['avatar_url'] as String?;
      _avatarThumbUrl = j['avatar_thumb_url'] as String?;
      _avatarData = null;
    });
    return j['avatar_url'] as String? ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? avatarUrl;
      if (_avatarData != null) {
        avatarUrl = await uploadAvatar(_avatarData!);
      }

      final body = {
        'name': _nameCtrl.text.trim(),
        'age':
            _ageCtrl.text.trim().isEmpty
                ? null
                : int.tryParse(_ageCtrl.text.trim()),
        'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'budget':
            _budgetCtrl.text.trim().isEmpty
                ? null
                : double.tryParse(_budgetCtrl.text.trim()),
        'bio': _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim(),
        'state': _state,
        'move_in_date': _moveInDate?.toIso8601String(),
        'lifestyle': lifestyle.toList(),
        'activities': activities.toList(),
        'prefs': prefs.toList(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

      // Remove nulls so backend sees only provided keys
      body.removeWhere((key, value) => value == null);

      await ApiService.post('/updateUser', body: body);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    try {
      await _removeLocalAvatar();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Tell the server to invalidate the token
      if (token != null) {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/logout'),
          headers: {'Authorization': 'Bearer $token'},
        );
      }

      await prefs.remove('auth_token');
    } catch (_) {
      // Even if the server call fails, still log out locally
      await _removeLocalAvatar();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background (ends around top-half)
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kBrand, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Material(
                            color: Colors.white,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Profile Information',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Avatar + mini edit button (left aligned)
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _showImageOptions(),
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              // Avatar shows selected image if available, otherwise initials or icon
                                              CircleAvatar(
                                                radius: 36,
                                                backgroundColor: cs.primary
                                                    .withOpacity(0.2),
                                                backgroundImage:
                                                    // Prefer server thumbnail, then full, then local
                                                    _avatarThumbUrl != null
                                                        ? NetworkImage(
                                                          _avatarThumbUrl!,
                                                        )
                                                        : _avatarUrl != null
                                                        ? NetworkImage(
                                                          _avatarUrl!,
                                                        )
                                                        : _avatarData != null
                                                        ? MemoryImage(
                                                          _avatarData!,
                                                        )
                                                        : null,
                                                child:
                                                    (_avatarThumbUrl == null &&
                                                            _avatarUrl ==
                                                                null &&
                                                            _avatarData == null)
                                                        ? Builder(
                                                          builder: (ctx) {
                                                            final name =
                                                                _nameCtrl.text
                                                                    .trim();
                                                            final initials =
                                                                name.isEmpty
                                                                    ? ''
                                                                    : name
                                                                        .split(
                                                                          ' ',
                                                                        )
                                                                        .where(
                                                                          (s) =>
                                                                              s.isNotEmpty,
                                                                        )
                                                                        .map(
                                                                          (s) =>
                                                                              s[0],
                                                                        )
                                                                        .take(2)
                                                                        .join()
                                                                        .toUpperCase();
                                                            return initials
                                                                    .isEmpty
                                                                ? Icon(
                                                                  Icons.person,
                                                                  size: 40,
                                                                  color:
                                                                      cs.primary,
                                                                )
                                                                : Text(
                                                                  initials,
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        20,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        cs.primary,
                                                                  ),
                                                                );
                                                          },
                                                        )
                                                        : null,
                                              ),
                                              Positioned(
                                                right: -2,
                                                bottom: -2,
                                                child: InkWell(
                                                  onTap:
                                                      () => _showImageOptions(),
                                                  child: Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      color: cs.primary,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons.camera_alt,
                                                      size: 18,
                                                      color: cs.onPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            'Upload a clear photo of yourself. JPG, PNG or GIF (max 5MB)',
                                            style: TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 24),

                                    _label('Full Name'),
                                    TextFormField(
                                      controller: _nameCtrl,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter your name',
                                      ),
                                      validator:
                                          (v) =>
                                              (v == null || v.trim().isEmpty)
                                                  ? 'Please enter your name'
                                                  : null,
                                    ),
                                    const SizedBox(height: 16),

                                    // Age & State
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _label('Age'),
                                              TextFormField(
                                                controller: _ageCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: '25',
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _label('State'),
                                              DropdownButtonFormField<String>(
                                                value: _state,
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: 'Select state',
                                                    ),
                                                items:
                                                    states
                                                        .map(
                                                          (s) =>
                                                              DropdownMenuItem(
                                                                value: s,
                                                                child: Text(s),
                                                              ),
                                                        )
                                                        .toList(),
                                                onChanged:
                                                    (v) => setState(
                                                      () => _state = v,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    _label('City'),
                                    TextFormField(
                                      controller: _cityCtrl,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter your city',
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Budget & Move-in
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _label('Monthly Budget (USD)'),
                                              TextFormField(
                                                controller: _budgetCtrl,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                decoration:
                                                    const InputDecoration(
                                                      prefixText: '\$ ',
                                                      hintText: '1500',
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _label('Move-in Date'),
                                              TextFormField(
                                                controller: _moveInCtrl,
                                                readOnly: true,
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: 'MM/DD/YYYY',
                                                      suffixIcon: Icon(
                                                        Icons.calendar_today,
                                                      ),
                                                    ),
                                                onTap: () async {
                                                  final now = DateTime.now();
                                                  final picked =
                                                      await showDatePicker(
                                                        context: context,
                                                        initialDate:
                                                            _moveInDate ?? now,
                                                        firstDate: now,
                                                        lastDate: DateTime(
                                                          now.year + 5,
                                                        ),
                                                      );
                                                  if (picked != null) {
                                                    setState(() {
                                                      _moveInDate = picked;
                                                      _moveInCtrl.text =
                                                          _fmtDate(picked);
                                                    });
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _label('About You'),
                                        Text(
                                          '${_aboutCtrl.text.trim().isEmpty ? 0 : _aboutCtrl.text.trim().split(RegExp(r"\s+")).length}/50 words',
                                          style: const TextStyle(
                                            color: Colors.black45,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextFormField(
                                      controller: _aboutCtrl,
                                      maxLines: 4,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Tell potential roommates about yourself, your lifestyle, and what you’re looking for… (up to 50 words)',
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    _sectionTitle('Interests & Lifestyle'),

                                    _chipGroup(
                                      title: 'Lifestyle',
                                      options: lifestyleOptions,
                                      selected: lifestyle,
                                    ),
                                    const SizedBox(height: 12),

                                    _chipGroup(
                                      title: 'Activities',
                                      options: activitiesOptions,
                                      selected: activities,
                                    ),
                                    const SizedBox(height: 12),

                                    _chipGroup(
                                      title: 'Preferences',
                                      options: prefsOptions,
                                      selected: prefs,
                                    ),

                                    const SizedBox(height: 24),

                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _saving ? null : _save,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: cs.primary,
                                          foregroundColor: cs.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child:
                                            _saving
                                                ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                                : const Text(
                                                  'Save Profile',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _logout,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Log Out',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
  );

  Widget _chipGroup({
    required String title,
    required List<String> options,
    required Set<String> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options.map((opt) {
                final isSelected = selected.contains(opt);
                return FilterChip(
                  selected: isSelected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        selected.add(opt);
                      } else {
                        selected.remove(opt);
                      }
                    });
                  },
                  label: Text(opt),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isSelected ? kBrand : Colors.black26,
                      width: 1,
                    ),
                  ),
                  selectedColor: kBrand.withOpacity(0.25),
                  checkmarkColor: Colors.black,
                  showCheckmark: true,
                );
              }).toList(),
        ),
      ],
    );
  }
}
