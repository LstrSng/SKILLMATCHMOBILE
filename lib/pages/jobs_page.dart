import 'dart:async';

import 'package:flutter/material.dart';
import 'job_detail_page.dart';
import '../models/job_role_skills.dart';
import '../services/applications_api.dart';
import '../services/job_roles_data.dart';
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
        loadJobRoles(),
        fetchMyApplications().catchError(
          (_) => <Map<String, dynamic>>[],
        ),
      ]);
      final raw = results[0] as List<Map<String, dynamic>>;
      final roles = results[1] as List<JobRoleSkills>;
      final applications = results[2] as List<Map<String, dynamic>>;
      final appliedJobIds = applications
          .map((a) => (a['jobId'] as Object?)?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final list = applyCsvSkillMatch(
        jobs: raw
            .map(Job.fromJson)
            .where((j) => !appliedJobIds.contains(j.id))
            .toList(),
        roles: roles,
        mySkillKeys: readMySkillKeys(SessionStore.user),
      );
      if (!mounted) return;
      setState(() {
        _jobs = list;
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
      if (_jobTypeFilter != null && j.jobType != _jobTypeFilter) return false;
      if (j.matchPercentage < _minMatch) return false;
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

  Future<void> _openFilterSheet() async {
    final jobTypes =
        _jobs.map((j) => j.jobType).where((t) => t.isNotEmpty).toSet().toList()
          ..sort();
    var selectedType = _jobTypeFilter;
    var selectedMinMatch = _minMatch;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                  Text(
                    'Filter Jobs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Job type',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
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
                        onSelected: (_) =>
                            setSheetState(() => selectedType = null),
                      ),
                      ...jobTypes.map(
                        (t) => ChoiceChip(
                          label: Text(t),
                          selected: selectedType == t,
                          onSelected: (_) =>
                              setSheetState(() => selectedType = t),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Minimum match: ${selectedMinMatch.round()}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: selectedMinMatch,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${selectedMinMatch.round()}%',
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (v) => setSheetState(() => selectedMinMatch = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheetState(() {
                            selectedType = null;
                            selectedMinMatch = 0;
                          }),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: uses theme
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
                      Text(
                        'Find Jobs',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              fontSize: 28,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: const Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Top matches for you',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search roles, skills, companies...',
                                hintStyle: const TextStyle(
                                  color: Color(0xFFD1D5DB),
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color(0xFF9CA3AF),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: (_jobTypeFilter != null || _minMatch > 0)
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.tune,
                                color: (_jobTypeFilter != null || _minMatch > 0)
                                    ? const Color(0xFF2563EB)
                                    : null,
                              ),
                              onPressed: _openFilterSheet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_visibleJobs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              _jobs.isEmpty
                                  ? 'No job postings yet. Add documents to your jobs collection in MongoDB, or set JOBS_COLLECTION in backend/.env if they live in another collection.'
                                  : 'No jobs match your search.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF6B7280)),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: _visibleJobs
                              .map(
                                (job) => _JobCard(
                                  job: job,
                                  onReturn: () => _loadJobs(silent: true),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

Color _matchColor(int percent) {
  if (percent >= 70) return AppColors.success;
  if (percent >= 40) return AppColors.warning;
  return AppColors.danger;
}

class _JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onReturn;

  const _JobCard({required this.job, required this.onReturn});

  int get _totalSkills => job.matchedSkills.length + job.unmatchedSkills.length;

  @override
  Widget build(BuildContext context) {
    final applicantId = (SessionStore.user?['_id'] ?? SessionStore.user?['id'])
        ?.toString();
    return GestureDetector(
      onTap: () async {
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
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and match percentage
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: job.initialColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      job.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.company,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _matchColor(
                      job.matchPercentage,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${job.matchPercentage}%',
                    style: TextStyle(
                      color: _matchColor(job.matchPercentage),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF9CA3AF),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  job.location,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Salary and Job Type
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  color: const Color(0xFF9CA3AF),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  job.salary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule,
                  color: const Color(0xFF9CA3AF),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  job.jobType,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Skill Match
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SKILL MATCH',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_totalSkills > 0)
                  Text(
                    '${job.matchedSkills.length}/$_totalSkills skills',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _matchColor(job.matchPercentage),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (_totalSkills > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: job.matchedSkills.length / _totalSkills,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _matchColor(job.matchPercentage),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),

            // Skills Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...job.matchedSkills.map(
                  (skill) => _SkillChip(skill: skill, matched: true),
                ),
                ...job.unmatchedSkills.map(
                  (skill) => _SkillChip(skill: skill, matched: false),
                ),
              ],
            ),
          ],
        ),
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
            matched ? Icons.check_circle : Icons.cancel,
            color: matched ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            skill,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: matched
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class Job {
  final String id;
  final String title;
  final String company;
  final String location;
  final String salary;
  final String jobType;
  final int matchPercentage;
  final String initial;
  final Color initialColor;
  final List<String> matchedSkills;
  final List<String> unmatchedSkills;
  final String description;
  final String postedDate;

  Job({
    this.id = '',
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.jobType,
    required this.matchPercentage,
    required this.initial,
    required this.initialColor,
    required this.matchedSkills,
    required this.unmatchedSkills,
    required this.description,
    required this.postedDate,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final company = (json['company'] as String?)?.trim() ?? '';
    final title = (json['title'] as String?)?.trim() ?? 'Untitled role';
    final id = (json['id'] as String?)?.trim() ?? '';
    final posted = (json['postedDate'] as String?)?.trim() ?? '';
    return Job(
      id: id,
      title: title,
      company: company,
      location: (json['location'] as String?)?.trim() ?? '',
      salary: (json['salary'] as String?)?.trim() ?? '',
      jobType: (json['jobType'] as String?)?.trim() ?? '',
      matchPercentage: _parseMatchPercent(json['matchPercentage']),
      initial: _initialFromCompany(company),
      initialColor: _brandColorForKey(company.isNotEmpty ? company : title),
      matchedSkills: _stringList(json['matchedSkills']),
      unmatchedSkills: _stringList(json['unmatchedSkills']),
      description: (json['description'] as String?)?.trim() ?? '',
      postedDate: posted.isNotEmpty ? posted : 'Recently posted',
    );
  }

  static int _parseMatchPercent(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static List<String> _stringList(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString()).toList();
  }

  static String _initialFromCompany(String c) {
    final t = c.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }

  static const List<Color> _palette = [
    Color(0xFF2563EB),
    Color(0xFF9333EA),
    Color(0xFFEC4899),
    Color(0xFF22C55E),
    Color(0xFF0EA5A5),
  ];

  static Color _brandColorForKey(String key) {
    if (key.isEmpty) return _palette[0];
    var h = 0;
    for (var i = 0; i < key.length; i++) {
      h = key.codeUnitAt(i) + ((h << 5) - h);
    }
    return _palette[h.abs() % _palette.length];
  }

  Job copyWith({
    int? matchPercentage,
    List<String>? matchedSkills,
    List<String>? unmatchedSkills,
  }) {
    return Job(
      id: id,
      title: title,
      company: company,
      location: location,
      salary: salary,
      jobType: jobType,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      initial: initial,
      initialColor: initialColor,
      matchedSkills: matchedSkills ?? this.matchedSkills,
      unmatchedSkills: unmatchedSkills ?? this.unmatchedSkills,
      description: description,
      postedDate: postedDate,
    );
  }
}
