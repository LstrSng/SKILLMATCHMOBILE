import 'job_roles_data.dart';

/// Competency levels, aligned with the PSF-SDS dataset.
///
/// Job postings require PSF-SDS skills with a proficiency level:
/// functional skills use "Level 1"…"Level 6" (sometimes a range such as
/// "Level 2-3", read as the minimum), enabling skills use Basic /
/// Intermediate / Advanced. Applicants rate each skill 1–10. This file
/// converts between the two so every screen compares them the same way.
///
/// | Rating (1–10) | Functional (PSF) | Enabling     |
/// |---------------|------------------|--------------|
/// | 1             | Level 1          | Basic        |
/// | 2–3           | Level 2          | Basic        |
/// | 4–5           | Level 3          | Intermediate |
/// | 6             | Level 4          | Intermediate |
/// | 7–8           | Level 5          | Intermediate / Advanced (8) |
/// | 9–10          | Level 6          | Advanced     |

/// Short label for a 1–10 rating, e.g. 3 → "Beginner".
String skillLevelLabel(int rating) {
  if (rating <= 3) return 'Beginner';
  if (rating <= 6) return 'Intermediate';
  if (rating <= 8) return 'Advanced';
  return 'Expert';
}

/// Rating a skill gets when the applicant hasn't rated it.
const int kUnratedSkillLevel = 5;

const _kEnablingLevels = ['Basic', 'Intermediate', 'Advanced'];

/// PSF-SDS functional level (1–6) for a 1–10 rating.
int psfLevelForRating(int rating) =>
    const [1, 2, 2, 3, 3, 4, 5, 5, 6, 6][rating.clamp(1, 10) - 1];

/// Enabling level (Basic / Intermediate / Advanced) for a 1–10 rating.
String enablingLevelForRating(int rating) {
  final r = rating.clamp(1, 10);
  if (r <= 3) return 'Basic';
  if (r <= 7) return 'Intermediate';
  return 'Advanced';
}

/// Lowest 1–10 rating that reaches PSF [level].
int _minRatingForPsfLevel(int level) =>
    const {1: 1, 2: 2, 3: 4, 4: 6, 5: 7, 6: 9}[level.clamp(1, 6)]!;

/// Lowest 1–10 rating that reaches an enabling [level].
int _minRatingForEnabling(String level) =>
    const {'Basic': 1, 'Intermediate': 4, 'Advanced': 8}[level] ?? 1;

/// The level a job requires for one skill, e.g. "Level 3" or "Intermediate".
class RequiredLevel {
  const RequiredLevel._({this.psfLevel, this.enabling});

  /// Functional PSF level 1–6 (minimum of a range), if any.
  final int? psfLevel;

  /// Enabling level (Basic / Intermediate / Advanced), if any.
  final String? enabling;

  /// Minimum 1–10 rating that meets this level.
  int get minRating => psfLevel != null
      ? _minRatingForPsfLevel(psfLevel!)
      : _minRatingForEnabling(enabling!);

  String get label => psfLevel != null ? 'Level $psfLevel' : enabling!;

  /// The applicant's [rating] expressed on this level's scale.
  String labelForRating(int rating) => psfLevel != null
      ? 'Level ${psfLevelForRating(rating)}'
      : enablingLevelForRating(rating);

  /// Reads the level from a dataset skill such as "Budgeting Level 3",
  /// "Business Needs Analysis Level 2-3" or "Collaboration Basic". Returns
  /// null for skills without a level (e.g. "React").
  static RequiredLevel? parse(String rawSkill) {
    final s = rawSkill.trim();
    final psf = RegExp(
      r'Level\s*(\d)(?:\s*-\s*\d)?',
      caseSensitive: false,
    ).firstMatch(s);
    if (psf != null) {
      return RequiredLevel._(psfLevel: int.parse(psf.group(1)!).clamp(1, 6));
    }
    for (final level in _kEnablingLevels) {
      if (RegExp('\\b$level\\s*\$', caseSensitive: false).hasMatch(s)) {
        return RequiredLevel._(enabling: level);
      }
    }
    return null;
  }
}

enum CompetencyStatus {
  /// Has the skill at or above the required level.
  meets,

  /// Has the skill, but below the required level.
  belowLevel,

  /// Doesn't have the skill.
  missing,
}

/// How the applicant stands on one skill a job requires.
class SkillCompetency {
  const SkillCompetency({
    required this.raw,
    required this.skill,
    required this.required,
    required this.rating,
    required this.status,
  });

  /// The skill as the job lists it, e.g. "Budgeting Level 3".
  final String raw;

  /// Plain skill name, e.g. "Budgeting".
  final String skill;

  /// Required level, or null when the job lists no level.
  final RequiredLevel? required;

  /// Applicant's 1–10 rating, or null if they don't have the skill.
  final int? rating;
  final CompetencyStatus status;

  /// e.g. "Beginner (Level 2)", "Advanced (8/10)", or null if missing.
  String? get applicantDescription {
    final r = rating;
    if (r == null) return null;
    final scaled = required?.labelForRating(r) ?? '$r/10';
    return '${skillLevelLabel(r)} ($scaled)';
  }

  /// The applicant's standing on this skill, e.g. "You: Beginner (Basic) ·
  /// required Basic" when met, otherwise [gapDescription].
  String get levelSummary {
    if (status != CompetencyStatus.meets) return gapDescription;
    final req = required == null
        ? 'any level is enough'
        : 'required ${required!.label}';
    return 'You: $applicantDescription · $req';
  }

  /// What the applicant still needs, e.g. "You: Beginner (Level 2) · needs
  /// Level 3" or "Not in your skills yet · any level is enough".
  String get gapDescription {
    final needs = required == null
        ? 'any level is enough'
        : 'needs ${required!.label}';
    final you = applicantDescription;
    return you == null
        ? 'Not in your skills yet · $needs'
        : 'You: $you · $needs';
  }

  /// Applicant's level on the required scale, e.g. "Level 2".
  String? get applicantLevel {
    final r = rating;
    if (r == null) return null;
    return required?.labelForRating(r) ?? '$r/10';
  }

  /// Share of this requirement met, 0–1 (partial credit below level).
  double get credit {
    switch (status) {
      case CompetencyStatus.meets:
        return 1;
      case CompetencyStatus.missing:
        return 0;
      case CompetencyStatus.belowLevel:
        return rating! / required!.minRating;
    }
  }
}

/// Assesses each of a job's [requiredSkills] against the applicant's
/// skills and 1–10 levels from [user] (the profile map).
List<SkillCompetency> assessCompetencies(
  List<String> requiredSkills,
  Map<String, dynamic>? user,
) {
  final ratings = <String, int>{};
  final skills = user?['skills'];
  final levels = user?['skillLevels'];
  if (skills is List) {
    for (final s in skills) {
      final name = s.toString().trim();
      if (name.isEmpty) continue;
      final raw = levels is Map ? levels[name] : null;
      final rating = raw is num ? raw.round() : int.tryParse('${raw ?? ''}');
      ratings[plainSkillName(name).toLowerCase()] =
          (rating ?? kUnratedSkillLevel).clamp(1, 10);
    }
  }

  // Some postings list a skill twice ("agile software development" and
  // "Agile Software Development Level 4"); count it once, at the stricter
  // (higher) required level.
  final unique = <String, String>{};
  for (final raw in requiredSkills) {
    final key = plainSkillName(raw).toLowerCase();
    if (key.isEmpty) continue;
    final current = unique[key];
    final newMin = RequiredLevel.parse(raw)?.minRating ?? 0;
    final currentMin = current == null
        ? -1
        : (RequiredLevel.parse(current)?.minRating ?? 0);
    if (newMin > currentMin) unique[key] = raw;
  }

  return [
    for (final raw in unique.values)
      () {
        final skill = plainSkillName(raw);
        final required = RequiredLevel.parse(raw);
        final rating =
            ratings[skill.toLowerCase()] ?? ratings[raw.trim().toLowerCase()];
        final status = rating == null
            ? CompetencyStatus.missing
            : (required == null || rating >= required.minRating)
            ? CompetencyStatus.meets
            : CompetencyStatus.belowLevel;
        return SkillCompetency(
          raw: raw,
          skill: skill,
          required: required,
          rating: rating,
          status: status,
        );
      }(),
  ];
}

/// Competency-weighted match: the average credit across required skills,
/// as a 0–100 percentage.
int competencyMatchPercent(List<SkillCompetency> competencies) {
  if (competencies.isEmpty) return 0;
  final total = competencies.fold<double>(0, (sum, c) => sum + c.credit);
  return (total / competencies.length * 100).round();
}

/// A 1–10 [rating] as the PSF-SDS dataset expresses it for [skill]:
/// "Level N" for functional skills, Basic/Intermediate/Advanced for
/// enabling skills, or null for tech-stack skills (no dataset level).
/// Needs [loadJobRoles] to have run so skills can be categorized.
String? datasetLevelLabel(String skill, int rating) =>
    switch (categorizeSkill(skill)) {
      SkillCategory.functional => 'Level ${psfLevelForRating(rating)}',
      SkillCategory.enabling => enablingLevelForRating(rating),
      SkillCategory.techStack => null,
    };
