// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'services/user_service.dart'; // from earlier step

/// A realistic profile screen with Edit + Preview modes.
/// - Shows: avatar, name, email, age, city, bio, and a stats row (mock values)
/// - Edit: inline fields; Save calls UserService.updateMe(...)
/// - Preview: shows how others would see the card (later you can re-use this)
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Editable fields
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _age = TextEditingController();
  final _city = TextEditingController();
  final _bio = TextEditingController();

  // Non-editable (for now)
  String _email = '';

  bool _loading = true;
  bool _saving = false;
  bool _preview = false;

  // Mock stats (hook these to real metrics later)
  int _likes = 305;
  int _matches = 27;
  int _connections = 158;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _age.dispose();
    _city.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await UserService.getMe();
      // Split name (fallbacks are safe)
      final name = me.name;
      final parts = (name.isEmpty ? '' : name).split(' ');
      _firstName.text = parts.isNotEmpty ? parts.first : '';
      _lastName.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      _email = me.email;
      _age.text = me.age?.toString() ?? '';
      _city.text = me.city ?? '';
      _bio.text = me.bio ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final name = [
        _firstName.text.trim(),
        _lastName.text.trim(),
      ].where((s) => s.isNotEmpty).join(' ');

      final age =
          _age.text.trim().isEmpty ? null : int.tryParse(_age.text.trim());

      await UserService.updateMe(
        name: name,
        age: age,
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved')));
      setState(() => _preview = true); // flip into preview after saving
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = cs.primary;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      brand.withOpacity(0.95),
                      brand.withOpacity(0.6),
                      brand.withOpacity(0.25),
                      brand.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // ======== HEADER with avatar + name/email + Preview toggle
                      _Header(
                        firstName: _firstName.text,
                        lastName: _lastName.text,
                        email: _email,
                        brand: brand,
                        preview: _preview,
                        onTogglePreview:
                            () => setState(() => _preview = !_preview),
                        onEditAvatar: _onEditAvatar, // TODO: implement picker
                      ),
                      const SizedBox(height: 12),

                      // About Me
                      _CardSection(
                        title: 'About Me',
                        trailingEdit: !_preview,
                        child:
                            _preview
                                ? Text(
                                  _bio.text.isEmpty ? 'No bio yet.' : _bio.text,
                                  style: const TextStyle(fontSize: 16),
                                )
                                : TextFormField(
                                  controller: _bio,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'Tell people about yourself',
                                  ),
                                ),
                      ),
                      const SizedBox(height: 12),

                      // Stats row (read-only visual flair)
                      _StatsRow(
                        likes: _likes,
                        matches: _matches,
                        connections: _connections,
                      ),

                      const SizedBox(height: 12),

                      // Identity (name)
                      _CardSection(
                        title: 'Name',
                        trailingEdit: !_preview,
                        child:
                            _preview
                                ? Text(
                                  [
                                            _firstName.text.trim(),
                                            _lastName.text.trim(),
                                          ]
                                          .where((s) => s.isNotEmpty)
                                          .join(' ')
                                          .isEmpty
                                      ? 'No name set'
                                      : [
                                        _firstName.text.trim(),
                                        _lastName.text.trim(),
                                      ].where((s) => s.isNotEmpty).join(' '),
                                  style: const TextStyle(fontSize: 16),
                                )
                                : Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _firstName,
                                        decoration: const InputDecoration(
                                          labelText: 'First name',
                                        ),
                                        validator:
                                            (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? 'Required'
                                                    : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lastName,
                                        decoration: const InputDecoration(
                                          labelText: 'Last name',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                      const SizedBox(height: 12),

                      // Email (display-only)
                      _CardSection(
                        title: 'Email',
                        child: Text(
                          _email,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // City + Age
                      _CardSection(
                        title: 'Details',
                        trailingEdit: !_preview,
                        child:
                            _preview
                                ? _DetailRowPreview(
                                  city: _city.text,
                                  age: _age.text,
                                )
                                : Column(
                                  children: [
                                    TextFormField(
                                      controller: _city,
                                      decoration: const InputDecoration(
                                        labelText: 'City',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _age,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Age',
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                      const SizedBox(height: 24),

                      // Save / Preview buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _preview || _saving ? null : _save,
                              child:
                                  _saving
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('Save'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _saving
                                      ? null
                                      : () =>
                                          setState(() => _preview = !_preview),
                              child: Text(
                                _preview ? 'Back to Edit' : 'Preview',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onEditAvatar() {
    // TODO: wire up image picker & upload
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avatar edit not implemented yet')),
    );
  }
}

/// ======= WIDGETS =======

class _Header extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String email;
  final Color brand;
  final bool preview;
  final VoidCallback onTogglePreview;
  final VoidCallback onEditAvatar;

  const _Header({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.brand,
    required this.preview,
    required this.onTogglePreview,
    required this.onEditAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final name = [
      firstName.trim(),
      lastName.trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    final displayName = name.isEmpty ? 'Your Name' : name;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Column(
        children: [
          // Top row: back/space + Preview toggle
          Row(
            children: [
              const SizedBox(
                width: 40,
              ), // keep space for symmetry if you later add back button
              const Spacer(),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.black12.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: onTogglePreview,
                child: Text(preview ? 'Back to Edit' : 'Preview'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Avatar + edit badge
          Stack(
            children: [
              CircleAvatar(
                radius: 100,
                backgroundColor: Colors.white.withOpacity(0.6),
                child: const Icon(
                  Icons.person,
                  size: 80,
                  color: Colors.black54,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  onTap: onEditAvatar,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.camera_alt,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Name + email
          Text(
            displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool trailingEdit;

  const _CardSection({
    required this.title,
    required this.child,
    this.trailingEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (trailingEdit)
                Icon(Icons.edit, size: 18, color: cs.primary.withOpacity(0.9)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int likes;
  final int matches;
  final int connections;

  const _StatsRow({
    required this.likes,
    required this.matches,
    required this.connections,
  });

  @override
  Widget build(BuildContext context) {
    final tile =
        (String label, String value) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          tile('Likes', likes.toString()),
          _VLine(),
          tile('Matches', matches.toString()),
          _VLine(),
          tile('Connections', connections.toString()),
        ],
      ),
    );
  }
}

class _VLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: Colors.black12,
  );
}

class _DetailRowPreview extends StatelessWidget {
  final String city;
  final String age;
  const _DetailRowPreview({required this.city, required this.age});

  @override
  Widget build(BuildContext context) {
    final text = <String>[
      if (age.trim().isNotEmpty) age.trim(),
      if (city.trim().isNotEmpty) city.trim(),
    ].join(' • ');
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.isEmpty ? 'No details provided' : text,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
