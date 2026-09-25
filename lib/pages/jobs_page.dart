import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'job_detail_page.dart';
import '../models/job.dart';
import '../services/applications_api.dart';
import '../services/job_skill_matcher.dart';
import '../services/jobs_api.dart';
import '../services/notification_store.dart';
import '../services/session_store.dart';
import '../services/saved_jobs_store.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/widgets.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _debouncedQuery = '';

  List<Job> _jobs = [];
  bool _loading = true;
  String? _error;
  String? _jobTypeFilter;
  double _minMatch = 0;
  bool _hasAppliedToAllJobs = false;

  // Selected quick filter pill
  String _selectedQuickFilter = 'All';
  Set<String> _savedJobIds = {};

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() => _debouncedQuery = '');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _debouncedQuery = val.trim().toLowerCase());
    });
  }

  @override
  void initState() {
    super.initState();
    SessionStore.skillsChanged.addListener(_onSkillsChanged);
    _initFromCacheAndLoad();
  }

  /// Re-matches the loaded jobs against the user's updated skills.
  void _onSkillsChanged() {
    if (!mounted) return;
    setState(() {
      _jobs = applyOwnSkillMatch(jobs: _jobs, user: SessionStore.user);
    });
  }

  Future<void> _initFromCacheAndLoad() async {
    final cached = await getCachedJobsRaw();
    if (!mounted) return;
    if (cached.isNotEmpty) {
      final cachedApps =
          memoryCachedApplications ?? await getCachedMyApplications();
      final activeApplications = cachedApps.where((a) {
        final status =
            (a['status'] as Object?)?.toString().trim().toLowerCase() ?? '';
        return status != 'withdrawn' && status != 'rejected';
      });
      final appliedJobIds = activeApplications
          .map((a) => (a['jobId'] as Object?)?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final allJobs = cached.map(Job.fromJson).toList();
      final list = applyOwnSkillMatch(
        jobs: allJobs.where((j) => !appliedJobIds.contains(j.id)).toList(),
        user: SessionStore.user,
      );
      if (mounted) {
        setState(() {
          _jobs = list;
          _hasAppliedToAllJobs = allJobs.isNotEmpty && list.isEmpty;
          _loading = false;
        });
      }
    }
    await _loadJobs(silent: _jobs.isNotEmpty);
  }

  Future<void> _loadJobs({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        fetchJobsRaw(),
        fetchMyApplications().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final raw = results[0];
      final applications = results[1];
      final activeApplications = applications.where((a) {
        final status =
            (a['status'] as Object?)?.toString().trim().toLowerCase() ?? '';
        return status != 'withdrawn' && status != 'rejected';
      });
      final appliedJobIds = activeApplications
          .map((a) => (a['jobId'] as Object?)?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final allJobs = raw.map(Job.fromJson).toList();
      final list = applyOwnSkillMatch(
        jobs: allJobs.where((j) => !appliedJobIds.contains(j.id)).toList(),
        user: SessionStore.user,
      );
      final savedIds = await SavedJobsStore.loadIds();
      if (!mounted) return;
      setState(() {
        _jobs = list;
        _savedJobIds = savedIds;
        _hasAppliedToAllJobs = allJobs.isNotEmpty && list.isEmpty;
        _loading = false;
        _error = null;
      });
      unawaited(
        NotificationStore.syncNewJobMatches(
          list
              .where((j) => j.id.isNotEmpty)
              .map((j) => MapEntry(j.id, j.title))
              .toList(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_jobs.isEmpty) {
          _error = e.toString();
        }
      });
    }
  }

  List<Job> get _visibleJobs {
    final q = _debouncedQuery;
    bool matches(Job j) {
      // Quick filter
      if (_selectedQuickFilter == 'Saved' && !_savedJobIds.contains(j.id)) {
        return false;
      }
      if (_selectedQuickFilter == 'High Match (80%+)' &&
          j.matchPercentage < 80) {
        return false;
      }
      if (_selectedQuickFilter == 'Full-time' &&
          !j.jobType.toLowerCase().contains('full')) {
        return false;
      }
      if (_selectedQuickFilter == 'Hybrid' &&
          !j.location.toLowerCase().contains('hybrid') &&
          !j.jobType.toLowerCase().contains('hybrid')) {
        return false;
      }
      if (_selectedQuickFilter == 'Remote' &&
          !j.location.toLowerCase().contains('remote') &&
          !j.jobType.toLowerCase().contains('remote')) {
        return false;
      }
      if (_selectedQuickFilter == 'Internship' &&
          !j.jobType.toLowerCase().contains('intern') &&
          !j.title.toLowerCase().contains('intern')) {
        return false;
      }

      // Modal filters
      if (_jobTypeFilter != null && j.jobType != _jobTypeFilter) return false;
      if (j.matchPercentage < _minMatch) return false;

      // Query search
      if (q.isEmpty) return true;
      final hay = [
        j.title,
        j.company,
        j.location,
        j.jobType,
        j.salary,
        ...j.matchedSkills,
        ...j.unmatchedSkills,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }

    return _jobs.where(matches).toList();
  }

  bool get _hasActiveFilters =>
      _jobTypeFilter != null || _minMatch > 0 || _selectedQuickFilter != 'All';

  void _clearFilters() {
    _searchDebounce?.cancel();
    setState(() {
      _jobTypeFilter = null;
      _minMatch = 0;
      _selectedQuickFilter = 'All';
      _searchController.clear();
      _debouncedQuery = '';
    });
  }

  Future<void> _openFilterSheet() async {
    final jobTypes =
        _jobs.map((j) => j.jobType).where((t) => t.isNotEmpty).toSet().toList()
          ..sort();
    var selectedType = _jobTypeFilter;
    var selectedMinMatch = _minMatch;

    final tokens = context.appColors;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Jobs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: tokens.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Job Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: selectedType == null,
                        selectedColor: tokens.primarySoftBg,
                        onSelected: (_) =>
                            setSheetState(() => selectedType = null),
                      ),
                      ...jobTypes.map(
                        (t) => ChoiceChip(
                          label: Text(t),
                          selected: selectedType == t,
                          selectedColor: tokens.primarySoftBg,
                          onSelected: (_) =>
                              setSheetState(() => selectedType = t),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Minimum Match Score',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      Text(
                        '${selectedMinMatch.round()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: tokens.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: selectedMinMatch,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${selectedMinMatch.round()}%',
                    activeColor: tokens.primary,
                    onChanged: (v) => setSheetState(() => selectedMinMatch = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              selectedType = null;
                              selectedMinMatch = 0;
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: tokens.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _jobTypeFilter = selectedType;
                              _minMatch = selectedMinMatch;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    SessionStore.skillsChanged.removeListener(_onSkillsChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleJobs = _visibleJobs;
    final tokens = context.appColors;

    return Scaffold(
      appBar: const AppTopBar(),
      body: _loading
          ? ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
                vertical: 16,
              ),
              itemCount: 4,
              itemBuilder: (context, _) => const CenteredFormWidth(
                maxWidth: 700,
                child: JobCardSkeleton(),
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _loadJobs(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadJobs(silent: true),
              color: tokens.primary,
              child: CenteredFormWidth(
                maxWidth: 700,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        MediaQuery.of(context).size.width > 600 ? 32 : 16,
                        16,
                        MediaQuery.of(context).size.width > 600 ? 32 : 16,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PageHeroHeader(
                              icon: Icons.explore_rounded,
                              eyebrow: 'Find your fit',
                              title: 'Explore Jobs',
                              subtitle:
                                  'Jobs ranked by how well they match your skills.',
                              highlight: _jobs.isEmpty
                                  ? null
                                  : () {
                                      final strong = _jobs
                                          .where((j) => j.matchPercentage >= 70)
                                          .length;
                                      final n = _jobs.length;
                                      return '$n job${n == 1 ? '' : 's'} · $strong strong match${strong == 1 ? '' : 'es'}';
                                    }(),
                            ),
                            const SizedBox(height: 16),
                            // Header & Search Bar
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: tokens.cardBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tokens.cardBorderSoft,
                                      ),
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
                                            'Search roles, skills, companies...',
                                        hintStyle: TextStyle(
                                          color: tokens.textFaint,
                                          fontSize: 14,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search_rounded,
                                          color: tokens.textSecondary,
                                          size: 20,
                                        ),
                                        suffixIcon:
                                            ValueListenableBuilder<
                                              TextEditingValue
                                            >(
                                              valueListenable:
                                                  _searchController,
                                              builder: (context, value, _) {
                                                if (value.text.isEmpty) {
                                                  return const SizedBox.shrink();
                                                }
                                                return IconButton(
                                                  icon: Icon(
                                                    Icons.clear,
                                                    size: 18,
                                                    color: tokens.textSecondary,
                                                  ),
                                                  onPressed: () {
                                                    _searchDebounce?.cancel();
                                                    _searchController.clear();
                                                    setState(
                                                      () =>
                                                          _debouncedQuery = '',
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 14,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Material(
                                  color: tokens.cardBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: _openFilterSheet,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              (_jobTypeFilter != null ||
                                                  _minMatch > 0)
                                              ? tokens.primary
                                              : tokens.cardBorderSoft,
                                        ),
                                        boxShadow: tokens.cardShadows,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.tune_rounded,
                                            color:
                                                (_jobTypeFilter != null ||
                                                    _minMatch > 0)
                                                ? tokens.primary
                                                : tokens.textSecondary,
                                            size: 22,
                                          ),
                                          if (_jobTypeFilter != null ||
                                              _minMatch > 0)
                                            Positioned(
                                              top: 10,
                                              right: 10,
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: tokens.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Quick-Filter Horizontal Chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _QuickFilterChip(
                                    label: 'All',
                                    selected: _selectedQuickFilter == 'All',
                                    onTap: () => setState(
                                      () => _selectedQuickFilter = 'All',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _QuickFilterChip(
                                    label: 'Saved',
                                    icon: Icons.bookmark_rounded,
                                    selected: _selectedQuickFilter == 'Saved',
                                    onTap: () async {
                                      final ids =
                                          await SavedJobsStore.loadIds();
                                      if (mounted) {
                                        setState(() {
                                          _savedJobIds = ids;
                                          _selectedQuickFilter = 'Saved';
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _QuickFilterChip(
                                    label: '⚡ High Match (80%+)',
                                    selected:
                                        _selectedQuickFilter ==
                                        'High Match (80%+)',
                                    onTap: () => setState(
                                      () => _selectedQuickFilter =
                                          'High Match (80%+)',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _QuickFilterChip(
                                    label: 'Full-time',
                                    selected:
                                        _selectedQuickFilter == 'Full-time',
                                    onTap: () => setState(
                                      () => _selectedQuickFilter = 'Full-time',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _QuickFilterChip(
                                    label: 'Remote',
                                    selected: _selectedQuickFilter == 'Remote',
                                    onTap: () => setState(
                                      () => _selectedQuickFilter = 'Remote',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _QuickFilterChip(
                                    label: 'Internship',
                                    selected:
                                        _selectedQuickFilter == 'Internship',
                                    onTap: () => setState(
                                      () => _selectedQuickFilter = 'Internship',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _QuickFilterChip(
                                    label: 'Hybrid',
                                    selected: _selectedQuickFilter == 'Hybrid',
                                    onTap: () => setState(
                                      () => _selectedQuickFilter = 'Hybrid',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Job count bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${visibleJobs.length} ${visibleJobs.length == 1 ? "Job" : "Jobs"} Available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                                if (_hasActiveFilters)
                                  TextButton(
                                    onPressed: _clearFilters,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Clear filters',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tokens.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),

                    // Job Cards List
                    if (visibleJobs.isEmpty)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width > 600
                              ? 32
                              : 16,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceMuted,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.search_off_rounded,
                                      size: 32,
                                      color: tokens.textFaint,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _hasAppliedToAllJobs
                                        ? "No more jobs available at the moment."
                                        : _selectedQuickFilter == 'Saved'
                                        ? "No saved jobs yet"
                                        : _jobs.isEmpty
                                        ? 'No jobs match your filters'
                                        : 'No jobs match your search/filter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: tokens.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _hasAppliedToAllJobs
                                        ? 'Check back later for new opportunities.'
                                        : _selectedQuickFilter == 'Saved'
                                        ? 'Tap the bookmark icon on any job to save it for later.'
                                        : 'Try adjusting your search criteria or explore all available positions.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (_hasActiveFilters) ...[
                                    const SizedBox(height: 16),
                                    FilledButton.tonal(
                                      onPressed: _clearFilters,
                                      child: const Text('Reset Filters'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width > 600
                              ? 32
                              : 16,
                        ),
                        sliver: SliverList.builder(
                          itemCount: visibleJobs.length,
                          itemBuilder: (context, index) => _JobCard(
                            job: visibleJobs[index],
                            onReturn: () => _loadJobs(silent: true),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _QuickFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : tokens.cardShadows,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : tokens.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onReturn;

  const _JobCard({required this.job, required this.onReturn});

  int get _totalSkills => job.matchedSkills.length + job.unmatchedSkills.length;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final applicantId = (SessionStore.user?['_id'] ?? SessionStore.user?['id'])
        ?.toString();
    final matchColor = AppColors.matchColor(job.matchPercentage);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      animateScaleOnTap: false,
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailPage(
                jobId: job.id,
                applicantId: applicantId,
                title: job.title,
                company: job.company,
                location: job.location,
                salary: job.salary,
                jobType: job.jobType,
                postedDate: job.postedDate,
                matchPercentage: job.matchPercentage,
                description: job.description,
                matchedSkills: job.matchedSkills,
                unmatchedSkills: job.unmatchedSkills,
              ),
            ),
          );
          onReturn();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Avatar + Title & Company + Match Score
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: job.initialColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      job.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.company,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                MatchScoreBadge(
                  score: job.matchPercentage,
                  variant: MatchScoreBadgeVariant.pill,
                  showLabel: false,
                  animate: false,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metadata Tag Row (Location, Salary, Job Type)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (job.location.isNotEmpty)
                  _MetaPill(
                    icon: Icons.location_on_outlined,
                    label: job.location,
                  ),
                if (job.salary.isNotEmpty)
                  _MetaPill(
                    icon: Icons.attach_money_rounded,
                    label: job.salary,
                  ),
                if (job.jobType.isNotEmpty)
                  _MetaPill(icon: Icons.schedule_rounded, label: job.jobType),
              ],
            ),
            const SizedBox(height: 12),

            // Matched Skills Breakdown
            if (_totalSkills > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Matched Skills (${job.matchedSkills.length}/$_totalSkills)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    '${job.matchPercentage}% fit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: matchColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: job.matchedSkills.length / _totalSkills,
                  minHeight: 4,
                  backgroundColor: tokens.cardBorderSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(matchColor),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Skills Chips Row (Top 3 matched skills)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...job.matchedSkills
                    .take(3)
                    .map(
                      (skill) => SkillChip(
                        label: skill,
                        status: SkillChipStatus.matched,
                        size: SkillChipSize.small,
                        animateOnTap: false,
                      ),
                    ),
                if (job.matchedSkills.length > 3)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.cardBorderSoft),
                    ),
                    child: Text(
                      '+${job.matchedSkills.length - 3} more',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.cardBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tokens.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
