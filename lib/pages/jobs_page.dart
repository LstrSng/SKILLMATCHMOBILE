import 'package:flutter/material.dart';
import 'job_detail_page.dart';
import 'settings_page.dart';
import '../services/jobs_api.dart';

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
      final raw = await fetchJobsRaw();
      final list = raw.map(Job.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _jobs = list;
        _loading = false;
        _error = null;
      });
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
    if (q.isEmpty) return _jobs;
    bool matches(Job j) {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'SkillMatch',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.black87),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Jobs',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                              hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF9CA3AF),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
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
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.tune, color: Colors.black87),
                            onPressed: () {},
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
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _visibleJobs
                            .map((job) => _JobCard(job: job))
                            .toList(),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;

  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailPage(
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
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
                    border: Border.all(color: const Color(0xFF0EA5A5)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${job.matchPercentage}%',
                    style: const TextStyle(
                      color: Color(0xFF0EA5A5),
                      fontWeight: FontWeight.w600,
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
                  job.jobType == 'Full-time'
                      ? Icons.schedule
                      : Icons.location_on,
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
            Text(
              'SKILL MATCH',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w600,
              ),
            ),
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
            Icons.check_circle,
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
}
