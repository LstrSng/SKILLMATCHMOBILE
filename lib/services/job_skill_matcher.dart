import '../models/job.dart';
import 'competency.dart';

/// Re-splits each job's own required skills (whatever the employer
/// actually selected when posting it — [Job.matchedSkills] ∪
/// [Job.unmatchedSkills] as returned by the API) into skills the user has
/// (matched, at any level) and lacks (unmatched), and recomputes the match
/// percentage from the user's competency levels (see [assessCompetencies]).
List<Job> applyOwnSkillMatch({
  required List<Job> jobs,
  required Map<String, dynamic>? user,
}) {
  final result = jobs.map((job) {
    final requiredSkills = [...job.matchedSkills, ...job.unmatchedSkills];
    if (requiredSkills.isEmpty) return job;
    final competencies = assessCompetencies(requiredSkills, user);
    return job.copyWith(
      matchPercentage: competencyMatchPercent(competencies),
      matchedSkills: [
        for (final c in competencies)
          if (c.status != CompetencyStatus.missing) c.raw,
      ],
      unmatchedSkills: [
        for (final c in competencies)
          if (c.status == CompetencyStatus.missing) c.raw,
      ],
    );
  }).toList();
  result.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
  return result;
}
