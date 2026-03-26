import 'package:flutter/material.dart';
import '../services/household_service.dart';

/// Household tab — replaces the Notifications stub.
///
/// Two states:
/// 1. No household: create one or view/accept pending invites
/// 2. In a household: members list, invite flow, house rules with voting
class HouseholdPage extends StatefulWidget {
  const HouseholdPage({super.key});

  @override
  State<HouseholdPage> createState() => HouseholdPageState();
}

class HouseholdPageState extends State<HouseholdPage>
    with TickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic>? _household;
  List<dynamic> _receivedInvites = [];
  List<dynamic> _eligible = [];
  Set<int> _sentInviteUserIds = {};
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> refreshHousehold() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await HouseholdService.getMyHousehold();
      final invites = await HouseholdService.getInvites();
      if (!mounted) return;
      final sent = invites['sent'] as List<dynamic>? ?? [];
      setState(() {
        _household = data['household'] as Map<String, dynamic>?;
        _receivedInvites = invites['received'] as List<dynamic>? ?? [];
        _sentInviteUserIds = sent
            .map((s) => ((s as Map)['invitee'] as Map?)?['id'] as int?)
            .whereType<int>()
            .toSet();
        _loading = false;
      });
      // Load eligible only when not in a household or household has room
      if (_household == null || (_household!['members'] as List).length < 4) {
        final elig = await HouseholdService.getEligibleConnections();
        if (mounted) setState(() => _eligible = elig['eligible'] as List<dynamic>? ?? []);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Whether user has pending actions (powers badge dot in HomeShell).
  /// True if there are pending invites OR proposed rules the user hasn't voted on.
  bool get hasPendingActions {
    if (_receivedInvites.isNotEmpty) return true;
    final rules = (_household?['rules'] as List<dynamic>?) ?? [];
    return rules.any((r) {
      final m = r as Map<String, dynamic>;
      return m['status'] == 'proposed' && m['my_vote'] == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_household != null) {
      return _buildInHousehold(brand, brandLight);
    }
    return _buildNoHousehold(brand, brandLight);
  }

  // ── No Household State ──────────────────────────────────────

  Widget _buildNoHousehold(Color brand, Color brandLight) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Household'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Text(
              'Form a Household',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: brand,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Team up with people you\'ve connected with through Quick Picks.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add_home),
                label: const Text('Create Household'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pending invites
            if (_receivedInvites.isNotEmpty) ...[
              Text(
                'Pending Invites',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: brand,
                ),
              ),
              const SizedBox(height: 8),
              ..._receivedInvites.map((inv) => _buildInviteCard(
                inv as Map<String, dynamic>,
                brand,
                brandLight,
              )),
              const SizedBox(height: 24),
            ],

            // Eligible connections
            if (_eligible.isNotEmpty) ...[
              Text(
                'Eligible Connections',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: brand,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'People you\'ve completed Quick Picks with',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              ..._eligible.map((u) => _buildEligibleCard(
                u as Map<String, dynamic>,
                brand,
                brandLight,
              )),
            ],

            if (_eligible.isEmpty && _receivedInvites.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(Icons.group_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      'Complete Quick Picks with matches to unlock household invites.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> inv, Color brand, Color brandLight) {
    final inviter = inv['inviter'] as Map<String, dynamic>? ?? {};
    final name = inviter['name'] ?? 'Someone';
    final householdName = inv['household_name'] ?? 'a household';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brandLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brandLight.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: brandLight.withValues(alpha: 0.3),
            backgroundImage: inviter['avatar_url'] != null
                ? NetworkImage(inviter['avatar_url'] as String)
                : null,
            child: inviter['avatar_url'] == null
                ? Icon(Icons.person, color: brand, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name invited you',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  'to "$householdName"',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () => _acceptInvite(inv['id'] as int),
          ),
          IconButton(
            icon: Icon(Icons.cancel, color: Colors.grey[400]),
            onPressed: () => _declineInvite(inv['id'] as int),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibleCard(Map<String, dynamic> u, Color brand, Color brandLight) {
    final name = u['name'] ?? 'Unknown';
    final labels = (u['vibe_labels'] as List<dynamic>?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: brandLight.withValues(alpha: 0.3),
            backgroundImage: u['avatar_url'] != null
                ? NetworkImage(u['avatar_url'] as String)
                : null,
            child: u['avatar_url'] == null
                ? Icon(Icons.person, color: brand, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (labels.isNotEmpty)
                  Text(
                    labels.take(2).join(', '),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── In Household State ──────────────────────────────────────

  Widget _buildInHousehold(Color brand, Color brandLight) {
    final name = _household!['name'] as String? ?? 'Household';
    final members = (_household!['members'] as List<dynamic>?) ?? [];
    final rules = (_household!['rules'] as List<dynamic>?) ?? [];
    final householdId = _household!['id'] as int;

    // Split rules by status
    final accepted = rules.where((r) => (r as Map)['status'] == 'accepted').toList();
    final proposed = rules.where((r) {
      final s = (r as Map)['status'];
      return s == 'proposed' || s == 'removal_proposed';
    }).toList();
    final rejected = rules.where((r) => (r as Map)['status'] == 'rejected').toList();

    return Scaffold(
        appBar: AppBar(
          title: Text(name),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: brand,
            labelColor: brand,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Members'),
              Tab(text: 'House Rules'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Members tab
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...members.map((m) => _buildMemberCard(
                    m as Map<String, dynamic>,
                    brand,
                    brandLight,
                  )),
                  if (members.length < 4) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Invite Someone',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: brand,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_eligible.isNotEmpty)
                      ..._eligible.map((u) => _buildInvitableCard(
                        u as Map<String, dynamic>,
                        brand,
                        brandLight,
                      ))
                    else
                      Text(
                        'No eligible connections yet. Complete Quick Picks with matches to invite them.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                  ],
                  const SizedBox(height: 32),
                  Center(
                    child: TextButton.icon(
                      onPressed: _confirmLeave,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Leave Household'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
                    ),
                  ),
                ],
              ),
            ),
            // House Rules tab
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (accepted.isNotEmpty) ...[
                    _sectionHeader('Accepted', Colors.green),
                    const SizedBox(height: 6),
                    ...accepted.map((r) => _buildRuleCard(
                      r as Map<String, dynamic>,
                      brand,
                      brandLight,
                      householdId,
                    )),
                    const SizedBox(height: 16),
                  ],
                  if (proposed.isNotEmpty) ...[
                    _sectionHeader('Up for Vote', Colors.orange),
                    const SizedBox(height: 6),
                    ...proposed.map((r) => _buildRuleCard(
                      r as Map<String, dynamic>,
                      brand,
                      brandLight,
                      householdId,
                    )),
                    const SizedBox(height: 16),
                  ],
                  if (rejected.isNotEmpty) ...[
                    _sectionHeader('Rejected', Colors.grey),
                    const SizedBox(height: 6),
                    ...rejected.map((r) => _buildRuleCard(
                      r as Map<String, dynamic>,
                      brand,
                      brandLight,
                      householdId,
                    )),
                    const SizedBox(height: 16),
                  ],
                  if (rules.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        children: [
                          Icon(Icons.gavel, size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            members.length < 2
                                ? 'Invite someone to start proposing house rules.'
                                : 'No house rules yet.\nPropose one to get started!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  if (members.length >= 2) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showProposeRuleDialog(householdId),
                        icon: const Icon(Icons.add),
                        label: const Text('Propose a Rule'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> m, Color brand, Color brandLight) {
    final name = m['name'] ?? 'Unknown';
    final role = m['role'] as String? ?? 'member';
    final labels = (m['vibe_labels'] as List<dynamic>?)?.cast<String>() ?? [];
    final city = m['city'] ?? '';
    final state = m['state'] ?? '';
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brandLight.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: brandLight.withValues(alpha: 0.3),
            backgroundImage: m['avatar_url'] != null
                ? NetworkImage(m['avatar_url'] as String)
                : null,
            child: m['avatar_url'] == null
                ? Icon(Icons.person, color: brand, size: 24)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (role == 'creator') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: brandLight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Creator',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: brand),
                        ),
                      ),
                    ],
                  ],
                ),
                if (location.isNotEmpty)
                  Text(location, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                if (labels.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      children: labels.take(3).map((l) => Chip(
                        label: Text(l, style: const TextStyle(fontSize: 10)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        backgroundColor: brandLight.withValues(alpha: 0.15),
                        side: BorderSide.none,
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitableCard(Map<String, dynamic> u, Color brand, Color brandLight) {
    final name = u['name'] ?? 'Unknown';
    final userId = u['id'] as int;
    final isPending = _sentInviteUserIds.contains(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: brandLight.withValues(alpha: 0.3),
            backgroundImage: u['avatar_url'] != null
                ? NetworkImage(u['avatar_url'] as String)
                : null,
            child: u['avatar_url'] == null
                ? Icon(Icons.person, color: brand, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          isPending
              ? Text('Pending', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600, fontSize: 14))
              : TextButton(
                  onPressed: () => _inviteUser(userId, name),
                  child: Text('Invite', style: TextStyle(color: brand, fontWeight: FontWeight.w600)),
                ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(
    Map<String, dynamic> r,
    Color brand,
    Color brandLight,
    int householdId,
  ) {
    final text = r['text'] as String? ?? '';
    final status = r['status'] as String? ?? 'proposed';
    final yesVotes = r['yes_votes'] as int? ?? 0;
    final noVotes = r['no_votes'] as int? ?? 0;
    final myVote = r['my_vote'] as bool?;
    final ruleId = r['id'] as int;

    Color statusColor;
    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              if (status == 'removal_proposed')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Removal vote',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red[400]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (status == 'proposed' || status == 'removal_proposed') ...[
                Icon(Icons.thumb_up_alt_outlined, size: 14, color: Colors.green[400]),
                const SizedBox(width: 4),
                Text('$yesVotes', style: TextStyle(fontSize: 12, color: Colors.green[400])),
                const SizedBox(width: 12),
                Icon(Icons.thumb_down_alt_outlined, size: 14, color: Colors.red[300]),
                const SizedBox(width: 4),
                Text('$noVotes', style: TextStyle(fontSize: 12, color: Colors.red[300])),
              ],
              const Spacer(),
              if (status == 'proposed' || status == 'removal_proposed') ...[
                _voteButton(
                  icon: Icons.thumb_up,
                  isActive: myVote == true,
                  color: Colors.green,
                  onTap: () => _vote(ruleId, true),
                ),
                const SizedBox(width: 8),
                _voteButton(
                  icon: Icons.thumb_down,
                  isActive: myVote == false,
                  color: Colors.red,
                  onTap: () => _vote(ruleId, false),
                ),
              ],
              if (status == 'accepted')
                TextButton.icon(
                  onPressed: () => _proposeRemoval(ruleId),
                  icon: Icon(Icons.remove_circle_outline, size: 16, color: Colors.red[300]),
                  label: Text('Propose Removal', style: TextStyle(fontSize: 12, color: Colors.red[300])),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _voteButton({
    required IconData icon,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : Colors.grey[300]!,
          ),
        ),
        child: Icon(icon, size: 18, color: isActive ? color : Colors.grey[400]),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────

  void _showCreateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name Your Household'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. "Our Place"'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await HouseholdService.createHousehold(name);
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showProposeRuleDialog(int householdId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Propose a Rule'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. "Quiet hours after 11pm"'),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await HouseholdService.proposeRule(householdId, text);
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            child: const Text('Propose'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptInvite(int inviteId) async {
    try {
      await HouseholdService.acceptInvite(inviteId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _declineInvite(int inviteId) async {
    try {
      await HouseholdService.declineInvite(inviteId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _inviteUser(int userId, String name) async {
    try {
      await HouseholdService.inviteUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite sent to $name')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _vote(int ruleId, bool vote) async {
    try {
      await HouseholdService.voteOnRule(ruleId, vote);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _proposeRemoval(int ruleId) async {
    try {
      await HouseholdService.proposeRemoval(ruleId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _confirmLeave() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Household?'),
        content: const Text('You\'ll need a new invite to rejoin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await HouseholdService.leaveHousehold();
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
