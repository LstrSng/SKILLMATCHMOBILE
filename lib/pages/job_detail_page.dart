import 'package:flutter/material.dart';

import '../models/job_match_result.dart';
import '../models/training_pathway.dart';
import '../services/applications_api.dart';
import '../services/job_roles_data.dart';
import '../services/job_skill_matcher.dart';
import '../services/pathway_links_data.dart';
import '../services/saved_jobs_store.dart';
import '../services/session_store.dart';
import 'company_details_page.dart';
import 'settings_page.dart';
import '../widgets/centered_form_width.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/training_pathway_card.dart';

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({
    super.key,
    required this.jobId,
    this.applicantId,
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.jobType,
    required this.postedDate,
    required this.matchPercentage,
    required this.description,
    required this.matchedSkills,
    required this.unmatchedSkills,
    this.allowApply = true,
    this.backLabel = 'Back to Jobs',
  });

  final String jobId;
  final String? applicantId;
  final String title;
  final String company;
  final String location;
  final String salary;
  final String jobType;
  final String postedDate;
  final int matchPercentage;
  final String description;
  final List<String> matchedSkills;
  final List<String> unmatchedSkills;
  final bool allowApply;
  final String backLabel;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  bool _isBookmarked = false;
  bool _applying = false;
  bool _loading = true;
  String? _error;
  JobMatchResult? _matchResult;
  TrainingPathway? _trainingPathway;
  String? _csvDescription;

  /// The CSV role's own description when a role match was found, falling
  /// back to whatever description the caller passed in (from the backend
  /// job listing or a saved application snapshot).
  String get _displayDescription {
    final csv = _csvDescription?.trim() ?? '';
    if (csv.isNotEmpty) return csv;
    return widget.description;
  }

  @override
  void initState() {
    super.initState();
    _loadMatchResult();
    _loadBookmarkState();
  }

  Future<void> _loadBookmarkState() async {
    if (widget.jobId.trim().isEmpty) return;
    final saved = await SavedJobsStore.isSaved(widget.jobId);
    if (!mounted) return;
    setState(() => _isBookmarked = saved);
  }

  Future<void> _toggleBookmark() async {
    if (widget.jobId.trim().isEmpty) return;
    final ids = await SavedJobsStore.toggle(widget.jobId);
    if (!mounted) return;
    setState(() => _isBookmarked = ids.contains(widget.jobId));
  }

  /// Builds the skill match breakdown the same way as the Jobs list and
  /// Dashboard: the job's title is matched to a canonical role in the
  /// bundled IT_Job_Roles_Skills CSV, and that role's skills are split
  /// matched/unmatched against the signed-in user's own profile skills.
  /// This keeps the number shown here consistent with every other screen
  /// that shows a match percentage for the same job.
  Future<void> _loadMatchResult() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final roles = await loadJobRoles();
      final role = findBestRoleForTitle(roles, widget.title);
      final mySkills = readMySkillKeys(SessionStore.user);

      var matched = const <String>[];
      var missing = const <String>[];
      var score = widget.matchPercentage;

      if (role != null && role.skills.isNotEmpty) {
        final split = splitSkillsByOwnership(role.skills, mySkills);
        matched = split.matched;
        missing = split.unmatched;
        score = (matched.length / role.skills.length * 100).round();
      }

      final result = JobMatchResult(
        jobTitle: widget.title,
        matchScore: score,
        matchedSkills: matched,
        missingSkills: missing,
        recommendation: _recommendationFor(score, missing),
      );

      if (!mounted) return;
      setState(() {
        _matchResult = result;
        _csvDescription = role?.description;
        _loading = false;
      });
      _loadTrainingPathway(widget.title);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  static String _recommendationFor(int score, List<String> missing) {
    if (score >= 80) return 'Great fit — you match most required skills.';
    if (score >= 50) {
      return 'Good fit — consider learning a few missing skills to improve your chances.';
    }
    if (score > 0) {
      return 'Low match — consider gaining experience in ${missing.take(3).join(', ')}.';
    }
    return 'No recommendation available.';
  }

  Future<void> _loadTrainingPathway(String roleTitle) async {
    final pathway = await trainingPathwayForRole(roleTitle);
    if (!mounted) return;
    setState(() => _trainingPathway = pathway);
  }

  Future<void> _applyNow() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      await applyToJob(
        jobId: widget.jobId,
        jobSnapshot: {
          'title': _displayTitle,
          'company': widget.company,
          'location': widget.location,
          'salary': widget.salary,
          'jobType': widget.jobType,
          'postedDate': widget.postedDate,
          'matchPercentage': _displayScore,
          'description': _displayDescription,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application submitted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  String get _displayTitle {
    final title = _matchResult?.jobTitle.trim() ?? '';
    if (title.isNotEmpty) return title;
    return widget.title;
  }

  int get _displayScore => _matchResult?.matchScore ?? widget.matchPercentage;

  void _openCompanyDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyDetailsPage(jobId: widget.jobId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'SkillMatch',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          const NotificationBellButton(iconColor: Colors.black54),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _StatusCard(
            title: 'Could not load job details',
            message: _error!,
            actionLabel: 'Retry',
            onPressed: _loadMatchResult,
          ),
        ),
      );
    }

    final result = _matchResult;
    if (result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _StatusCard(
            title: 'No analytics available',
            message: 'Try refreshing this job to load your match details.',
            actionLabel: 'Refresh',
            onPressed: _loadMatchResult,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: CenteredFormWidth(
        maxWidth: 700,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back,
                color: Color(0xFF6B7280),
                size: 18,
              ),
              label: Text(
                widget.backLabel,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            JobHeaderCard(
              title: _displayTitle,
              company: widget.company,
              location: widget.location,
              salary: widget.salary,
              jobType: widget.jobType,
              postedDate: widget.postedDate,
              matchScore: result.matchScore,
              isBookmarked: _isBookmarked,
              allowApply: widget.allowApply,
              applying: _applying,
              onApply: _applyNow,
              onBookmarkToggle: _toggleBookmark,
              onCompanyTap: widget.jobId.trim().isEmpty
                  ? null
                  : _openCompanyDetails,
            ),
            if (_displayDescription.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Job Description',
                child: Text(
                  _displayDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                    height: 1.55,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SkillMatchBreakdownCard(
              matchedSkills: result.matchedSkills,
              missingSkills: result.missingSkills,
            ),
            const SizedBox(height: 16),
            RecommendationCard(
              recommendation: result.recommendation,
              trainingPathway: _trainingPathway,
            ),
          ],
        ),
      ),
    );
  }
}

class JobHeaderCard extends StatelessWidget {
  const JobHeaderCard({
    super.key,
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.jobType,
    required this.postedDate,
    required this.matchScore,
    required this.isBookmarked,
    required this.allowApply,
    required this.applying,
    required this.onApply,
    required this.onBookmarkToggle,
    this.onCompanyTap,
  });

  final String title;
  final String company;
  final String location;
  final String salary;
  final String jobType;
  final String postedDate;
  final int matchScore;
  final bool isBookmarked;
  final bool allowApply;
  final bool applying;
  final VoidCallback onApply;
  final VoidCallback onBookmarkToggle;
  final VoidCallback? onCompanyTap;

  @override
  Widget build(BuildContext context) {
    final metaItems = <Widget>[
      if (location.trim().isNotEmpty)
        _MetaPill(icon: Icons.location_on_outlined, label: location),
      if (salary.trim().isNotEmpty)
        _MetaPill(icon: Icons.attach_money, label: salary),
      if (jobType.trim().isNotEmpty)
        _MetaPill(icon: Icons.schedule_outlined, label: jobType),
      if (postedDate.trim().isNotEmpty)
        _MetaPill(icon: Icons.calendar_today_outlined, label: postedDate),
    ];

    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (company.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: onCompanyTap,
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              company,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: onCompanyTap != null
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            if (onCompanyTap != null) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Color(0xFF2563EB),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '$matchScore%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF0F766E),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Match',
                      style: TextStyle(
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (metaItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: metaItems),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insights_outlined,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Job Match Score',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$matchScore% Match',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF0F766E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (allowApply) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (applying || matchScore <= 0) ? null : onApply,
                    child: applying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Apply Now',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: onBookmarkToggle,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
            if (matchScore <= 0) ...[
              const SizedBox(height: 8),
              Text(
                "You don't match any required skills for this job yet, so you can't apply.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class SkillMatchBreakdownCard extends StatelessWidget {
  const SkillMatchBreakdownCard({
    super.key,
    required this.matchedSkills,
    required this.missingSkills,
  });

  final List<String> matchedSkills;
  final List<String> missingSkills;

  @override
  Widget build(BuildContext context) {
    final totalSkills = matchedSkills.length + missingSkills.length;
    final skillRows = [
      ...matchedSkills.map((skill) => SkillRow(skill: skill, matched: true)),
      ...missingSkills.map((skill) => SkillRow(skill: skill, matched: false)),
    ];

    return _InfoCard(
      title: 'Skill Match Breakdown',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${matchedSkills.length} of $totalSkills skills matched',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (skillRows.isEmpty)
            Text(
              'No skill analytics are available for this job yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
            )
          else
            Column(
              children: skillRows
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: row,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class SkillRow extends StatelessWidget {
  const SkillRow({super.key, required this.skill, required this.matched});

  final String skill;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    final accent = matched ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final badgeBg = matched ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              matched ? Icons.check : Icons.close,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              skill,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              matched ? 'Matched' : 'Missing',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.trainingPathway,
  });

  final String recommendation;
  final TrainingPathway? trainingPathway;

  static const _kPlaceholders = {
    '',
    'no recommendation available.',
    'no recommendation available',
  };

  bool get _hasRecommendation =>
      !_kPlaceholders.contains(recommendation.trim().toLowerCase());

  bool get _hasLinks => trainingPathway?.links.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final showRecommendation = _hasRecommendation;
    final showLinks = _hasLinks;
    if (!showRecommendation && !showLinks) return const SizedBox.shrink();

    return _InfoCard(
      title: 'Recommendation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showRecommendation)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: Color(0xFF0F766E),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      recommendation.trim(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF134E4A),
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (showLinks) ...[
            if (showRecommendation) const SizedBox(height: 16),
            TrainingLinksList(pathway: trainingPathway!),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onPressed,
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
