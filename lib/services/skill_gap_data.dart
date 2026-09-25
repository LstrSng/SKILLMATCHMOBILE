import '../models/job.dart';
import 'competency.dart';
import 'jobs_api.dart';
import 'session_store.dart';

/// A skill the user lacks, or has below the level posted jobs require.
class SkillGap {
  const SkillGap({
    required this.skill,
    required this.jobTitles,
    required this.required,
    required this.rating,
  });

  /// Plain skill name, without a competency level ("Cloud Computing").
  final String skill;
  final List<String> jobTitles;

  /// Highest level the jobs require, or null if they list none.
  final RequiredLevel? required;

  /// The user's 1–10 rating if they have the skill (a level gap), else null.
  final int? rating;

  int get jobCount => jobTitles.length;
  bool get isLevelGap => rating != null;
}

/// Skills the signed-in user lacks — or has below the required PSF-SDS
/// level — across all posted jobs, most-demanded first. Uses cached jobs
/// when available so the Pathways tab opens fast.
Future<List<SkillGap>> loadSkillGapsFromPostedJobs() async {
  var raw = await getCachedJobsRaw();
  if (raw.isEmpty) raw = await fetchJobsRaw();
  final user = SessionStore.user;

  final byKey = <String, SkillGap>{};
  for (final job in raw.map(Job.fromJson)) {
    final required = [...job.matchedSkills, ...job.unmatchedSkills];
    for (final c in assessCompetencies(required, user)) {
      if (c.status == CompetencyStatus.meets || c.skill.isEmpty) continue;
      final key = c.skill.toLowerCase();
      final prev = byKey[key];
      final titles = [...?prev?.jobTitles];
      if (!titles.contains(job.title)) titles.add(job.title);
      final prevLevel = prev?.required;
      final highest =
          prevLevel == null ||
              (c.required != null &&
                  c.required!.minRating > prevLevel.minRating)
          ? c.required
          : prevLevel;
      byKey[key] = SkillGap(
        skill: c.skill,
        jobTitles: titles,
        required: highest,
        rating: c.rating,
      );
    }
  }

  return byKey.values.toList()..sort((a, b) {
    final byCount = b.jobCount.compareTo(a.jobCount);
    return byCount != 0 ? byCount : a.skill.compareTo(b.skill);
  });
}
