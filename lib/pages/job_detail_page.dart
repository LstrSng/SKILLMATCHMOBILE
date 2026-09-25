import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/job_match_result.dart';
import '../services/applications_api.dart';
import '../services/coding_challenge_bank.dart';
import '../models/training_pathway.dart';
import '../services/competency.dart';
import '../services/job_roles_data.dart';
import '../services/prescriptive_engine.dart';
import '../services/saved_jobs_store.dart';
import '../services/session_store.dart';
import '../widgets/coding_challenge_sheet.dart';
import 'company_details_page.dart';
import 'pathway_page.dart';
import 'settings_page.dart';
import 'skill_assessment_page.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/widgets.dart';

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

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  bool _isBookmarked = false;
  bool _applying = false;
  bool _loading = true;
  String? _error;
  JobMatchResult? _matchResult;
  List<PrescribedAction> _actions = const [];
  String? _csvDescription;

  /// Prioritize the employer's custom posting description, falling back
  /// to the PSF-SDS role description if none was provided.
  String get _displayDescription {
    final raw = widget.description.trim();
    if (raw.isNotEmpty) return raw;
    final csv = _csvDescription?.trim() ?? '';
    if (csv.isNotEmpty) return csv;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _checkIfApplied();
    _loadMatchResult();
    _loadBookmarkState();
  }

  bool _isApplied = false;

  Future<void> _checkIfApplied() async {
    if (widget.jobId.trim().isEmpty) return;
    try {
      final cached =
          memoryCachedApplications ?? await getCachedMyApplications();
      final match = cached.any((a) {
        final jId = (a['jobId'] as Object?)?.toString().trim() ?? '';
        if (jId != widget.jobId.trim()) return false;
        final status =
            (a['status'] as Object?)?.toString().trim().toLowerCase() ?? '';
        return status != 'withdrawn' && status != 'rejected';
      });
      if (mounted) setState(() => _isApplied = match);
    } catch (_) {}
  }

  Future<void> _loadBookmarkState() async {
    if (widget.jobId.trim().isEmpty) return;
    final saved = await SavedJobsStore.isSaved(widget.jobId);
    if (!mounted) return;
    setState(() => _isBookmarked = saved);
  }

  Future<void> _toggleBookmark() async {
    if (widget.jobId.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    final ids = await SavedJobsStore.toggle(widget.jobId);
    if (!mounted) return;
    final isSaved = ids.contains(widget.jobId);
    setState(() => _isBookmarked = isSaved);
    showAppToast(
      context,
      isSaved ? 'Job saved to your bookmarks.' : 'Job removed from bookmarks.',
      type: isSaved ? AppToastType.success : AppToastType.info,
    );
  }

  Future<void> _loadMatchResult() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final roles = await loadJobRoles();
      final role = findBestRoleForTitle(roles, widget.title);

      final competencies = assessCompetencies([
        ...widget.matchedSkills,
        ...widget.unmatchedSkills,
      ], SessionStore.user);
      // Same competency-weighted score as the Jobs list and action plan.
      final score = competencies.isEmpty
          ? widget.matchPercentage
          : competencyMatchPercent(competencies);
      final actions = await prescribeActions(
        jobTitle: widget.title,
        requiredSkills: [...widget.matchedSkills, ...widget.unmatchedSkills],
        user: SessionStore.user,
      );
      final result = JobMatchResult(
        jobTitle: widget.title,
        matchScore: score,
        matchedSkills: widget.matchedSkills,
        missingSkills: widget.unmatchedSkills,
        recommendation: prescriptionText(score: score, actions: actions),
      );

      if (!mounted) return;
      setState(() {
        _matchResult = result;
        _actions = actions;
        _csvDescription = role?.description;
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
    final totalSkills =
        (_matchResult?.matchedSkills.length ?? widget.matchedSkills.length) +
        (_matchResult?.missingSkills.length ?? widget.unmatchedSkills.length);
    if (totalSkills > 0 && _displayScore <= 0) {
      showAppToast(
        context,
        'You need to match at least 1 required skill to apply.',
        type: AppToastType.warning,
      );
      return;
    }

    Map<String, dynamic>? codingChallenge;
    if (isDeveloperRole(_displayTitle)) {
      final skills = SessionStore.user?['skills'];
      codingChallenge = await showCodingChallengeSheet(
        context,
        jobTitle: _displayTitle,
        userSkills: skills is List
            ? skills.map((e) => e.toString()).toList()
            : const [],
      );
      if (codingChallenge == null || !mounted) return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _applying = true);
    try {
      await applyToJob(
        jobId: widget.jobId,
        codingChallenge: codingChallenge,
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
      setState(() => _isApplied = true);
      showAppToast(
        context,
        'Application submitted successfully!',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, e.toString(), type: AppToastType.error);
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

  void _openSkillPathway(String skill) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PathwayPage(initialQuery: skill)),
    );
  }

  void _openSkillAssessment(String skill) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SkillAssessmentPage(initialSkill: skill),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return Scaffold(
      backgroundColor: tokens.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: tokens.cardBackground,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: tokens.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: tokens.primary.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.bolt, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'SkillMatch+',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: tokens.textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          const NotificationBellButton(),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(context),
      bottomNavigationBar:
          _loading || _matchResult == null || !widget.allowApply
          ? null
          : _JobDetailBottomBar(
              matchScore: _displayScore,
              isBookmarked: _isBookmarked,
              applying: _applying,
              isApplied: _isApplied,
              onApply: _applyNow,
              onBookmarkToggle: _toggleBookmark,
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const JobDetailSkeleton();
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
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Job Header Card
            JobHeaderCard(
              jobId: widget.jobId,
              title: _displayTitle,
              company: widget.company,
              location: widget.location,
              salary: widget.salary,
              jobType: widget.jobType,
              postedDate: widget.postedDate,
              matchScore: result.matchScore,
              onCompanyTap: widget.jobId.trim().isEmpty
                  ? null
                  : _openCompanyDetails,
            ),

            // Description Section
            if (_displayDescription.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              CollapsibleJobDescription(description: _displayDescription),
            ],
            const SizedBox(height: 16),

            // Interactive Skill Compatibility Matrix
            SkillCompatibilityMatrix(
              matchedSkills: result.matchedSkills,
              missingSkills: result.missingSkills,
              matchScore: result.matchScore,
              competencies: assessCompetencies([
                ...result.matchedSkills,
                ...result.missingSkills,
              ], SessionStore.user),
              onLearnSkill: _openSkillPathway,
              onTakeQuiz: _openSkillAssessment,
            ),
            const SizedBox(height: 16),

            // Recommendation Summary Card
            RecommendationCard(
              recommendation: result.recommendation,
              actions: _actions,
              onOpenAction: _openSkillPathway,
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible card for job descriptions, showing the first [trimLines] lines with a 'See more' toggle.
class CollapsibleJobDescription extends StatefulWidget {
  const CollapsibleJobDescription({
    super.key,
    required this.description,
    this.trimLines = 4,
  });

  final String description;
  final int trimLines;

  @override
  State<CollapsibleJobDescription> createState() =>
      _CollapsibleJobDescriptionState();
}

class _CollapsibleJobDescriptionState extends State<CollapsibleJobDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 18, color: tokens.primary),
              const SizedBox(width: 8),
              Text(
                'Job Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final textStyle = TextStyle(
                fontSize: 14,
                color: tokens.textSecondary,
                height: 1.55,
              );
              final span = TextSpan(text: widget.description, style: textStyle);
              final tp = TextPainter(
                text: span,
                maxLines: widget.trimLines,
                textDirection: Directionality.of(context),
              )..layout(maxWidth: constraints.maxWidth);

              final isOverflowing = tp.didExceedMaxLines;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topLeft,
                    child: Text(
                      widget.description,
                      style: textStyle,
                      maxLines: _isExpanded ? null : widget.trimLines,
                      overflow: _isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                  if (isOverflowing) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isExpanded = !_isExpanded);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isExpanded ? 'Show less' : 'See more',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tokens.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: tokens.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Header Card displaying company avatar, job title, metadata pills, and match score with Hero support.
class JobHeaderCard extends StatelessWidget {
  const JobHeaderCard({
    super.key,
    required this.jobId,
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.jobType,
    required this.postedDate,
    required this.matchScore,
    this.onCompanyTap,
  });

  final String jobId;
  final String title;
  final String company;
  final String location;
  final String salary;
  final String jobType;
  final String postedDate;
  final int matchScore;
  final VoidCallback? onCompanyTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    final metaItems = <Widget>[
      if (location.trim().isNotEmpty)
        _MetaPill(icon: Icons.location_on_outlined, label: location),
      if (salary.trim().isNotEmpty)
        _MetaPill(icon: Icons.attach_money_rounded, label: salary),
      if (jobType.trim().isNotEmpty)
        _MetaPill(icon: Icons.schedule_rounded, label: jobType),
      if (postedDate.trim().isNotEmpty)
        _MetaPill(icon: Icons.calendar_today_outlined, label: postedDate),
    ];

    final initial = company.trim().isNotEmpty
        ? company.trim()[0].toUpperCase()
        : 'J';

    return AppCard(
      animateScaleOnTap: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: tokens.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: tokens.textPrimary,
                      ),
                    ),
                    if (company.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: onCompanyTap,
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                company,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: onCompanyTap != null
                                      ? tokens.primary
                                      : tokens.textSecondary,
                                ),
                              ),
                            ),
                            if (onCompanyTap != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: tokens.primary,
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
              MatchScoreBadge(
                score: matchScore,
                variant: MatchScoreBadgeVariant.circular,
                size: 54,
                animate: false,
              ),
            ],
          ),
          if (metaItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: metaItems),
          ],
        ],
      ),
    );
  }
}

/// Filter mode for the Skill Compatibility Matrix.
enum _SkillMatrixFilter { all, matched, missing }

/// An interactive, elevated Skill Compatibility Matrix breaking down matched vs. missing skills,
/// providing 1-tap quick actions to learn pathways or take proficiency quizzes.
class SkillCompatibilityMatrix extends StatefulWidget {
  const SkillCompatibilityMatrix({
    super.key,
    required this.matchedSkills,
    required this.missingSkills,
    required this.matchScore,
    this.competencies,
    this.onLearnSkill,
    this.onTakeQuiz,
  });

  final List<String> matchedSkills;
  final List<String> missingSkills;
  final int matchScore;

  /// Applicant's level vs. the PSF-SDS level required for each skill (see
  /// [assessCompetencies]); rows show both when given.
  final List<SkillCompetency>? competencies;
  final ValueChanged<String>? onLearnSkill;
  final ValueChanged<String>? onTakeQuiz;

  @override
  State<SkillCompatibilityMatrix> createState() =>
      _SkillCompatibilityMatrixState();
}

class _SkillCompatibilityMatrixState extends State<SkillCompatibilityMatrix> {
  _SkillMatrixFilter _filter = _SkillMatrixFilter.all;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final totalSkills =
        widget.matchedSkills.length + widget.missingSkills.length;
    final byRaw = {for (final c in widget.competencies ?? const []) c.raw: c};
    SkillCompetency? competencyFor(String skill) => byRaw[skill];
    final belowCount = byRaw.values
        .where((c) => c.status == CompetencyStatus.belowLevel)
        .length;

    final displayedMatched =
        (_filter == _SkillMatrixFilter.all ||
            _filter == _SkillMatrixFilter.matched)
        ? widget.matchedSkills
        : <String>[];
    final displayedMissing =
        (_filter == _SkillMatrixFilter.all ||
            _filter == _SkillMatrixFilter.missing)
        ? widget.missingSkills
        : <String>[];

    return AppCard(
      animateScaleOnTap: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 20, color: tokens.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Skill Compatibility Matrix',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Overview Stat Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.cardBorderSoft),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: tokens.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      belowCount == 0
                          ? '${widget.matchedSkills.length} Matched'
                          : '${widget.matchedSkills.length - belowCount} Matched · $belowCount Below level',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: tokens.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.missingSkills.length} Missing Gaps',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$totalSkills Required',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Segmented Filter Tabs
          Row(
            children: [
              _buildFilterTab(
                context,
                label:
                    'All (${widget.matchedSkills.length + widget.missingSkills.length})',
                filter: _SkillMatrixFilter.all,
              ),
              const SizedBox(width: 8),
              _buildFilterTab(
                context,
                label: 'Matched (${widget.matchedSkills.length})',
                filter: _SkillMatrixFilter.matched,
                accentColor: tokens.success,
              ),
              const SizedBox(width: 8),
              _buildFilterTab(
                context,
                label: 'Missing (${widget.missingSkills.length})',
                filter: _SkillMatrixFilter.missing,
                accentColor: tokens.danger,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Skills List Content
          if (displayedMatched.isEmpty && displayedMissing.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No skills in this category.',
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                ),
              ),
            )
          else ...[
            ...displayedMatched.map(
              (skill) => _MatchedSkillRow(
                skill: skill,
                competency: competencyFor(skill),
              ),
            ),
            ...displayedMissing.map(
              (skill) => _MissingSkillRow(
                competency: competencyFor(skill),
                skill: skill,
                onLearn: widget.onLearnSkill != null
                    ? () => widget.onLearnSkill!(skill)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterTab(
    BuildContext context, {
    required String label,
    required _SkillMatrixFilter filter,
    Color? accentColor,
  }) {
    final tokens = context.appColors;
    final isSelected = _filter == filter;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _filter = filter);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (accentColor?.withValues(alpha: 0.12) ?? tokens.primarySoftBg)
                : tokens.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? (accentColor ?? tokens.primary)
                  : tokens.cardBorderSoft,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? (accentColor ?? tokens.primary)
                    : tokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Required: Level 3 · You: Level 2" under a skill in the matrix.
class _LevelLine extends StatelessWidget {
  const _LevelLine({required this.competency});

  final SkillCompetency competency;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final required = competency.required;
    final you = competency.applicantLevel;
    final text = [
      if (required != null) 'Required: ${required.label}',
      you != null ? 'You: $you' : 'You: not in your skills',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}

class _MatchedSkillRow extends StatelessWidget {
  const _MatchedSkillRow({required this.skill, this.competency});

  final String skill;
  final SkillCompetency? competency;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final isDark = context.isDarkMode;
    final belowLevel = competency?.status == CompetencyStatus.belowLevel;
    final badgeColor = belowLevel ? tokens.warning : tokens.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.cardBorderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkillChip(
                  label: competency?.skill ?? skill,
                  status: belowLevel
                      ? SkillChipStatus.neutral
                      : SkillChipStatus.matched,
                  size: SkillChipSize.medium,
                ),
                if (competency != null) _LevelLine(competency: competency!),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: belowLevel
                  ? tokens.warningBg
                  : AppColors.matchBgColor(100, isDark: isDark),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: belowLevel
                    ? tokens.warning.withValues(alpha: 0.4)
                    : AppColors.matchBorderColor(100, isDark: isDark),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  belowLevel
                      ? Icons.trending_up_rounded
                      : Icons.check_circle_rounded,
                  size: 12,
                  color: badgeColor,
                ),
                const SizedBox(width: 4),
                Text(
                  belowLevel ? 'Below level' : 'Matched',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingSkillRow extends StatelessWidget {
  const _MissingSkillRow({required this.skill, this.competency, this.onLearn});

  final String skill;
  final SkillCompetency? competency;
  final VoidCallback? onLearn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1719) : const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF5A2020) : const Color(0xFFFECACA),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkillChip(
                  label: competency?.skill ?? skill,
                  status: SkillChipStatus.missing,
                  isMissingAlert: true,
                  size: SkillChipSize.medium,
                ),
                if (competency != null) _LevelLine(competency: competency!),
              ],
            ),
          ),
          // The level line already says the skill is missing.
          if (competency == null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.matchBgColor(0, isDark: isDark),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.matchBorderColor(0, isDark: isDark),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 12,
                    color: tokens.danger,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Skill Gap',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onLearn != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onLearn!();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: tokens.primarySoftBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: tokens.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.explore_outlined,
                      size: 13,
                      color: tokens.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Learn',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tokens.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 13,
                      color: tokens.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sticky bottom action bar for thumb-friendly Application and Bookmarking.
class _JobDetailBottomBar extends StatelessWidget {
  const _JobDetailBottomBar({
    required this.matchScore,
    required this.isBookmarked,
    required this.applying,
    this.isApplied = false,
    required this.onApply,
    required this.onBookmarkToggle,
  });

  final int matchScore;
  final bool isBookmarked;
  final bool applying;
  final bool isApplied;
  final VoidCallback onApply;
  final VoidCallback onBookmarkToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 6
            : 14,
      ),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        border: Border(top: BorderSide(color: tokens.cardBorderSoft)),
        boxShadow: tokens.cardShadows,
      ),
      child: Row(
        children: [
          // Bookmark Button
          InkWell(
            onTap: onBookmarkToggle,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isBookmarked
                    ? tokens.primarySoftBg
                    : tokens.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isBookmarked ? tokens.primary : tokens.cardBorderSoft,
                  width: 1.2,
                ),
              ),
              child: Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isBookmarked ? tokens.primary : tokens.textSecondary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Primary Apply Now Button
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApplied
                      ? tokens.success
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isApplied
                      ? tokens.success.withValues(alpha: 0.8)
                      : AppColors.primary.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (applying || isApplied) ? null : onApply,
                child: applying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isApplied
                                ? 'Applied'
                                : (matchScore <= 0
                                      ? 'Boost Match to Apply'
                                      : 'Apply Now'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isApplied
                                ? Icons.check_circle_rounded
                                : (matchScore <= 0
                                      ? Icons.lock_outline_rounded
                                      : Icons.arrow_forward_rounded),
                            size: 18,
                          ),
                        ],
                      ),
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
    this.actions = const [],
    this.onOpenAction,
  });

  final String recommendation;

  /// Ranked actions from [prescribeActions]; shown as an action plan.
  final List<PrescribedAction> actions;

  /// Opens the certifications for an action's skill.
  final ValueChanged<String>? onOpenAction;

  static const _kPlaceholders = {
    '',
    'no recommendation available.',
    'no recommendation available',
  };

  bool get _hasRecommendation =>
      !_kPlaceholders.contains(recommendation.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    if (!_hasRecommendation) return const SizedBox.shrink();
    final tokens = context.appColors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: tokens.primary),
              const SizedBox(width: 8),
              Text(
                'Smart Match Recommendation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.primarySoftBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.cardBorderSoft),
            ),
            child: Text(
              recommendation.trim(),
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actions.length > 1) ...[
            const SizedBox(height: 14),
            Text(
              'Action plan (ranked by impact)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, a) in actions.take(3).indexed)
              _ActionRow(
                rank: i + 1,
                action: a,
                onTap: onOpenAction == null
                    ? null
                    : () => onOpenAction!(a.skill),
              ),
          ],
        ],
      ),
    );
  }
}

/// One ranked action: skill, match change, reach and certification cost.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.rank, required this.action, this.onTap});

  final int rank;
  final PrescribedAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final cert = action.certification;
    final details = [
      if (action.levelChange != null) action.levelChange!,
      'match ${action.currentScore}% → ${action.newScore}%',
      if (action.otherJobs.isNotEmpty)
        '+${action.otherJobs.length} other job${action.otherJobs.length == 1 ? '' : 's'}',
      if (cert == null)
        'no cert needed'
      else
        switch (cert.cost) {
          TrainingCost.free => 'free cert',
          TrainingCost.freeToLearn => 'free to learn',
          TrainingCost.paid => cert.pesoPrice ?? 'paid cert',
        },
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank == 1 ? tokens.primary : tokens.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: rank == 1 ? Colors.white : tokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.isLevelUp ? '↑ Raise ${action.skill}' : action.skill,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    details,
                    style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.textFaint,
                size: 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.cardBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tokens.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _StatusCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 36, color: tokens.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
