import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/training_pathway.dart';
import '../services/pathway_links_data.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/training_pathway_card.dart';

class PathwayPage extends StatefulWidget {
  const PathwayPage({
    super.key,
    this.initialQuery,
    this.initialCategory,
  });

  final String? initialQuery;
  final String? initialCategory;

  @override
  State<PathwayPage> createState() => _PathwayPageState();
}

class _PathwayPageState extends State<PathwayPage> {
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<TrainingPathway> _pathways = [];
  late String _selectedCategory = widget.initialCategory ?? 'All';

  static const _categories = [
    'All',
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
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pathways = await allTrainingPathways(forceReload: true);
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
    final q = _searchController.text.trim().toLowerCase();
    final filtered = _pathways.where((p) {
      if (_selectedCategory != 'All') {
        final cat = _selectedCategory.toLowerCase();
        final nameLower = p.name.toLowerCase();
        final fieldLower = (p.field ?? '').toLowerCase();
        final bool matchesCategory;
        if (cat == 'free certs') {
          matchesCategory = p.links.any(
            (l) => (l.isFree == true) || l.label.toLowerCase().contains('free'),
          );
        } else if (cat == 'mobile') {
          matchesCategory = fieldLower == 'mobile' ||
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
          matchesCategory = fieldLower == 'web' ||
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
          matchesCategory = fieldLower == 'data & ai' ||
              nameLower.contains('data') ||
              nameLower.contains('machine learning') ||
              nameLower.contains('database') ||
              nameLower.contains('bi') ||
              nameLower.contains('sql');
        } else if (cat == 'cloud') {
          matchesCategory = fieldLower == 'cloud' ||
              nameLower.contains('cloud') ||
              nameLower.contains('aws') ||
              nameLower.contains('azure') ||
              nameLower.contains('gcp');
        } else if (cat == 'cybersecurity') {
          matchesCategory = fieldLower == 'cybersecurity' ||
              nameLower.contains('cyber') ||
              nameLower.contains('security') ||
              nameLower.contains('penetration');
        } else if (cat == 'devops') {
          matchesCategory = fieldLower == 'devops' ||
              nameLower.contains('devops') ||
              nameLower.contains('kubernetes') ||
              nameLower.contains('ci/cd') ||
              nameLower.contains('pipeline') ||
              nameLower.contains('qa') ||
              nameLower.contains('git') ||
              nameLower.contains('automation');
        } else if (cat == 'design') {
          matchesCategory = fieldLower == 'design' ||
              nameLower.contains('design') ||
              nameLower.contains('ux') ||
              nameLower.contains('ui') ||
              nameLower.contains('animation') ||
              nameLower.contains('accessibility');
        } else if (cat == 'game dev') {
          matchesCategory = fieldLower == 'game dev' ||
              nameLower.contains('game') ||
              nameLower.contains('unity') ||
              nameLower.contains('unreal');
        } else if (cat == 'it & support') {
          matchesCategory = fieldLower == 'it & support' ||
              nameLower.contains('it support') ||
              nameLower.contains('help desk') ||
              nameLower.contains('networking') ||
              nameLower.contains('linux') ||
              nameLower.contains('service management');
        } else if (cat == 'management') {
          matchesCategory = fieldLower == 'management' ||
              nameLower.contains('management') ||
              nameLower.contains('analysis') ||
              nameLower.contains('leadership') ||
              nameLower.contains('agile');
        } else if (cat == 'other') {
          matchesCategory = fieldLower == 'other' ||
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
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.links.any((l) => l.label.toLowerCase().contains(q));
    }).toList();

    final horizontalPadding =
        MediaQuery.of(context).size.width > 600 ? 32.0 : 16.0;
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
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textSecondary,
                  ),
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
                    onChanged: (v) => setState(() {}),
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
                              icon: Icon(Icons.clear, size: 18, color: tokens.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected ? tokens.primary : tokens.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? tokens.primary : tokens.cardBorderSoft,
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
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                color: selected ? Colors.white : tokens.textSecondary,
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
          Expanded(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 36, color: tokens.textFaint),
                          const SizedBox(height: 12),
                          Text(
                            'No matching certification pathways found.',
                            style: TextStyle(color: tokens.textSecondary, fontSize: 14),
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
                      100,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _PathwayTile(
                      key: ValueKey(filtered[i].name),
                      pathway: filtered[i],
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

  const _PathwayTile({super.key, required this.pathway});

  @override
  State<_PathwayTile> createState() => _PathwayTileState();
}

class _PathwayTileState extends State<_PathwayTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pathway = widget.pathway;
    final count = pathway.links.length;
    final hasFree = pathway.links.any((l) => (l.isFree == true) || l.label.toLowerCase().contains('free'));
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
                              color: tokens.cardBorderSoft.withValues(alpha: 0.5),
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
          if (_expanded) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: tokens.cardBorderSoft),
            const SizedBox(height: 12),
            TrainingPathwayCard(pathway: pathway),
          ],
        ],
      ),
    );
  }
}
