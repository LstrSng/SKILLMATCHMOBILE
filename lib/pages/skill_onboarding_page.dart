import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/competency.dart';
import '../services/job_roles_data.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/centered_form_width.dart';
import '../widgets/edit_profile_sheet.dart'
    show kDefaultSkillLevel, skillLevelLabel;
import 'main_navigation_page.dart';

bool _hasSkills(Map<String, dynamic>? user) {
  final skills = user?['skills'];
  return skills is List && skills.any((s) => s.toString().trim().isNotEmpty);
}

/// Where a signed-in user lands: the skill picker if they haven't added
/// any skills yet (e.g. right after creating an account), otherwise home.
/// Use this instead of [MainNavigationPage] after sign-up/sign-in.
class SignedInHome extends StatefulWidget {
  const SignedInHome({super.key});

  @override
  State<SignedInHome> createState() => _SignedInHomeState();
}

class _SignedInHomeState extends State<SignedInHome> {
  // Known from the cached session, so returning users skip the network.
  late bool? _needsSkills = _hasSkills(SessionStore.user) ? false : null;

  @override
  void initState() {
    super.initState();
    if (_needsSkills == null) _check();
  }

  Future<void> _check() async {
    try {
      final user = await fetchMyProfile();
      if (mounted) setState(() => _needsSkills = !_hasSkills(user));
    } catch (_) {
      // Offline or server error: don't lock the user out of the app.
      if (mounted) setState(() => _needsSkills = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_needsSkills) {
      null => Scaffold(
        backgroundColor: context.appColors.scaffoldBackground,
        body: const Center(child: CircularProgressIndicator()),
      ),
      true => SkillOnboardingPage(
        onDone: () => setState(() => _needsSkills = false),
      ),
      false => const MainNavigationPage(),
    };
  }
}

/// Color for a 1–10 level: orange (beginner) → blue → indigo → green (expert).
Color _levelColor(int level) {
  if (level <= 3) return AppColors.warning;
  if (level <= 6) return AppColors.info;
  if (level <= 8) return AppColors.verified;
  return AppColors.success;
}

/// Asks a new user to pick their skills and rate each one from 1 to 10.
class SkillOnboardingPage extends StatefulWidget {
  const SkillOnboardingPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SkillOnboardingPage> createState() => _SkillOnboardingPageState();
}

class _SkillOnboardingPageState extends State<SkillOnboardingPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<String> _skillOptions = [];
  final List<String> _skills = [];
  final Map<String, int> _levels = {};
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSkillOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSkillOptions() async {
    try {
      final options = await loadSkillOptions();
      if (mounted) setState(() => _skillOptions = options);
    } catch (_) {
      // Users can still type their own skills.
    }
  }

  void _addSkill(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      final exists = _skills.any(
        (s) => s.toLowerCase() == trimmed.toLowerCase(),
      );
      if (!exists) {
        _skills.insert(0, trimmed);
        _levels[trimmed] = kDefaultSkillLevel;
      }
      _searchController.clear();
      _query = '';
    });
  }

  void _removeSkill(String skill) {
    HapticFeedback.lightImpact();
    setState(() {
      _skills.remove(skill);
      _levels.remove(skill);
    });
  }

  void _setLevel(String skill, int level) {
    if (_levels[skill] == level) return;
    HapticFeedback.selectionClick();
    setState(() => _levels[skill] = level);
  }

  Future<void> _save() async {
    if (_skills.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await updateMyProfile({
        'skills': _skills,
        'skillLevels': {
          for (final skill in _skills)
            skill: _levels[skill] ?? kDefaultSkillLevel,
        },
      });
      if (!mounted) return;
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: tokens.scaffoldBackground,
        body: Column(
          children: [
            _Header(
              firstName: (SessionStore.user?['firstName'] ?? '')
                  .toString()
                  .trim(),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _searchFocus.unfocus(),
                behavior: HitTestBehavior.translucent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    CenteredFormWidth(child: _buildSearch(tokens)),
                    const SizedBox(height: 20),
                    CenteredFormWidth(child: _buildSelected(tokens)),
                  ],
                ),
              ),
            ),
            _buildBottomBar(tokens),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(AppThemeExtension tokens) {
    final query = _query.trim();
    final lower = query.toLowerCase();
    final matches = lower.isEmpty
        ? const <String>[]
        : _skillOptions
              .where((o) => !_skills.contains(o))
              .where((o) => o.toLowerCase().contains(lower))
              .take(6)
              .toList();
    final hasExact =
        _skillOptions.any((o) => o.toLowerCase() == lower) ||
        _skills.any((s) => s.toLowerCase() == lower);

    return Container(
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchFocus.hasFocus ? tokens.primary : tokens.cardBorderSoft,
          width: _searchFocus.hasFocus ? 1.5 : 1,
        ),
        boxShadow: tokens.cardShadows,
      ),
      child: Column(
        children: [
          Focus(
            onFocusChange: (_) => setState(() {}),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.done,
              style: TextStyle(color: tokens.textPrimary, fontSize: 15),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (v) {
                if (matches.isNotEmpty &&
                    matches.first.toLowerCase() == v.trim().toLowerCase()) {
                  _addSkill(matches.first);
                } else {
                  _addSkill(v);
                }
                _searchFocus.requestFocus();
              },
              decoration: InputDecoration(
                hintText: 'Search skills, e.g. Python, Figma, SQL',
                hintStyle: TextStyle(color: tokens.textFaint, fontSize: 15),
                prefixIcon: Icon(Icons.search_rounded, color: tokens.primary),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: Icon(
                          Icons.close_rounded,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _query = '';
                        }),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (query.isNotEmpty) ...[
            Divider(height: 1, color: tokens.cardBorderSoft),
            ...matches.map(
              (m) => _SuggestionRow(
                label: m,
                query: lower,
                onTap: () => _addSkill(m),
              ),
            ),
            if (!hasExact)
              _SuggestionRow(
                label: 'Add "$query" as a new skill',
                icon: Icons.add_circle_outline_rounded,
                highlight: true,
                onTap: () => _addSkill(query),
              ),
            if (matches.isEmpty && hasExact)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Already added',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelected(AppThemeExtension tokens) {
    if (_skills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: tokens.primarySoftBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: tokens.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No skills added yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search above and tap a skill to add it.\nThen rate how good you are from 1 to 10.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: tokens.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Your skills',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_skills.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Tap the bars to rate',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._skills.map(
          (s) => _SkillCard(
            key: ValueKey(s),
            skill: s,
            level: _levels[s] ?? kDefaultSkillLevel,
            onLevel: (v) => _setLevel(s, v),
            onRemove: () => _removeSkill(s),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(AppThemeExtension tokens) {
    final count = _skills.length;
    return Container(
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        border: Border(top: BorderSide(color: tokens.cardBorderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: CenteredFormWidth(
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary,
                  disabledBackgroundColor: tokens.surfaceMuted,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: count == 0 || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              count == 0
                                  ? 'Add at least 1 skill'
                                  : 'Continue with $count skill${count == 1 ? '' : 's'}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: count == 0
                                    ? tokens.textFaint
                                    : Colors.white,
                              ),
                            ),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
          child: CenteredFormWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'LAST STEP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  firstName.isEmpty ? 'Welcome!' : 'Welcome, $firstName! 👋',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'What are your skills?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add the skills you have and rate each one. We use them to find jobs that fit you.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.label,
    required this.onTap,
    this.query = '',
    this.icon = Icons.add_rounded,
    this.highlight = false,
  });

  final String label;
  final String query;
  final IconData icon;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final base = TextStyle(
      fontSize: 14.5,
      color: highlight ? tokens.primary : tokens.textPrimary,
      fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
    );

    // Bold the part of the label that matches what was typed.
    final start = query.isEmpty ? -1 : label.toLowerCase().indexOf(query);
    final text = start < 0
        ? TextSpan(text: label, style: base)
        : TextSpan(
            style: base,
            children: [
              TextSpan(text: label.substring(0, start)),
              TextSpan(
                text: label.substring(start, start + query.length),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: label.substring(start + query.length)),
            ],
          );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tokens.primary),
            const SizedBox(width: 12),
            Expanded(child: Text.rich(text)),
          ],
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    super.key,
    required this.skill,
    required this.level,
    required this.onLevel,
    required this.onRemove,
  });

  final String skill;
  final int level;
  final ValueChanged<int> onLevel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final color = _levelColor(level);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.cardBorderSoft),
        boxShadow: tokens.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Text(
                  '$level',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${datasetLevelLabel(skill, level) ?? skillLevelLabel(level)} · $level/10',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove $skill',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: tokens.textFaint,
                ),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _LevelMeter(level: level, color: color, onChanged: onLevel),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Beginner',
                  style: TextStyle(fontSize: 11, color: tokens.textFaint),
                ),
                Text(
                  'Expert',
                  style: TextStyle(fontSize: 11, color: tokens.textFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ten tappable/draggable bars; bars up to [level] are filled with [color].
class _LevelMeter extends StatelessWidget {
  const _LevelMeter({
    required this.level,
    required this.color,
    required this.onChanged,
  });

  final int level;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Semantics(
      label: 'Skill level',
      value: '$level out of 10',
      increasedValue: '${(level + 1).clamp(1, 10)} out of 10',
      decreasedValue: '${(level - 1).clamp(1, 10)} out of 10',
      onIncrease: () => onChanged((level + 1).clamp(1, 10)),
      onDecrease: () => onChanged((level - 1).clamp(1, 10)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          void pick(double dx) {
            final i = (dx / constraints.maxWidth * 10).floor() + 1;
            onChanged(i.clamp(1, 10));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => pick(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
            child: SizedBox(
              height: 28,
              child: Row(
                children: List.generate(10, (i) {
                  final filled = i < level;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(right: i == 9 ? 0 : 4),
                      height: filled ? 28 : 20,
                      decoration: BoxDecoration(
                        color: filled ? color : tokens.surfaceMuted,
                        borderRadius: BorderRadius.circular(6),
                        border: filled
                            ? null
                            : Border.all(color: tokens.cardBorderSoft),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}
