import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/training_pathway.dart';
import '../services/completed_certs.dart';
import '../services/pathway_links_data.dart';
import '../services/session_store.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';
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
  List<String> _suggestedSkills = [];
  Set<String> _completedKeys = completedCertificationKeys();

  /// Recommended roles whose pathway the user hasn't completed a cert in yet.
  List<String> _visibleSuggestions = [];

  Future<void> _refreshSuggestions() async {
    final visible = <String>[];
    for (final role in _suggestedSkills) {
      final pathway = await trainingPathwayForRole(role);
      final done =
          pathway != null &&
          pathway.links.any((l) => isCertificationCompleted(l, _completedKeys));
      if (!done) visible.add(role);
    }
    if (mounted) setState(() => _visibleSuggestions = visible);
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
      _refreshSuggestions();
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

    final user = SessionStore.user;
    if (user != null) {
      final assessments = user['profile']?['skillAssessments'] as Map?;
      if (assessments != null) {
        for (final data in assessments.values) {
          if (data is Map) {
            final passed = data['passed'] == true;
            final score = (data['scorePercentage'] as num?)?.toDouble() ?? 0.0;
            final roleTitle = data['roleTitle'] as String?;
            if (roleTitle != null && (!passed || score < 70)) {
              if (!_suggestedSkills.contains(roleTitle)) {
                _suggestedSkills.add(roleTitle);
              }
            }
          }
        }
      }
    }

    _visibleSuggestions = List.of(_suggestedSkills);
    _load();
    _refreshSuggestions();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _debouncedQuery = v.trim().toLowerCase());
    });
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

    final filtered = _pathways.where((p) {
      if (!isAllCat) {
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
          matchesCategory = p.links.any(
            (l) => l.isFree || l.label.toLowerCase().contains('free'),
          );
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

    final horizontalPadding = MediaQuery.of(context).size.width > 600
        ? 32.0
        : 16.0;
    final tokens = context.appColors;

    return RefreshIndicator(
      onRefresh: _load,
      color: tokens.primary,
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
                Text(
                  'Certifications & Pathways',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse industry certifications to boost your job matches',
                  style: TextStyle(fontSize: 14, color: tokens.textSecondary),
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
                    style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search pathways (e.g. AWS, Cyber, Python)...',
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
          if (_visibleSuggestions.isNotEmpty &&
              widget.initialQuery == null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recommended for you',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Based on your assessments',
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  8,
                ),
                children: _visibleSuggestions.map((skill) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: tokens.cardBackground,
                      side: BorderSide(color: tokens.primary),
                      label: Text(skill),
                      labelStyle: TextStyle(
                        color: tokens.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      onPressed: () {
                        _searchController.text = skill;
                        setState(() => _debouncedQuery = skill.toLowerCase());
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 36,
                            color: tokens.textFaint,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No matching certification pathways found.',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      4,
                      horizontalPadding,
                      80,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _PathwayTile(
                      key: ValueKey(filtered[i].name),
                      pathway: filtered[i],
                      completedKeys: _completedKeys,
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
  final Set<String> completedKeys;
  final void Function(TrainingResource link, bool completed) onToggleCompleted;

  const _PathwayTile({
    super.key,
    required this.pathway,
    required this.completedKeys,
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
    final doneCount = pathway.links
        .where((l) => isCertificationCompleted(l, widget.completedKeys))
        .length;
    final hasFree = pathway.links.any(
      (l) => l.isFree || l.label.toLowerCase().contains('free'),
    );
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
                        if (doneCount > 0)
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
                              doneCount == count
                                  ? '✓ ALL COMPLETED'
                                  : '✓ $doneCount/$count COMPLETED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: tokens.success,
                                letterSpacing: 0.3,
                              ),
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
