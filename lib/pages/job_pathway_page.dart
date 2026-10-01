import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/training_pathway.dart';
import '../services/competency.dart';
import '../services/completed_certs.dart';
import '../services/pathway_certification.dart';
import '../services/pathway_links_data.dart';
import '../services/prescriptive_engine.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/widgets.dart';

/// Upskilling pathway for one job: only the skills the applicant lacks or
/// has below the required PSF-SDS level, ranked by priority (see
/// [prescribeActions]), each with certifications that fit the level needed.
/// Skills the applicant already qualifies in are left out.
class JobPathwayPage extends StatefulWidget {
  const JobPathwayPage({
    super.key,
    required this.jobTitle,
    required this.qualifiedPercent,
    required this.actions,
    required this.qualifiedSkills,
  });

  final String jobTitle;
  final int qualifiedPercent;

  /// Upskilling actions, best first.
  final List<PrescribedAction> actions;

  /// Skills already at the required level (not part of the pathway).
  final List<String> qualifiedSkills;

  @override
  State<JobPathwayPage> createState() => _JobPathwayPageState();
}

class _JobPathwayPageState extends State<JobPathwayPage> {
  List<TrainingPathway>? _pathways;
  Set<String> _completedCerts = completedCertificationKeys();
  Set<String> _completedSteps = completedPathwayKeys();

  /// Saves a completion change optimistically, reverting on failure.
  Future<void> _save(
    String label,
    bool completed,
    VoidCallback apply,
    VoidCallback revert,
    Future<void> Function() persist, {
    String? completedMessage,
  }) async {
    HapticFeedback.selectionClick();
    setState(apply);
    try {
      await persist();
      if (!mounted) return;
      showAppToast(
        context,
        completed
            ? completedMessage ?? 'Marked "$label" as completed.'
            : 'Removed completed mark.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(revert);
      showAppToast(context, e.toString(), type: AppToastType.error);
    }
  }

  /// Completing a step first offers an optional certificate upload, then
  /// asks for the user's level in the skill (starting at their current
  /// rating, or 1 if they don't have it yet); both are saved to the
  /// profile. Undoing asks for confirmation and only clears the mark.
  Future<void> _toggleStep(SkillCompetency competency, bool completed) async {
    final skill = competency.skill;
    CertificationDraft? cert;
    int? level;
    if (completed) {
      final suggested = certificationsFor(
        _pathways ?? const [],
        skill,
        competency.required,
      ).firstOrNull;
      final upload = await showCertificationUploadSheet(
        context,
        skill: skill,
        suggestedTitle: suggested?.label,
        suggestedIssuer: suggested?.provider,
      );
      if (upload == null || !mounted) return;
      cert = upload.draft;
      level = await showSkillLevelSheet(
        context,
        skill: skill,
        initialLevel: _currentCompetency(competency).rating ?? 1,
        required: competency.required,
      );
      if (level == null || !mounted) return;
    } else {
      final remove = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove completed mark?'),
          content: Text(
            '"$skill" will no longer be marked as completed. Your skill level '
            'and any certificate you uploaded stay on your profile.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (remove != true || !mounted) return;
    }
    final previous = _completedSteps;
    final key = skill.toLowerCase();
    await _save(
      skill,
      completed,
      () => _completedSteps = {...previous}..toggle(key, add: completed),
      () => _completedSteps = previous,
      () async {
        if (cert != null) await addPathwayCertification(cert, skill: skill);
        if (level != null) await setMySkillLevel(skill, level);
        final keys = await setPathwayCompleted(
          name: skill,
          completed: completed,
        );
        if (mounted) setState(() => _completedSteps = keys);
      },
      completedMessage: cert == null
          ? 'Marked "$skill" as completed and updated your skills.'
          : 'Marked "$skill" as completed. Skill and certificate added to your profile.',
    );
  }

  /// [competency] re-assessed against the latest profile, so a level saved
  /// from this page shows up right away.
  SkillCompetency _currentCompetency(SkillCompetency competency) =>
      assessCompetencies([competency.raw], SessionStore.user).firstOrNull ??
      competency;

  void _toggleCert(String skill, TrainingResource link, bool completed) {
    final previous = _completedCerts;
    final key = link.label.trim().toLowerCase();
    _save(
      link.label,
      completed,
      () => _completedCerts = {...previous}..toggle(key, add: completed),
      () => _completedCerts = previous,
      () async {
        final keys = await setCertificationCompleted(
          link: link,
          pathwayName: skill,
          completed: completed,
        );
        if (mounted) setState(() => _completedCerts = keys);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    allTrainingPathways().then((p) {
      if (mounted) setState(() => _pathways = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final pathways = _pathways;

    return Scaffold(
      backgroundColor: tokens.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Upskilling Pathway'),
        backgroundColor: tokens.cardBackground,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          PageHeroHeader(
            icon: Icons.route_rounded,
            eyebrow: widget.jobTitle,
            title: 'Your upskilling pathway',
            subtitle: widget.actions.isEmpty
                ? 'You already meet every required skill level for this job.'
                : 'Focus on these ${widget.actions.length} skill${widget.actions.length == 1 ? '' : 's'}, highest priority first (qualification gain, other jobs that need it, relevance and cost). Skills you already qualify in are not included.',
            highlight: '${widget.qualifiedPercent}% qualified now',
          ),
          if (widget.qualifiedSkills.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Note(
              icon: Icons.verified_rounded,
              color: tokens.success,
              text:
                  'Already qualified (not included): ${widget.qualifiedSkills.join(', ')}',
            ),
          ],
          const SizedBox(height: 8),
          if (pathways == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final (i, action) in widget.actions.indexed)
              _StepCard(
                step: i + 1,
                action: action,
                competency: _currentCompetency(action.competency),
                certifications: certificationsFor(
                  pathways,
                  action.skill,
                  action.competency.required,
                ),
                completed: _completedSteps.contains(action.skill.toLowerCase()),
                completedCerts: _completedCerts,
                onToggle: (done) => _toggleStep(action.competency, done),
                onToggleCert: (link, done) =>
                    _toggleCert(action.skill, link, done),
              ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.action,
    required this.competency,
    required this.certifications,
    required this.completed,
    required this.completedCerts,
    required this.onToggle,
    required this.onToggleCert,
  });

  final int step;
  final PrescribedAction action;

  /// The applicant's standing on this skill as of the latest profile.
  final SkillCompetency competency;
  final List<TrainingResource> certifications;

  /// Whether this step's pathway is marked completed.
  final bool completed;
  final Set<String> completedCerts;
  final ValueChanged<bool> onToggle;
  final void Function(TrainingResource link, bool completed) onToggleCert;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final c = competency;
    final you = c.applicantDescription ?? 'Not in your skills yet';
    final meets = c.status == CompetencyStatus.meets;
    final needs = c.required?.label ?? 'Any level';

    return AppCard(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: step == 1 ? tokens.primary : tokens.primarySoftBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$step',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: step == 1 ? Colors.white : tokens.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.skill,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${action.matchGain}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: tokens.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LevelRow(
            label: 'You',
            value: you,
            color: meets ? tokens.success : tokens.warning,
          ),
          const SizedBox(height: 4),
          _LevelRow(label: 'Needs', value: needs, color: tokens.primary),
          const SizedBox(height: 12),
          if (certifications.isEmpty)
            _Note(
              icon: Icons.groups_rounded,
              color: tokens.textSecondary,
              text:
                  'No certification needed — build this skill through projects, teamwork and practice.',
            )
          else ...[
            Text(
              c.required != null && c.required!.minRating >= 6
                  ? 'Recommended certifications (professional level)'
                  : 'Recommended training (foundational level)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TrainingLinksList(
              pathway: TrainingPathway(
                name: action.skill,
                links: certifications,
                note: '',
              ),
              completedKeys: completedCerts,
              onToggleCompleted: onToggleCert,
            ),
          ],
          const SizedBox(height: 12),
          CompleteButton(
            completed: completed,
            onPressed: () => onToggle(!completed),
          ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: tokens.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

extension on Set<String> {
  /// Adds [key] when [add] is true, removes it otherwise.
  void toggle(String key, {required bool add}) =>
      add ? this.add(key) : remove(key);
}
