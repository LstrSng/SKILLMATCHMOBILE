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
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/centered_form_width.dart';

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _searchController = TextEditingController();

  List<Job> _jobs = [];
  bool _loading = true;
  String? _error;
  String? _jobTypeFilter;
  double _minMatch = 0;
  bool _hasAppliedToAllJobs = false;

  // Selected quick filter pill
  String _selectedQuickFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadJobs();
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
        fetchMyApplications().catchError(
          (_) => <Map<String, dynamic>>[],
        ),
      ]);
      final raw = results[0];
      final applications = results[1];
      final appliedJobIds = applications
          .map((a) => (a['jobId'] as Object?)?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final allJobs = raw.map(Job.fromJson).toList();
      final list = applyOwnSkillMatch(
        jobs: allJobs
            .where((j) => !appliedJobIds.contains(j.id))
            .toList(),
        mySkillKeys: readMySkillKeys(SessionStore.user),
      );
      if (!mounted) return;
      setState(() {
        _jobs = list;
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
        _error = e.toString();
      });
    }
  }

  List<Job> get _visibleJobs {
    final q = _searchController.text.trim().toLowerCase();
    bool matches(Job j) {
      // Quick filter
      if (_selectedQuickFilter == 'High Match (80%+)' && j.matchPercentage < 80) {
        return false;
      }
      if (_selectedQuickFilter == 'Full-time' &&
          !j.jobType.toLowerCase().contains('full')) {
        return false;
      }
      if (_selectedQuickFilter == 'Part-time' &&
          !j.jobType.toLowerCase().contains('part')) {
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
    setState(() {
      _jobTypeFilter = null;
      _minMatch = 0;
      _selectedQuickFilter = 'All';
      _searchController.clear();
    });
  }

  Future<void> _openFilterSheet() async {
    final jobTypes =
        _jobs.map((j) => j.jobType).where((t) => t.isNotEmpty).toSet().toList()
          ..sort();
    var selectedType = _jobTypeFilter;
    var selectedMinMatch = _minMatch;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                      const Text(
                        'Filter Jobs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Job Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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
                        selectedColor: AppColors.primarySoftBg,
                        onSelected: (_) =>
                            setSheetState(() => selectedType = null),
                      ),
                      ...jobTypes.map(
                        (t) => ChoiceChip(
                          label: Text(t),
                          selected: selectedType == t,
                          selectedColor: AppColors.primarySoftBg,
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
                      const Text(
                        'Minimum Match Score',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${selectedMinMatch.round()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
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
                    activeColor: AppColors.primary,
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
                            backgroundColor: AppColors.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _jobTypeFilter = selectedType;
                              _minMatch = selectedMinMatch;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Apply Filters'),
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleJobs = _visibleJobs;

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
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
                  vertical: 16,
                ),
                child: CenteredFormWidth(
                  maxWidth: 700,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & Search Bar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSoft),
                                boxShadow: const [AppColors.subtleShadow],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Search roles, skills, companies...',
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
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: Colors.white,
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
                                    color: (_jobTypeFilter != null || _minMatch > 0)
                                        ? AppColors.primary
                                        : AppColors.borderSoft,
                                  ),
                                  boxShadow: const [AppColors.subtleShadow],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      color: (_jobTypeFilter != null || _minMatch > 0)
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      size: 22,
                                    ),
                                    if (_jobTypeFilter != null || _minMatch > 0)
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
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
                              onTap: () => setState(() => _selectedQuickFilter = 'All'),
                            ),
                            const SizedBox(width: 8),
                            _QuickFilterChip(
                              label: '⚡ High Match (80%+)',
                              selected: _selectedQuickFilter == 'High Match (80%+)',
                              onTap: () => setState(() => _selectedQuickFilter = 'High Match (80%+)'),
                            ),
                            const SizedBox(width: 8),
                            _QuickFilterChip(
                              label: 'Full-time',
                              selected: _selectedQuickFilter == 'Full-time',
                              onTap: () => setState(() => _selectedQuickFilter = 'Full-time'),
                            ),
                            const SizedBox(width: 8),
                            _QuickFilterChip(
                              label: 'Remote',
                              selected: _selectedQuickFilter == 'Remote',
                              onTap: () => setState(() => _selectedQuickFilter = 'Remote'),
                            ),
                            const SizedBox(width: 8),
                            _QuickFilterChip(
                              label: 'Internship',
                              selected: _selectedQuickFilter == 'Internship',
                              onTap: () => setState(() => _selectedQuickFilter = 'Internship'),
                            ),
                            const SizedBox(width: 8),
                            _QuickFilterChip(
                              label: 'Part-time',
                              selected: _selectedQuickFilter == 'Part-time',
                              onTap: () => setState(() => _selectedQuickFilter = 'Part-time'),
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (_hasActiveFilters)
                            TextButton(
                              onPressed: _clearFilters,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Clear filters',
                                style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Job Cards List
                      if (visibleJobs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.search_off_rounded, size: 32, color: AppColors.textFaint),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _hasAppliedToAllJobs
                                      ? "You've applied to all available jobs!"
                                      : _jobs.isEmpty
                                      ? 'No job postings yet. Check back soon!'
                                      : 'No jobs match your search/filter.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Try searching for different keywords or resetting filters.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                        )
                      else
                        Column(
                          children: visibleJobs
                              .map(
                                (job) => _JobCard(
                                  job: job,
                                  onReturn: () => _loadJobs(silent: true),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
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

  const _QuickFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : const [AppColors.subtleShadow],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
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
    final applicantId =
        (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString();
    final matchColor = AppColors.matchColor(job.matchPercentage);
    final matchBg = AppColors.matchBgColor(job.matchPercentage);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.company,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: matchBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 14, color: matchColor),
                      const SizedBox(width: 2),
                      Text(
                        '${job.matchPercentage}%',
                        style: TextStyle(
                          color: matchColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
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
                  _MetaPill(
                    icon: Icons.schedule_rounded,
                    label: job.jobType,
                  ),
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
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
                  backgroundColor: AppColors.borderSoft,
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
                ...job.matchedSkills.take(3).map(
                  (skill) => _SkillBadge(skill: skill, matched: true),
                ),
                if (job.matchedSkills.length > 3)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Text(
                      '+${job.matchedSkills.length - 3} more',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillBadge extends StatelessWidget {
  final String skill;
  final bool matched;

  const _SkillBadge({required this.skill, required this.matched});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: matched ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: matched ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            matched ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: matched ? const Color(0xFF059669) : const Color(0xFFDC2626),
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            skill,
            style: TextStyle(
              color: matched ? const Color(0xFF065F46) : const Color(0xFF991B1B),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
