import 'package:flutter/material.dart';

import '../models/job_match_result.dart';
import '../services/applications_api.dart';
import '../services/job_match_api.dart';
import '../services/session_store.dart';
import 'settings_page.dart';
import '../widgets/notification_bell_button.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMatchResult();
  }

  String? get _resolvedApplicantId {
    final fromWidget = widget.applicantId?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;

    final user = SessionStore.user;
    final raw = user?['_id'] ?? user?['id'];
    final fromSession = raw?.toString().trim() ?? '';
    if (fromSession.isEmpty) return null;
    return fromSession;
  }

  Future<void> _loadMatchResult() async {
    final applicantId = _resolvedApplicantId;
    if (applicantId == null || applicantId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing applicant ID. Please sign in again and retry.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await fetchJobMatchResult(
        applicantId: applicantId,
        jobId: widget.jobId,
      );
      if (!mounted) return;
      setState(() {
        _matchResult = result;
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
            onBookmarkToggle: () {
              setState(() {
                _isBookmarked = !_isBookmarked;
              });
            },
          ),
          const SizedBox(height: 16),
          SkillMatchBreakdownCard(
            matchedSkills: result.matchedSkills,
            missingSkills: result.missingSkills,
          ),
          const SizedBox(height: 16),
          RecommendationCard(recommendation: result.recommendation),
          if (widget.description.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Job Description',
              child: Text(
                widget.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.55,
                ),
              ),
            ),
          ],
        ],
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
                      Text(
                        company,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
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
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: applying ? null : onApply,
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
  const RecommendationCard({super.key, required this.recommendation});

  final String recommendation;

  @override
  Widget build(BuildContext context) {
    final text = recommendation.trim().isEmpty
        ? 'You match all required skills for this job.'
        : recommendation.trim();

    return _InfoCard(
      title: 'Recommendation',
      child: Container(
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
                text,
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
