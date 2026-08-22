import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/training_pathway.dart';
import '../services/pathway_links_data.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/training_pathway_card.dart';

class PathwayPage extends StatefulWidget {
  const PathwayPage({super.key});

  @override
  State<PathwayPage> createState() => _PathwayPageState();
}

class _PathwayPageState extends State<PathwayPage> {
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<TrainingPathway> _pathways = [];
  String _selectedCategory = 'All';

  static const _categories = [
    'All',
    'Cloud',
    'Cybersecurity',
    'Data',
    'DevOps',
    'Developer',
  ];

  @override
  void initState() {
    super.initState();
    _load();
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
      if (_selectedCategory != 'All' &&
          !p.name.toLowerCase().contains(_selectedCategory.toLowerCase())) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.links.any((l) => l.label.toLowerCase().contains(q));
    }).toList();

    final horizontalPadding =
        MediaQuery.of(context).size.width > 600 ? 32.0 : 16.0;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
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
                const Text(
                  'Certifications & Pathways',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Browse industry certifications to boost your job matches',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Search field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSoft),
                    boxShadow: const [AppColors.subtleShadow],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search pathways (e.g. AWS, Cyber, Python)...',
                      hintStyle: const TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
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
                              color: selected ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? AppColors.primary : AppColors.borderSoft,
                              ),
                              boxShadow: selected
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x332563EB),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : const [AppColors.subtleShadow],
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                color: selected ? Colors.white : AppColors.textSecondary,
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
                        children: const [
                          Icon(Icons.search_off_rounded, size: 36, color: AppColors.textFaint),
                          SizedBox(height: 12),
                          Text(
                            'No matching certification pathways found.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'No verified resources yet'
                          : '$count verified certification${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.borderSoft),
            const SizedBox(height: 12),
            TrainingPathwayCard(pathway: pathway),
          ],
        ],
      ),
    );
  }
}
