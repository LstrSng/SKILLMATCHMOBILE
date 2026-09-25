import '../models/training_pathway.dart';
import 'competency.dart';
import 'pathway_links_data.dart';
import 'skill_gap_data.dart';

/// Prescriptive analytics for a job's skill gaps, aligned with the PSF-SDS
/// competency levels the job requires (see competency.dart).
///
/// Every required skill the user lacks, or has below the required level,
/// is a possible action: learn it, or raise it to the required level. The
/// engine simulates each action's outcome and scores it:
///
/// | Factor           | Measure                                           | Weight |
/// |------------------|---------------------------------------------------|--------|
/// | Match gain       | % points this job's competency match rises        | × 1    |
/// | Reach            | other posted jobs with the same gap               | × 5    |
/// | Role relevance   | skill fits the job's role (see selectPrimary...)  | + 10   |
/// | Cost             | best certification: free +5, free to learn +2     |        |
///
/// Actions are ranked by the total. Each gets the certification that fits
/// the required level: foundational training (TESDA, free) for Level 1–3 /
/// Basic–Intermediate, professional certifications for Level 4–6 / Advanced.
class PrescribedAction {
  const PrescribedAction({
    required this.competency,
    required this.currentScore,
    required this.newScore,
    required this.otherJobs,
    required this.roleRelevant,
    required this.certification,
    required this.priority,
  });

  /// The applicant's standing on the skill this action improves.
  final SkillCompetency competency;
  final int currentScore;

  /// This job's match score after the action.
  final int newScore;

  /// Other posted jobs with the same gap.
  final List<String> otherJobs;
  final bool roleRelevant;

  /// Certification that fits the required level, or null if none (e.g.
  /// soft skills).
  final TrainingResource? certification;
  final int priority;

  String get skill => competency.skill;
  int get matchGain => newScore - currentScore;

  /// True when the user has the skill but below the required level.
  bool get isLevelUp => competency.status == CompetencyStatus.belowLevel;

  /// e.g. "Level 2 → Level 3", or "→ Level 3" when the skill is missing.
  String? get levelChange {
    final required = competency.required;
    if (required == null) return null;
    return '${competency.applicantLevel ?? ''} → ${required.label}'.trim();
  }
}

const _kReachWeight = 5;
const _kRelevanceBonus = 10;

int _costBonus(TrainingResource? cert) => switch (cert?.cost) {
  TrainingCost.free => 5,
  TrainingCost.freeToLearn => 2,
  _ => 0,
};

/// Whether a required level calls for professional certification
/// (PSF Level 4+ or Advanced) rather than foundational training.
bool _isAdvanced(RequiredLevel? level) => (level?.minRating ?? 0) >= 6;

/// Ranks certifications for a skill by fit with its required level.
int _certRank(TrainingResource l, {required bool advanced}) {
  final tesda = (l.provider ?? '').toLowerCase().contains('tesda') ? 0 : 1;
  if (advanced) {
    // Professional (paid) certifications first, then free-to-learn, free.
    return (2 - l.cost.index) * 10 + tesda;
  }
  return tesda * 10 + l.cost.index;
}

/// Certifications from the pathways dataset for [skill], best fit for
/// [level] first (see [_certRank]), at most [limit].
List<TrainingResource> certificationsFor(
  List<TrainingPathway> pathways,
  String skill,
  RequiredLevel? level, {
  int limit = 3,
}) {
  final advanced = _isAdvanced(level);
  final seen = <String>{};
  final certs =
      [
        for (final p in pathwaysForSkill(pathways, skill))
          for (final l in p.links)
            if (seen.add(l.url + l.label)) l,
      ]..sort(
        (a, b) => _certRank(
          a,
          advanced: advanced,
        ).compareTo(_certRank(b, advanced: advanced)),
      );
  return certs.take(limit).toList();
}

/// Certification from the pathways dataset that fits [skill] at [level].
TrainingResource? bestCertificationFor(
  List<TrainingPathway> pathways,
  String skill,
  RequiredLevel? level,
) {
  final certs = certificationsFor(pathways, skill, level, limit: 1);
  return certs.isEmpty ? null : certs.first;
}

/// Whether [skill] fits the job's role domain. Pairs it with a placeholder
/// so [selectPrimaryPrescriptionSkill]'s "first skill" fallback doesn't
/// count as relevance.
bool _isRoleRelevant(String skill, String jobTitle) =>
    selectPrimaryPrescriptionSkill(['\u0000', skill], jobTitle: jobTitle) ==
    skill;

/// Ranks the actions for a job — learning each missing skill or raising
/// each below-level one — best first.
Future<List<PrescribedAction>> prescribeActions({
  required String jobTitle,
  String jobId = '',
  required List<String> requiredSkills,
  required Map<String, dynamic>? user,
}) async {
  final competencies = assessCompetencies(requiredSkills, user);
  final gapsHere = competencies
      .where((c) => c.status != CompetencyStatus.meets)
      .toList();
  if (gapsHere.isEmpty) return const [];
  final current = competencyMatchPercent(competencies);

  final pathways = await allTrainingPathways();
  List<SkillGap> gaps;
  try {
    gaps = await loadSkillGapsFromPostedJobs();
  } catch (_) {
    gaps = const []; // Offline: rank without the reach factor.
  }

  final actions = <PrescribedAction>[];
  for (final c in gapsHere) {
    // Simulate the action: this requirement becomes fully met.
    final after = competencyMatchPercent([
      for (final other in competencies)
        identical(other, c)
            ? SkillCompetency(
                raw: c.raw,
                skill: c.skill,
                required: c.required,
                rating: 10,
                status: CompetencyStatus.meets,
              )
            : other,
    ]);
    final gap = gaps.where(
      (g) => g.skill.toLowerCase() == c.skill.toLowerCase(),
    );
    final otherJobs = gap.isEmpty
        ? const <String>[]
        : [
            // Exclude this job by id (postings can share a title).
            for (final (i, title) in gap.first.jobTitles.indexed)
              if (jobId.isNotEmpty && i < gap.first.jobIds.length
                  ? gap.first.jobIds[i] != jobId
                  : title != jobTitle)
                title,
          ];
    final cert = bestCertificationFor(pathways, c.skill, c.required);
    final relevant = _isRoleRelevant(c.raw, jobTitle);

    actions.add(
      PrescribedAction(
        competency: c,
        currentScore: current,
        newScore: after,
        otherJobs: otherJobs,
        roleRelevant: relevant,
        certification: cert,
        priority:
            (after - current) +
            _kReachWeight * otherJobs.length +
            (relevant ? _kRelevanceBonus : 0) +
            _costBonus(cert),
      ),
    );
  }
  // Stable sort keeps the job's own skill order on ties.
  final indexed = actions.indexed.toList()
    ..sort((a, b) {
      final byPriority = b.$2.priority.compareTo(a.$2.priority);
      return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
    });
  return [for (final (_, a) in indexed) a];
}

String _fitLabel(int score) {
  if (score >= 85) return 'Great fit';
  if (score >= 70) return 'Good fit';
  if (score >= 50) return 'Moderate fit';
  return 'Skill gap detected';
}

String _costText(TrainingResource cert) => switch (cert.cost) {
  TrainingCost.free => 'Free',
  TrainingCost.freeToLearn => 'free to learn',
  TrainingCost.paid => cert.pesoPrice ?? 'paid',
};

/// The Smart Match Recommendation sentence for a job, built from the
/// top-ranked action.
String prescriptionText({
  required int score,
  required List<PrescribedAction> actions,
}) {
  if (actions.isEmpty) {
    return 'Outstanding match ($score%)! You meet all required skills at the required levels. Ready to apply!';
  }
  final top = actions.first;
  final required = top.competency.required;
  final step = top.isLevelUp
      ? 'raise ${top.skill} from ${top.competency.applicantLevel} to ${required!.label}'
      : 'learn ${top.skill}${required != null ? ' up to ${required.label}' : ''}';
  final reach = top.otherJobs.isEmpty
      ? ''
      : ' and closes the same gap in ${top.otherJobs.length} other posted job${top.otherJobs.length == 1 ? '' : 's'}';
  final cert = top.certification;
  final certText = cert == null
      ? ' Build it through projects and practice.'
      : cert.isFree && cert.label.toLowerCase().contains('free')
      ? ' Recommended: ${cert.label}.'
      : ' Recommended: ${cert.label} (${_costText(cert)}).';
  return '${_fitLabel(score)} ($score%). Best next step: $step — it raises your match to ${top.newScore}%$reach.$certText';
}

bool _hasSkillKeyword(String text, String keyword) {
  final lower = text.toLowerCase();
  final k = keyword.toLowerCase();
  if (k.length <= 2 && RegExp(r'^[a-z0-9]+$').hasMatch(k)) {
    return RegExp(
      r'\b' + RegExp.escape(k) + r'\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }
  return lower.contains(k);
}

/// Picks the missing skill most relevant to [jobTitle] (e.g. TypeScript
/// for a UI role), falling back to the first one.
String selectPrimaryPrescriptionSkill(
  List<String> missing, {
  String jobTitle = '',
}) {
  if (missing.isEmpty) return '';
  if (missing.length == 1 || jobTitle.trim().isEmpty) return missing.first;

  final titleLower = jobTitle.toLowerCase();

  final isUiDesign =
      titleLower.contains('ui') ||
      titleLower.contains('ux') ||
      titleLower.contains('interface') ||
      titleLower.contains('design') ||
      titleLower.contains('frontend') ||
      titleLower.contains('front-end') ||
      titleLower.contains('web');

  final isMobile =
      titleLower.contains('mobile') ||
      titleLower.contains('android') ||
      titleLower.contains('ios') ||
      titleLower.contains('flutter');

  final isDataAi =
      titleLower.contains('data') ||
      titleLower.contains('analytics') ||
      titleLower.contains('machine learning') ||
      titleLower.contains('ai');

  final isDevOps =
      titleLower.contains('devops') ||
      titleLower.contains('cloud') ||
      titleLower.contains('sysadmin') ||
      titleLower.contains('infrastructure');

  final isQa =
      titleLower.contains('qa') ||
      titleLower.contains('test') ||
      titleLower.contains('quality');

  final isCyber =
      titleLower.contains('security') || titleLower.contains('cyber');

  for (final skill in missing) {
    final sLower = skill.toLowerCase();
    if (isUiDesign) {
      if (_hasSkillKeyword(sLower, 'typescript') ||
          _hasSkillKeyword(sLower, 'ts') ||
          _hasSkillKeyword(sLower, 'react') ||
          _hasSkillKeyword(sLower, 'javascript') ||
          _hasSkillKeyword(sLower, 'js') ||
          _hasSkillKeyword(sLower, 'css') ||
          _hasSkillKeyword(sLower, 'html') ||
          _hasSkillKeyword(sLower, 'figma') ||
          _hasSkillKeyword(sLower, 'design') ||
          _hasSkillKeyword(sLower, 'ui') ||
          _hasSkillKeyword(sLower, 'ux') ||
          _hasSkillKeyword(sLower, 'web')) {
        return skill;
      }
    }
    if (isMobile) {
      if (_hasSkillKeyword(sLower, 'flutter') ||
          _hasSkillKeyword(sLower, 'dart') ||
          _hasSkillKeyword(sLower, 'android') ||
          _hasSkillKeyword(sLower, 'ios') ||
          _hasSkillKeyword(sLower, 'swift') ||
          _hasSkillKeyword(sLower, 'kotlin') ||
          _hasSkillKeyword(sLower, 'mobile')) {
        return skill;
      }
    }
    if (isDataAi) {
      if (_hasSkillKeyword(sLower, 'python') ||
          _hasSkillKeyword(sLower, 'data') ||
          _hasSkillKeyword(sLower, 'analytics') ||
          _hasSkillKeyword(sLower, 'pandas') ||
          _hasSkillKeyword(sLower, 'sql') ||
          _hasSkillKeyword(sLower, 'ai')) {
        return skill;
      }
    }
    if (isDevOps) {
      if (_hasSkillKeyword(sLower, 'docker') ||
          _hasSkillKeyword(sLower, 'kubernetes') ||
          _hasSkillKeyword(sLower, 'k8s') ||
          _hasSkillKeyword(sLower, 'aws') ||
          _hasSkillKeyword(sLower, 'cloud') ||
          _hasSkillKeyword(sLower, 'devops')) {
        return skill;
      }
    }
    if (isQa) {
      if (_hasSkillKeyword(sLower, 'qa') ||
          _hasSkillKeyword(sLower, 'test') ||
          _hasSkillKeyword(sLower, 'selenium') ||
          _hasSkillKeyword(sLower, 'automation')) {
        return skill;
      }
    }
    if (isCyber) {
      if (_hasSkillKeyword(sLower, 'security') ||
          _hasSkillKeyword(sLower, 'cyber')) {
        return skill;
      }
    }
  }

  return missing.first;
}
