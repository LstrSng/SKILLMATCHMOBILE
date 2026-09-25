import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/training_pathway.dart';
import '../services/competency.dart';
import '../services/completed_certs.dart';
import '../services/jobs_api.dart';
import '../services/pathway_links_data.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';
import '../services/skill_gap_data.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/page_hero_header.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/training_pathway_card.dart';

final _kLevelRegex = RegExp(r'\blevel\s*\d+\b', caseSensitive: false);
final _kTokenRegex = RegExp(r'[^a-zA-Z0-9#+]');

const Map<String, List<String>> _kSkillSearchAliases = {
  'ts': ['typescript'],
  'typescript': ['typescript', 'ts'],
  'js': ['javascript'],
  'javascript': ['javascript', 'js'],
  'py': ['python'],
  'reactjs': ['react'],
  'nextjs': ['next.js', 'next'],
  'next.js': ['nextjs', 'next'],
  'vuejs': ['vue'],
  'nodejs': ['node.js', 'node'],
  'k8s': ['kubernetes'],
  'golang': ['go'],
  'postgres': ['postgresql'],
  'postgresql': ['postgres'],
  'mongo': ['mongodb'],
  'mongodb': ['mongo'],
  'ci/cd': ['ci/cd', 'pipeline'],
};

class PathwayPage extends StatefulWidget {
  const PathwayPage({super.key, this.initialQuery, this.initialCategory});

  final String? initialQuery;
  final String? initialCategory;

  @override
  State<PathwayPage> createState() => _PathwayPageState();
}

class _PathwayPageState extends State<PathwayPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _debouncedQuery = '';
  bool _loading = true;
  String? _error;
  List<TrainingPathway> _pathways = [];
  late String _selectedCategory = widget.initialCategory ?? 'All';
  Set<String> _completedKeys = completedCertificationKeys();
  Set<String> _completedPathways = completedPathwayKeys();

  /// Skills the user is missing across posted jobs, with the pathways
  /// whose certifications cover each one.
  List<({SkillGap gap, List<TrainingPathway> pathways})> _gapMatches = [];

  /// Gap chip the user tapped; filters the list to its certifications.
  String? _selectedGap;

  /// Gaps that still need a certification: ones with a completed
  /// certification in any of their pathways drop off the list.
  List<({SkillGap gap, List<TrainingPathway> pathways})> get _openGaps =>
      _gapMatches
          .where(
            (m) => !m.pathways.any(
              (p) =>
                  _completedPathways.contains(p.name.toLowerCase()) ||
                  p.links.any(
                    (l) => isCertificationCompleted(l, _completedKeys),
                  ),
            ),
          )
          .toList();

  /// Pathway name -> the skill gaps its certifications cover, e.g.
  /// "Figma" or, when the user has the skill below the required level,
  /// "Figma — You: Beginner (Level 2) · needs Level 3".
  Map<String, List<String>> get _gapSkillsByPathway {
    final out = <String, List<String>>{};
    final seenByPathway = <String, Set<String>>{};
    for (final m in _openGaps) {
      final gap = m.gap;
      final required = gap.required;
      final rating = gap.rating;
      final label = gap.isLevelGap && required != null && rating != null
          ? '${gap.skill} — You: ${skillLevelLabel(rating)} '
                '(${required.labelForRating(rating)}) · needs ${required.label}'
          : gap.skill;
      final key = _skillKey(gap.skill);
      for (final p in m.pathways) {
        final seen = seenByPathway.putIfAbsent(p.name, () => {});
        // The dataset spells some skills two ways ("Sensibility" /
        // "Sensibilities"); list each only once.
        if (seen.add(key)) out.putIfAbsent(p.name, () => []).add(label);
      }
    }
    return out;
  }

  /// Normalizes a skill name so spelling variants compare equal:
  /// "User Interface (UI) Design" and "User Interface Design", or
  /// "Specification" and "Specifications".
  static String _skillKey(String skill) => skill
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w.replaceFirst(RegExp(r'(ies|y|s)$'), ''))
      .join(' ');

  Future<void> _loadGaps() async {
    try {
      final gaps = await loadSkillGapsFromPostedJobs();
      final pathways = await allTrainingPathways();
      final matches = [
        for (final gap in gaps)
          (gap: gap, pathways: pathwaysForSkill(pathways, gap.skill)),
      ].where((m) => m.pathways.isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        _gapMatches = matches;
        // The selected gap may be closed now that the user has the skill.
        if (!matches.any((m) => m.gap.skill == _selectedGap)) {
          _selectedGap = null;
        }
      });
    } catch (_) {
      // No jobs or offline: the section just stays hidden.
    }
  }

  /// Whether the user completed [pathway] or any certification in it.
  bool _isCompleted(TrainingPathway pathway) =>
      _completedPathways.contains(pathway.name.toLowerCase()) ||
      pathway.links.any((l) => isCertificationCompleted(l, _completedKeys));

  Future<void> _togglePathwayCompleted(
    TrainingPathway pathway,
    bool completed,
  ) async {
    HapticFeedback.selectionClick();
    final previous = _completedPathways;
    final key = pathway.name.toLowerCase();
    setState(() {
      _completedPathways = {..._completedPathways};
      completed ? _completedPathways.add(key) : _completedPathways.remove(key);
    });
    try {
      final keys = await setPathwayCompleted(
        name: pathway.name,
        completed: completed,
      );
      if (!mounted) return;
      setState(() => _completedPathways = keys);
      showAppToast(
        context,
        completed
            ? 'Marked "${pathway.name}" as completed.'
            : 'Removed completed mark.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _completedPathways = previous);
      showAppToast(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _toggleCompleted(
    TrainingPathway pathway,
    TrainingResource link,
    bool completed,
  ) async {
    HapticFeedback.selectionClick();
    final previous = _completedKeys;
    final key = link.label.trim().toLowerCase();
    setState(() {
      _completedKeys = {..._completedKeys};
      completed ? _completedKeys.add(key) : _completedKeys.remove(key);
    });
    try {
      final keys = await setCertificationCompleted(
        link: link,
        pathwayName: pathway.name,
        completed: completed,
      );
      if (!mounted) return;
      setState(() => _completedKeys = keys);
      showAppToast(
        context,
        completed
            ? 'Marked "${link.label}" as completed.'
            : 'Removed completed mark.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _completedKeys = previous);
      showAppToast(context, e.toString(), type: AppToastType.error);
    }
  }

  static const _categories = [
    'All',
    'My Skill Gaps',
    'Completed',
    'TESDA Registered',
    'Free Certs',
    'Mobile',
    'Web',
    'Data & AI',
    'Cloud',
    'Cybersecurity',
    'DevOps',
    'Design',
    'Game Dev',
    'IT & Support',
    'Management',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _debouncedQuery = widget.initialQuery!.trim().toLowerCase();
    }

    _load();
    _loadGaps();
    SessionStore.skillsChanged.addListener(_loadGaps);
    completionsChanged.addListener(_syncCompleted);
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _debouncedQuery = v.trim().toLowerCase());
    });
  }

  /// Re-reads completed pathways/certifications from the saved profile.
  void _syncCompleted() {
    if (!mounted) return;
    setState(() {
      _completedKeys = completedCertificationKeys();
      _completedPathways = completedPathwayKeys();
    });
  }

  /// Pull-to-refresh: reloads the profile (completions), posted jobs (skill
  /// gaps) and pathways without replacing the page with a spinner.
  Future<void> _refresh() async {
    await Future.wait([
      fetchMyProfile().then((_) {}, onError: (_) {}),
      fetchJobsRaw().then((_) {}, onError: (_) {}),
    ]);
    if (!mounted) return;
    _syncCompleted();
    await _loadGaps();
    try {
      final pathways = await allTrainingPathways();
      if (mounted) setState(() => _pathways = pathways);
    } catch (_) {
      // Keep the pathways already shown.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pathways = await allTrainingPathways();
      if (!mounted) return;
      setState(() {
        _pathways = pathways;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    SessionStore.skillsChanged.removeListener(_loadGaps);
    completionsChanged.removeListener(_syncCompleted);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(),
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
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final qLower = _debouncedQuery.trim().toLowerCase();
    final isAllCat = _selectedCategory == 'All';
    final cat = _selectedCategory.toLowerCase();

    final searchTerms = <String>{};
    if (qLower.isNotEmpty) {
      final rawTerms = qLower
          .replaceAll(_kLevelRegex, '')
          .split(_kTokenRegex)
          .where(
            (t) =>
                t.length >= 3 ||
                {
                  'ts',
                  'js',
                  'ui',
                  'ux',
                  'qa',
                  'ci',
                  'cd',
                  'ai',
                  'go',
                  'db',
                  'c#',
                }.contains(t),
          )
          .toList();

      searchTerms.addAll(rawTerms);
      if (_kSkillSearchAliases.containsKey(qLower)) {
        searchTerms.addAll(_kSkillSearchAliases[qLower]!);
      }
      for (final t in rawTerms) {
        if (_kSkillSearchAliases.containsKey(t)) {
          searchTerms.addAll(_kSkillSearchAliases[t]!);
        }
      }
    }

    bool matchesTerm(String text, String term) {
      final lower = text.toLowerCase();
      if (term.length <= 2) {
        return RegExp(
          r'\b' + RegExp.escape(term) + r'\b',
          caseSensitive: false,
        ).hasMatch(lower);
      }
      return lower.contains(term);
    }

    bool matchesPathway(TrainingPathway pathway, String term) {
      return matchesTerm(pathway.name, term) ||
          pathway.links.any(
            (l) =>
                matchesTerm(l.label, term) ||
                (l.provider != null && matchesTerm(l.provider!, term)),
          );
    }

    final gapSkillsByPathway = _gapSkillsByPathway;
    final selectedGapPathways = _selectedGap == null
        ? null
        : {
            for (final m in _openGaps)
              if (m.gap.skill == _selectedGap)
                for (final p in m.pathways) p.name,
          };

    final unordered = _pathways.where((p) {
      if (selectedGapPathways != null) {
        if (!selectedGapPathways.contains(p.name)) return false;
      } else if (cat == 'my skill gaps') {
        if (!gapSkillsByPathway.containsKey(p.name)) return false;
      } else if (cat == 'completed') {
        if (!_isCompleted(p)) return false;
      } else if (!isAllCat) {
        final nameLower = p.name.toLowerCase();
        final fieldLower = (p.field ?? '').toLowerCase();
        bool matchesCategory = false;
        if (cat == 'tesda registered') {
          matchesCategory =
              fieldLower == 'tesda' ||
              nameLower.contains('tesda') ||
              p.links.any(
                (l) =>
                    (l.provider?.toLowerCase().contains('tesda') ?? false) ||
                    (l.type?.toLowerCase().contains('tesda') ?? false) ||
                    l.label.toLowerCase().contains('tesda'),
              );
        } else if (cat == 'free certs') {
          matchesCategory = p.links.any((l) => l.isFree);
        } else if (cat == 'mobile') {
          matchesCategory =
              fieldLower == 'mobile' ||
              nameLower.contains('mobile') ||
              nameLower.contains('android') ||
              nameLower.contains('ios') ||
              p.links.any((l) {
                final lbl = l.label.toLowerCase();
                return lbl.contains('android') ||
                    lbl.contains('ios') ||
                    lbl.contains('swift') ||
                    lbl.contains('flutter') ||
                    lbl.contains('mobile');
              });
        } else if (cat == 'web') {
          matchesCategory =
              fieldLower == 'web' ||
              nameLower.contains('web') ||
              nameLower.contains('front-end') ||
              nameLower.contains('back-end') ||
              nameLower.contains('full-stack') ||
              nameLower.contains('javascript') ||
              nameLower.contains('php') ||
              nameLower.contains('wordpress') ||
              nameLower.contains('rails') ||
              p.links.any((l) {
                final lbl = l.label.toLowerCase();
                return lbl.contains('web') ||
                    lbl.contains('html') ||
                    lbl.contains('css') ||
                    lbl.contains('javascript') ||
                    lbl.contains('full stack') ||
                    lbl.contains('front-end') ||
                    lbl.contains('back-end');
              });
        } else if (cat == 'data & ai') {
          matchesCategory =
              fieldLower == 'data & ai' ||
              nameLower.contains('data') ||
              nameLower.contains('machine learning') ||
              nameLower.contains('database') ||
              nameLower.contains('bi') ||
              nameLower.contains('sql');
        } else if (cat == 'cloud') {
          matchesCategory =
              fieldLower == 'cloud' ||
              nameLower.contains('cloud') ||
              nameLower.contains('aws') ||
              nameLower.contains('azure') ||
              nameLower.contains('gcp');
        } else if (cat == 'cybersecurity') {
          matchesCategory =
              fieldLower == 'cybersecurity' ||
              nameLower.contains('cyber') ||
              nameLower.contains('security') ||
              nameLower.contains('penetration');
        } else if (cat == 'devops') {
          matchesCategory =
              fieldLower == 'devops' ||
              nameLower.contains('devops') ||
              nameLower.contains('kubernetes') ||
              nameLower.contains('ci/cd') ||
              nameLower.contains('pipeline') ||
              nameLower.contains('qa') ||
              nameLower.contains('git') ||
              nameLower.contains('automation');
        } else if (cat == 'design') {
          matchesCategory =
              fieldLower == 'design' ||
              nameLower.contains('design') ||
              nameLower.contains('ux') ||
              nameLower.contains('ui') ||
              nameLower.contains('animation') ||
              nameLower.contains('accessibility');
        } else if (cat == 'game dev') {
          matchesCategory =
              fieldLower == 'game dev' ||
              nameLower.contains('game') ||
              nameLower.contains('unity') ||
              nameLower.contains('unreal');
        } else if (cat == 'it & support') {
          matchesCategory =
              fieldLower == 'it & support' ||
              nameLower.contains('it support') ||
              nameLower.contains('help desk') ||
              nameLower.contains('networking') ||
              nameLower.contains('linux') ||
              nameLower.contains('service management');
        } else if (cat == 'management') {
          matchesCategory =
              fieldLower == 'management' ||
              nameLower.contains('management') ||
              nameLower.contains('analysis') ||
              nameLower.contains('leadership') ||
              nameLower.contains('agile');
        } else if (cat == 'other') {
          matchesCategory =
              fieldLower == 'other' ||
              nameLower.contains('salesforce') ||
              nameLower.contains('sap') ||
              nameLower.contains('dynamics') ||
              nameLower.contains('mulesoft') ||
              nameLower.contains('blockchain') ||
              nameLower.contains('embedded') ||
              nameLower.contains('gis') ||
              nameLower.contains('sales');
        } else {
          matchesCategory = fieldLower.contains(cat) || nameLower.contains(cat);
        }
        if (!matchesCategory) return false;
      }
      if (qLower.isEmpty) return true;

      // Direct match on pathway name, link label, or link provider
      if (matchesPathway(p, qLower)) {
        return true;
      }

      if (searchTerms.isNotEmpty) {
        return searchTerms.any((t) => matchesPathway(p, t));
      }
      return false;
    }).toList();
    // Pathways that cover the user's skill gaps come first (order kept).
    final filtered = [
      ...unordered.where((p) => gapSkillsByPathway.containsKey(p.name)),
      ...unordered.where((p) => !gapSkillsByPathway.containsKey(p.name)),
    ];

    final horizontalPadding = MediaQuery.of(context).size.width > 600
        ? 32.0
        : 16.0;
    final tokens = context.appColors;

    // One scroll view for the whole page so the header, search and skill
    // gap chips scroll away with the list instead of staying pinned.
    return RefreshIndicator(
      onRefresh: _refresh,
      color: tokens.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PageHeroHeader(
                        icon: Icons.workspace_premium_rounded,
                        eyebrow: 'Level up',
                        title: 'Certifications & Pathways',
                        subtitle:
                            'Earn certifications that boost your job matches.',
                        highlight: () {
                          final done = _pathways.where(_isCompleted).length;
                          return done == 0
                              ? '${_pathways.length} pathways'
                              : '${_pathways.length} pathways · $done completed';
                        }(),
                      ),
                      const SizedBox(height: 16),

                      // Search field
                      Container(
                        decoration: BoxDecoration(
                          color: tokens.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tokens.cardBorderSoft),
                          boxShadow: tokens.cardShadows,
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14,
                          ),
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText:
                                'Search pathways (e.g. AWS, Cyber, Python)...',
                            hintStyle: TextStyle(
                              color: tokens.textFaint,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: tokens.textSecondary,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      size: 18,
                                      color: tokens.textSecondary,
                                    ),
                                    onPressed: () {
                                      _searchDebounce?.cancel();
                                      _searchController.clear();
                                      setState(() => _debouncedQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final selected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedCategory = cat);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? tokens.primary
                                        : tokens.cardBackground,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected
                                          ? tokens.primary
                                          : tokens.cardBorderSoft,
                                    ),
                                    boxShadow: selected
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x332563EB),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ]
                                        : tokens.cardShadows,
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : tokens.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_openGaps.isNotEmpty && widget.initialQuery == null)
                  _GapSection(
                    gaps: _openGaps.map((m) => m.gap).toList(),
                    selected: _selectedGap,
                    padding: horizontalPadding,
                    onSelect: (skill) {
                      HapticFeedback.selectionClick();
                      setState(
                        () =>
                            _selectedGap = _selectedGap == skill ? null : skill,
                      );
                    },
                  ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 36,
                        color: tokens.textFaint,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        cat == 'completed' && qLower.isEmpty
                            ? 'Nothing completed yet. Tap "Complete" on a pathway or certification to see it here.'
                            : 'No matching certification pathways found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                4,
                horizontalPadding,
                80,
              ),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) => _PathwayTile(
                  key: ValueKey(filtered[i].name),
                  pathway: filtered[i],
                  gapSkills: gapSkillsByPathway[filtered[i].name] ?? const [],
                  completedKeys: _completedKeys,
                  pathwayCompleted: _completedPathways.contains(
                    filtered[i].name.toLowerCase(),
                  ),
                  onTogglePathway: (done) =>
                      _togglePathwayCompleted(filtered[i], done),
                  onToggleCompleted: (link, done) =>
                      _toggleCompleted(filtered[i], link, done),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PathwayTile extends StatefulWidget {
  final TrainingPathway pathway;

  /// Missing skills (from posted jobs) this pathway's certifications cover.
  final List<String> gapSkills;
  final Set<String> completedKeys;

  /// Whether the user marked this whole pathway as completed.
  final bool pathwayCompleted;
  final ValueChanged<bool> onTogglePathway;
  final void Function(TrainingResource link, bool completed) onToggleCompleted;

  const _PathwayTile({
    super.key,
    required this.pathway,
    this.gapSkills = const [],
    required this.completedKeys,
    this.pathwayCompleted = false,
    required this.onTogglePathway,
    required this.onToggleCompleted,
  });

  @override
  State<_PathwayTile> createState() => _PathwayTileState();
}

class _PathwayTileState extends State<_PathwayTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pathway = widget.pathway;
    final count = pathway.links.length;
    final hasFree = pathway.links.any((l) => l.isFree);
    final tokens = context.appColors;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _expanded = !_expanded);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x222563EB),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pathway.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (pathway.field != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.cardBorderSoft.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pathway.field!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: tokens.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        Text(
                          count == 0
                              ? 'No verified resources yet'
                              : '$count verified resource${count == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                        if (hasFree)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.successBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: tokens.success.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              'FREE OPTIONS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: tokens.success,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: tokens.textSecondary,
                  size: 22,
                ),
              ),
            ],
          ),
          if (widget.gapSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.warningBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.track_changes_rounded,
                    size: 16,
                    color: tokens.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Fills your skill gaps:',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: () {
                              final gaps = widget.gapSkills;
                              if (gaps.length == 1) return ' ${gaps.single}';
                              // Collapsed cards show the first few; the full
                              // list shows when the card is opened.
                              const collapsed = 3;
                              final shown = _expanded
                                  ? gaps
                                  : gaps.take(collapsed);
                              final more = gaps.length - collapsed;
                              return shown.map((g) => '\n• $g').join() +
                                  (!_expanded && more > 0
                                      ? '\n+$more more (tap to see all)'
                                      : '');
                            }(),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          CompleteButton(
            completed: widget.pathwayCompleted,
            onPressed: () => widget.onTogglePathway(!widget.pathwayCompleted),
          ),
          if (_expanded) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: tokens.cardBorderSoft),
            const SizedBox(height: 12),
            TrainingPathwayCard(
              pathway: pathway,
              completedKeys: widget.completedKeys,
              onToggleCompleted: widget.onToggleCompleted,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Certifications for your skill gaps": one chip per skill the user is
/// missing across posted jobs, most-demanded first. Tapping a chip filters
/// the pathway list to certifications covering that skill.
class _GapSection extends StatelessWidget {
  const _GapSection({
    required this.gaps,
    required this.selected,
    required this.padding,
    required this.onSelect,
  });

  final List<SkillGap> gaps;
  final String? selected;
  final double padding;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 4, padding, 0),
          child: Row(
            children: [
              Icon(
                Icons.track_changes_rounded,
                size: 18,
                color: tokens.warning,
              ),
              const SizedBox(width: 6),
              Text(
                'Certifications for your skill gaps',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 2, padding, 0),
          child: Text(
            selected == null
                ? 'Skills posted jobs need that you don\'t have yet (↑ = you have it below the required PSF-SDS level). Tap one to see its certifications.'
                : 'Showing certifications for $selected. Tap it again to show all.',
            style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(padding, 8, padding, 8),
            children: [
              for (final gap in gaps)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected == gap.skill,
                    onSelected: (_) => onSelect(gap.skill),
                    showCheckmark: false,
                    backgroundColor: tokens.cardBackground,
                    selectedColor: tokens.warning,
                    side: BorderSide(
                      color: selected == gap.skill
                          ? tokens.warning
                          : tokens.warning.withValues(alpha: 0.45),
                    ),
                    tooltip: [
                      if (gap.isLevelGap && gap.required != null)
                        'You: ${gap.required!.labelForRating(gap.rating!)} · Required: ${gap.required!.label}',
                      'Needed by: ${gap.jobTitles.join(', ')}',
                    ].join('\n'),
                    label: Text(
                      '${gap.isLevelGap ? '↑ ' : ''}${gap.skill}'
                      '${gap.required != null ? ' · ${gap.required!.label}' : ''}'
                      ' · ${gap.jobCount} job${gap.jobCount == 1 ? '' : 's'}',
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected == gap.skill
                          ? Colors.white
                          : tokens.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
