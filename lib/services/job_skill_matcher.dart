import '../pages/jobs_page.dart';
import 'job_roles_data.dart';

/// Reads the signed-in user's own profile skills as a lowercased,
/// trimmed set, for matching against a job's required skills.
Set<String> readMySkillKeys(Map<String, dynamic>? user) {
  final v = user?['skills'];
  if (v is List) {
    return v
        .map((e) => e.toString().trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
  }
  return {};
}

/// Re-splits each job's own required skills (whatever the employer
/// actually selected when posting it — [Job.matchedSkills] ∪
/// [Job.unmatchedSkills] as returned by the API) into matched/unmatched
/// against [mySkillKeys], and recomputes the match percentage from that.
/// Never substitutes a different skill list — only the skills the job was
/// actually posted with are ever shown. Used by every screen that shows
/// job match data (Jobs list, Dashboard) so the numbers agree everywhere.
/// Result is sorted by match percentage, highest first.
List<Job> applyOwnSkillMatch({
  required List<Job> jobs,
  required Set<String> mySkillKeys,
}) {
  final result = jobs.map((job) {
    final requiredSkills = [...job.matchedSkills, ...job.unmatchedSkills];
    if (requiredSkills.isEmpty) return job;
    final split = splitSkillsByOwnership(requiredSkills, mySkillKeys);
    final percent = (split.matched.length / requiredSkills.length * 100)
        .round();
    return job.copyWith(
      matchPercentage: percent,
      matchedSkills: split.matched,
      unmatchedSkills: split.unmatched,
    );
  }).toList();
  result.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
  return result;
}
