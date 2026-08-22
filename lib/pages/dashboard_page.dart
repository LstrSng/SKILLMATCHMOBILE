import 'package:flutter/material.dart';
import 'applications_page.dart';
import 'job_detail_page.dart';
import 'jobs_page.dart';
import 'skill_assessment_page.dart';
import '../services/applications_api.dart';
import '../services/job_skill_matcher.dart';
import '../services/jobs_api.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';
import '../services/skill_assessment_engine.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';

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
      final results = await Future.wait([
        fetchMyProfile(),
        fetchJobsRaw(),
        fetchMyApplications(),
      ]);
      if (!mounted) return;
      final profile = results[0] as Map<String, dynamic>;
      final rawJobs = (results[1] as List<Map<String, dynamic>>)
          .map(Job.fromJson)
          .toList();
      final applications = (results[2] as List<Map<String, dynamic>>)
          .map(JobApplication.fromJson)
          .toList();
      final jobs = applyOwnSkillMatch(
        jobs: rawJobs,
        mySkillKeys: readMySkillKeys(profile),
      );
      setState(() {
        _profile = profile;
        _jobs = jobs;
        _applications = applications;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep showing whatever we already have (e.g. the cached session
      // profile) instead of blocking the whole dashboard on one failed call.
      setState(() {
        _loading = false;
        _error = e.toString();
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
    final hasResume = profileData is Map && profileData['resume'] is Map;

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

  /// Application counts for the last 7 calendar days (oldest to newest).
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
    final name = _greetingName();
    final applied = _applications.length;
    final matches = _jobs.length;
    final avgMatch = _averageMatch();
    final profileCompletion = _profileCompletion();
    final topMatches = _topMatches();

    return Scaffold(
      // backgroundColor: uses theme
      appBar: const AppTopBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Here\'s your career optimization overview.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_error != null) ...[
                  Text(
                    'Some data could not be refreshed: $_error',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 600
                      ? 4
                      : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _StatCard(
                      label: 'Profile',
                      value: '${(profileCompletion * 100).round()}%',
                      icon: Icons.trending_up,
                      hasProgress: true,
                      progress: profileCompletion,
                      subtitle: '',
                    ),
                    _StatCard(
                      label: 'Matches',
                      value: '$matches',
                      icon: Icons.business,
                      subtitle: matches == 0 ? 'No jobs yet' : 'Available now',
                    ),
                    _StatCard(
                      label: 'Avg Match',
                      value: _jobs.isEmpty ? '—' : '$avgMatch%',
                      icon: Icons.flash_on,
                      subtitle: _jobs.isEmpty ? '' : 'Across $matches jobs',
                    ),
                    _StatCard(
                      label: 'Applied',
                      value: '$applied',
                      icon: Icons.business_center,
                      subtitle: applied == 0 ? 'None yet' : 'Total submitted',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (!_hasAnyAssessment()) ...[
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.quiz_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Find your skill level',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Take a short adaptive quiz to improve your job matches.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _openAssessment,
                          child: const Text('Start'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Top Matches',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const JobsPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'View all',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (topMatches.isEmpty)
                        Text(
                          'No job matches yet. Check back soon.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF6B7280)),
                        )
                      else
                        for (var i = 0; i < topMatches.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _JobMatchCard(job: topMatches[i]),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Activity',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Applications submitted over the last 7 days',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 160,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: BarChartPainter(
                            days: _weeklyLabels(),
                            values: _weeklyActivity(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 100),
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
  final String subtitle;
  final bool hasProgress;
  final double progress;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.subtitle,
    this.hasProgress = false,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: Colors.white, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          if (hasProgress) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ] else if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _JobMatchCard extends StatelessWidget {
  final Job job;

  const _JobMatchCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final applicantId =
            (SessionStore.user?['_id'] ?? SessionStore.user?['id'])?.toString();
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
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5A5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${job.matchPercentage}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BarChartPainter extends CustomPainter {
  final List<String> days;
  final List<int> values;

  BarChartPainter({required this.days, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint barPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2;

    final Paint gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    final TextPainter textPaint = TextPainter(textDirection: TextDirection.ltr);

    final maxValue = values.isEmpty
        ? 1.0
        : values
              .fold<int>(0, (m, v) => v > m ? v : m)
              .clamp(1, 1 << 30)
              .toDouble();

    final barWidth = size.width / (values.length * 2 + 2);
    final chartHeight = size.height * 0.75;
    final padding = size.height * 0.1;

    // Draw grid lines: always 4 evenly spaced steps from 0 to maxValue, so
    // the labels line up with the real scale no matter how big it gets.
    const gridDivisions = 4;
    for (int step = 0; step <= gridDivisions; step++) {
      final fraction = step / gridDivisions;
      final y = padding + (chartHeight * (1 - fraction));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      final label = (maxValue * fraction).round();
      final textSpan = TextSpan(
        text: '$label',
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
      );
      textPaint.text = textSpan;
      textPaint.layout();
      textPaint.paint(canvas, Offset(-20, y - 6));
    }

    // Draw bars and labels
    for (int i = 0; i < values.length; i++) {
      final barHeight = (chartHeight * values[i]) / maxValue;
      final x = barWidth * (2 * i + 1.5);
      final y = padding + chartHeight - barHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barWidth / 2, y, barWidth, barHeight),
          const Radius.circular(4),
        ),
        barPaint,
      );

      final textSpan = TextSpan(
        text: days[i],
        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      );
      textPaint.text = textSpan;
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(x - textPaint.width / 2, padding + chartHeight + 5),
      );
    }
  }

  @override
  bool shouldRepaint(BarChartPainter oldDelegate) =>
      oldDelegate.values.toString() != values.toString() ||
      oldDelegate.days.toString() != days.toString();
}
