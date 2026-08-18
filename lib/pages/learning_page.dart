import 'package:flutter/material.dart';

import '../models/job_role_skills.dart';
import '../models/training_pathway.dart';
import '../services/job_roles_data.dart';
import '../services/pathway_links_data.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_toast.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/training_pathway_card.dart';
import 'settings_page.dart';

const _kBlue = Color(0xFF2563EB);
const _kGray = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

/// Skill-gap view for a target role: how many of the role's required
/// skills the signed-in user already has, which ones are missing, and
/// verified resources to learn them. Reachable from the Pathway tab's
/// "View skill gap analysis" link.
class LearningPage extends StatefulWidget {
  const LearningPage({super.key, this.initialRoleTitle});

  final String? initialRoleTitle;

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  bool _loading = true;
  String? _error;
  List<JobRoleSkills> _roles = [];
  JobRoleSkills? _selected;
  Set<String> _mySkillKeys = {};
  TrainingPathway? _trainingPathway;
  bool _addingSkill = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Set<String> _readMySkills() {
    final v = SessionStore.user?['skills'];
    if (v is List) {
      return v
          .map((e) => e.toString().trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();
    }
    return {};
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roles = await loadJobRoles();
      if (!mounted) return;
      JobRoleSkills? initial;
      final wanted = widget.initialRoleTitle?.trim().toLowerCase();
      if (wanted != null && wanted.isNotEmpty) {
        for (final r in roles) {
          if (r.title.toLowerCase() == wanted) {
            initial = r;
            break;
          }
        }
      }
      if (initial == null) {
        for (final r in roles) {
          if (r.title.toLowerCase() == 'full stack developer') {
            initial = r;
            break;
          }
        }
      }
      initial ??= roles.isNotEmpty ? roles.first : null;
      setState(() {
        _roles = roles;
        _selected = initial;
        _mySkillKeys = _readMySkills();
        _loading = false;
      });
      _loadTrainingPathway(initial?.title);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadTrainingPathway(String? roleTitle) async {
    if (roleTitle == null) {
      setState(() => _trainingPathway = null);
      return;
    }
    final pathway = await trainingPathwayForRole(roleTitle);
    if (!mounted) return;
    setState(() => _trainingPathway = pathway);
  }

  Future<void> _pickRole() async {
    final picked = await showModalBottomSheet<JobRoleSkills>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _RolePickerSheet(roles: _roles, initial: _selected),
    );
    if (picked != null && mounted) {
      setState(() => _selected = picked);
      _loadTrainingPathway(picked.title);
    }
  }

  Future<void> _addSkillToProfile(String skill) async {
    if (SessionStore.user == null || _addingSkill) return;
    final rawSkills = SessionStore.user?['skills'];
    final current = rawSkills is List
        ? rawSkills.map((e) => e.toString()).toList()
        : <String>[];
    if (current.any((s) => s.trim().toLowerCase() == skill.toLowerCase())) {
      return;
    }
    current.add(skill);
    setState(() => _addingSkill = true);
    try {
      await updateMyProfile({'skills': current});
      if (!mounted) return;
      setState(() {
        _mySkillKeys = _readMySkills();
      });
      showAppToast(
        context,
        'Added "$skill" to your profile skills.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'Could not update profile: $e',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _addingSkill = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'SkillMatch',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          const NotificationBellButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _selected == null
          ? const Center(child: Text('No skill gap data available yet.'))
          : _buildContent(context, _selected!),
    );
  }

  Widget _buildContent(BuildContext context, JobRoleSkills role) {
    final mastered = role.skills
        .where((s) => _mySkillKeys.contains(s.toLowerCase()))
        .toList();
    final missing = role.skills
        .where((s) => !_mySkillKeys.contains(s.toLowerCase()))
        .toList();
    final total = role.skills.length;
    final coverage = total == 0 ? 0.0 : mastered.length / total;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skill Gap Analysis',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Compare your skills against a target role',
            style: TextStyle(fontSize: 16, color: _kGray),
          ),
          const SizedBox(height: 20),

          // Role selector
          AppCard(
            onTap: _pickRole,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.show_chart, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target role',
                        style: TextStyle(fontSize: 12, color: _kGray),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.unfold_more, color: _kGray),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Coverage / market alignment
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Skill Coverage',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${mastered.length}/$total skills',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Skills you have vs. what this role requires',
                  style: TextStyle(fontSize: 14, color: _kGray),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: coverage,
                    minHeight: 8,
                    backgroundColor: _kBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(_kBlue),
                  ),
                ),
                if (mastered.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: mastered
                        .map((s) => _SkillChip(skill: s, matched: true))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Priority gaps
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Priority Gaps',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Skills this role needs that aren\'t on your profile yet',
                  style: TextStyle(fontSize: 14, color: _kGray),
                ),
                const SizedBox(height: 16),
                if (missing.isEmpty)
                  const Text(
                    'You already have every skill listed for this role. Nice work!',
                    style: TextStyle(fontSize: 14, color: _kGray),
                  )
                else
                  ...missing.map(
                    (skill) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              skill,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _addingSkill
                                ? null
                                : () => _addSkillToProfile(skill),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'I have this',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _kBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_trainingPathway != null && _trainingPathway!.links.isNotEmpty)
            TrainingPathwayCard(
              pathway: _trainingPathway!,
              subtitle: 'Curated resources to close your gaps for ${role.title}',
            )
          else
            const AppCard(
              child: Text(
                'No curated learning resources are available for this role yet.',
                style: TextStyle(fontSize: 14, color: _kGray),
              ),
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String skill;
  final bool matched;

  const _SkillChip({required this.skill, required this.matched});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: matched ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        border: Border.all(
          color: matched ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: matched ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            skill,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: matched ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePickerSheet extends StatefulWidget {
  final List<JobRoleSkills> roles;
  final JobRoleSkills? initial;

  const _RolePickerSheet({required this.roles, required this.initial});

  @override
  State<_RolePickerSheet> createState() => _RolePickerSheetState();
}

class _RolePickerSheetState extends State<_RolePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.roles
        : widget.roles.where((r) => r.title.toLowerCase().contains(q)).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a target role',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search roles (e.g. Full Stack Developer)',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No matching roles.'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: _kBorder),
                        itemBuilder: (context, index) {
                          final r = filtered[index];
                          final selected = widget.initial?.title == r.title;
                          return ListTile(
                            title: Text(
                              r.title,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected ? _kBlue : Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              '${r.skills.length} skills',
                              style: const TextStyle(fontSize: 12, color: _kGray),
                            ),
                            trailing: selected
                                ? const Icon(Icons.check_circle, color: _kBlue)
                                : null,
                            onTap: () => Navigator.pop(context, r),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
