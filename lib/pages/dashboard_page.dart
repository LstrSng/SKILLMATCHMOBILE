import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'job_detail_page.dart';
import 'skill_assessment_page.dart';
import '../models/job.dart';
import '../models/job_application.dart';
import '../services/applications_api.dart';
import '../services/job_skill_matcher.dart';
import '../services/jobs_api.dart';
import '../services/navigation_service.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';
import '../services/skill_assessment_engine.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/widgets.dart';
import 'sign_in_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _profile = SessionStore.user ?? {};
  List<Job> _jobs = const [];
  List<JobApplication> _applications = const [];

  String _cachedGreetingName = '';
  double _cachedProfileCompletion = 0.0;
  int _cachedAvgMatch = 0;
  List<Job> _cachedTopMatches = const [];
  List<int> _cachedWeeklyActivity = const [0, 0, 0, 0, 0, 0, 0];
  List<String> _cachedWeeklyLabels = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  bool _cachedHasAnyAssessment = false;

  void _recomputeDerivedMetrics() {
    _cachedGreetingName = _greetingName();
    _cachedProfileCompletion = _profileCompletion();
    _cachedAvgMatch = _averageMatch();
    _cachedTopMatches = _topMatches();
    _cachedWeeklyActivity = _weeklyActivity();
    _cachedWeeklyLabels = _weeklyLabels();
    _cachedHasAnyAssessment = _hasAnyAssessment();
  }

  @override
  void initState() {
    super.initState();
    _recomputeDerivedMetrics();
    _initFromCacheAndLoad();
  }

  Future<void> _initFromCacheAndLoad() async {
    // 1. Immediately hydrate from cache so the screen displays without delay
    final cachedJobsRaw = await getCachedJobsRaw();
    final cachedAppsRaw = await getCachedMyApplications();
    if (!mounted) return;

    if (cachedJobsRaw.isNotEmpty || _profile.isNotEmpty) {
      final rawJobs = cachedJobsRaw.map(Job.fromJson).toList();
      final applications = cachedAppsRaw.map(JobApplication.fromJson).toList();
      final jobs = applyOwnSkillMatch(
        jobs: rawJobs,
        mySkillKeys: readMySkillKeys(_profile),
      );
      setState(() {
        _jobs = jobs;
        _applications = applications;
        _loading = false;
        _recomputeDerivedMetrics();
      });
    }

    // 2. Fetch fresh data in background (silent if cache is already shown)
    await _load(silent: _jobs.isNotEmpty);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final profileFuture = fetchMyProfile().catchError((e) {
        debugPrint('fetchMyProfile error: $e');
        return _profile;
      });
      bool jobsFailed = false;
      final jobsFuture = fetchJobsRaw().catchError((e) {
        debugPrint('fetchJobsRaw error: $e');
        jobsFailed = true;
        return <Map<String, dynamic>>[];
      });
      bool appsFailed = false;
      final appsFuture = fetchMyApplications().catchError((e) {
        debugPrint('fetchMyApplications error: $e');
        appsFailed = true;
        return <Map<String, dynamic>>[];
      });

      final results = await Future.wait([
        profileFuture,
        jobsFuture,
        appsFuture,
      ]);
      if (!mounted) return;
      final profile = results[0] as Map<String, dynamic>;
      final rawJobsList = results[1] as List<Map<String, dynamic>>;
      final rawAppsList = results[2] as List<Map<String, dynamic>>;

      final rawJobs = jobsFailed
          ? _jobs
          : rawJobsList.map(Job.fromJson).toList();
      final applications = appsFailed
          ? _applications
          : rawAppsList.map(JobApplication.fromJson).toList();

      final jobs = applyOwnSkillMatch(
        jobs: rawJobs,
        mySkillKeys: readMySkillKeys(profile),
      );
      setState(() {
        _profile = profile;
        _jobs = jobs;
        _applications = applications;
        _loading = false;
        _error = null;
        _recomputeDerivedMetrics();
      });
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

  String _greetingName() {
    final first = (_profile['firstName'] as Object?)?.toString().trim() ?? '';
    if (first.isNotEmpty) return first;
    final last = (_profile['lastName'] as Object?)?.toString().trim() ?? '';
    if (last.isNotEmpty) return last;
    final email = (_profile['email'] as Object?)?.toString().trim() ?? '';
    if (email.isNotEmpty) return email;
    return '';
  }

  double _profileCompletion() {
    bool has(String key) =>
        (_profile[key] as Object?)?.toString().trim().isNotEmpty ?? false;
    bool hasList(String key) {
      final v = _profile[key];
      return v is List && v.isNotEmpty;
    }

    final profileData = _profile['profile'];
    final hasResume =
        profileData is Map &&
        profileData['resume'] is Map &&
        ((profileData['resume']['url'] as Object?)
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true ||
            (profileData['resume']['data'] as Object?)
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true ||
            (profileData['resume']['name'] as Object?)
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true);

    final checks = [
      has('firstName'),
      has('lastName'),
      has('headline'),
      has('location'),
      has('phone'),
      has('portfolioUrl'),
      hasList('skills'),
      hasList('education'),
      hasList('experience'),
      hasResume,
    ];
    final filled = checks.where((c) => c).length;
    return filled / checks.length;
  }

  int _averageMatch() {
    if (_jobs.isEmpty) return 0;
    final total = _jobs.fold<int>(0, (sum, j) => sum + j.matchPercentage);
    return (total / _jobs.length).round();
  }

  List<Job> _topMatches() {
    final sorted = [..._jobs]
      ..sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
    return sorted.take(3).toList();
  }

  bool _hasAnyAssessment() {
    final profileData = _profile['profile'];
    if (profileData is! Map) return false;
    final mapped = profileData.map((k, v) => MapEntry(k.toString(), v));
    return readAssessmentResults(mapped).isNotEmpty;
  }

  Future<void> _openAssessment() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SkillAssessmentPage()),
    );
    if (!mounted) return;
    _load();
  }

  List<int> _weeklyActivity() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return List.generate(7, (i) {
      final day = startOfToday.subtract(Duration(days: 6 - i));
      final nextDay = day.add(const Duration(days: 1));
      return _applications
          .where(
            (app) =>
                !app.appliedDate.isBefore(day) &&
                app.appliedDate.isBefore(nextDay),
          )
          .length;
    });
  }

  List<String> _weeklyLabels() {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return names[day.weekday - 1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final name = _cachedGreetingName;
    final applied = _applications.length;
    final matches = _jobs.where((j) => j.matchPercentage > 0).length;
    final avgMatch = _cachedAvgMatch;
    final profileCompletion = _cachedProfileCompletion;
    final topMatches = _cachedTopMatches;

    return Scaffold(
      appBar: const AppTopBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        color: tokens.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332563EB),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty
                                    ? 'Hello, Jobseeker!'
                                    : 'Hello, $name 👋',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Your career optimization overview',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFBFDBFE),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quick Action Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _HeroActionChip(
                            icon: Icons.explore_rounded,
                            label: 'Explore Jobs',
                            onTap: () => AppNavigation.switchTab(AppTab.jobs),
                          ),
                          const SizedBox(width: 8),
                          _HeroActionChip(
                            icon: Icons.alt_route_rounded,
                            label: 'Pathways',
                            onTap: () =>
                                AppNavigation.switchTab(AppTab.pathway),
                          ),
                          const SizedBox(width: 8),
                          _HeroActionChip(
                            icon: Icons.person_rounded,
                            label: 'My Profile',
                            onTap: () =>
                                AppNavigation.switchTab(AppTab.profile),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.dangerBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (SessionStore.token == null ||
                            SessionStore.token!.isEmpty)
                          TextButton(
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignInPage(),
                                ),
                                (_) => false,
                              );
                            },
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Interactive Stat Cards Grid
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 600
                      ? 4
                      : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.15,
                  children: [
                    _StatCard(
                      label: 'Profile Score',
                      value: '${(profileCompletion * 100).round()}%',
                      icon: Icons.person_outline_rounded,
                      iconBgColor: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                      hasProgress: true,
                      progress: profileCompletion,
                      onTap: () => AppNavigation.switchTab(AppTab.profile),
                    ),
                    _StatCard(
                      label: 'Job Matches',
                      value: '$matches',
                      icon: Icons.work_outline_rounded,
                      iconBgColor: const Color(0xFFEFF6FF),
                      iconColor: AppColors.primary,
                      subtitle: matches == 0
                          ? 'Complete your profile'
                          : '$matches with skill overlap',
                      onTap: () => AppNavigation.switchTab(AppTab.jobs),
                    ),
                    _StatCard(
                      label: 'Avg Skill Match',
                      value: _jobs.isEmpty ? '—' : '$avgMatch%',
                      icon: Icons.bolt_rounded,
                      iconBgColor: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      subtitle: _jobs.isEmpty ? 'No jobs' : 'Overall rating',
                      onTap: () => AppNavigation.switchTab(AppTab.jobs),
                    ),
                    _StatCard(
                      label: 'Applications',
                      value: '$applied',
                      icon: Icons.assignment_outlined,
                      iconBgColor: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                      subtitle: applied == 0 ? 'None yet' : 'Track status',
                      onTap: () => AppNavigation.switchTab(AppTab.applied),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Skill Assessment Banner
                if (!_cachedHasAnyAssessment) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.cardBorderSoft),
                      boxShadow: tokens.cardShadows,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.quiz_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Boost Your Job Matches',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Take a 3-min adaptive assessment to prove verified skills.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _openAssessment,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Start',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Top Matches Section
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                color: Color(0xFFF59E0B),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Top Matches for You',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () =>
                                AppNavigation.switchTab(AppTab.jobs),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'View all',
                                  style: TextStyle(
                                    color: tokens.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: tokens.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (topMatches.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.work_off_outlined,
                                  size: 36,
                                  color: tokens.textFaint,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No open job matches yet.',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < topMatches.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _JobMatchCard(job: topMatches[i]),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Weekly Activity Section
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Weekly Activity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                          Text(
                            '$applied total applied',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Applications submitted over the last 7 days',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 150,
                        child: Semantics(
                          label:
                              'Bar chart showing applications submitted over the last 7 days',
                          excludeSemantics: true,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: BarChartPainter(
                              days: _cachedWeeklyLabels,
                              values: _cachedWeeklyActivity,
                              emptyBarColor: tokens.cardBorderSoft,
                              gridColor: tokens.cardBorderSoft,
                              labelColor: tokens.textSecondary,
                              todayColor: tokens.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String subtitle;
  final bool hasProgress;
  final double progress;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.subtitle = '',
    this.hasProgress = false,
    this.progress = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Material(
      color: tokens.cardBackground,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.cardBorderSoft),
            boxShadow: tokens.cardShadows,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      // Pastel backgrounds glare in dark mode; tint the
                      // icon color instead.
                      color: context.appColors.isDark
                          ? iconColor.withValues(alpha: 0.18)
                          : iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: tokens.textFaint,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  letterSpacing: -0.5,
                  color: tokens.textPrimary,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
              if (hasProgress) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: tokens.surfaceMuted,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ] else if (subtitle.isNotEmpty) ...[
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: tokens.textFaint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JobMatchCard extends StatelessWidget {
  final Job job;

  const _JobMatchCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Material(
      color: tokens.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          final applicantId =
              (SessionStore.user?['_id'] ?? SessionStore.user?['id'])
                  ?.toString();
          Navigator.push(
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
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.cardBorderSoft),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.cardBorderSoft),
                ),
                child: Center(
                  child: Text(
                    job.company.isNotEmpty
                        ? job.company.substring(0, 1).toUpperCase()
                        : 'J',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: tokens.primary,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${job.company}${job.location.isNotEmpty ? " • ${job.location}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MatchScoreBadge(
                score: job.matchPercentage,
                variant: MatchScoreBadgeVariant.pill,
                showLabel: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BarChartPainter extends CustomPainter {
  final List<String> days;
  final List<int> values;
  final Color emptyBarColor;
  final Color gridColor;
  final Color labelColor;
  final Color todayColor;

  BarChartPainter({
    required this.days,
    required this.values,
    this.emptyBarColor = const Color(0xFFF1F5F9),
    this.gridColor = const Color(0xFFF1F5F9),
    this.labelColor = AppColors.textSecondary,
    this.todayColor = AppColors.primary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint barPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint emptyBarPaint = Paint()..color = emptyBarColor;
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final TextPainter textPaint = TextPainter(textDirection: TextDirection.ltr);

    final maxValue = values.isEmpty
        ? 1.0
        : values
              .fold<int>(0, (m, v) => v > m ? v : m)
              .clamp(1, 1 << 30)
              .toDouble();

    final barWidth = size.width / (values.length * 2 + 1);
    final chartHeight = size.height * 0.70;
    final padding = size.height * 0.08;

    // Draw horizontal grid lines
    const gridDivisions = 3;
    for (int step = 0; step <= gridDivisions; step++) {
      final fraction = step / gridDivisions;
      final y = padding + (chartHeight * (1 - fraction));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw bars
    for (int i = 0; i < values.length; i++) {
      final barHeight = (chartHeight * values[i]) / maxValue;
      final x = barWidth * (2 * i + 1.2);
      final y = padding + chartHeight - barHeight;

      // Draw light background bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barWidth / 2, padding, barWidth, chartHeight),
          const Radius.circular(6),
        ),
        emptyBarPaint,
      );

      // Draw active value bar
      if (barHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - barWidth / 2, y, barWidth, barHeight),
            const Radius.circular(6),
          ),
          barPaint,
        );
      }

      final isToday = i == values.length - 1;
      final textSpan = TextSpan(
        text: days[i],
        style: TextStyle(
          color: isToday ? todayColor : labelColor,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          fontSize: 11,
        ),
      );
      textPaint.text = textSpan;
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(x - textPaint.width / 2, padding + chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(BarChartPainter oldDelegate) =>
      oldDelegate.values.toString() != values.toString() ||
      oldDelegate.days.toString() != days.toString() ||
      oldDelegate.emptyBarColor != emptyBarColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.todayColor != todayColor;
}
