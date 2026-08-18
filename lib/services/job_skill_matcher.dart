import '../models/job_role_skills.dart';
import '../pages/jobs_page.dart';
import 'job_roles_data.dart';

/// Reads the signed-in user's own profile skills as a lowercased,
/// trimmed set, for matching against CSV role skill lists.
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

/// Replaces each job's skill lists with ones derived *only* from the
/// bundled IT_Job_Roles_Skills CSV: the job's title is matched to a
/// canonical role, that role's skills become the "required skills" list,
/// and each one is marked matched/unmatched against [mySkillKeys]. No
/// skill that isn't in the CSV is ever shown — jobs whose title doesn't
/// match any known role show no skill chips at all instead of falling
/// back to whatever the backend/scraped data sent. Used by every screen
/// that shows job match data (Jobs list, Dashboard) so the numbers agree
/// everywhere. Result is sorted by match percentage, highest first.
List<Job> applyCsvSkillMatch({
  required List<Job> jobs,
  required List<JobRoleSkills> roles,
  required Set<String> mySkillKeys,
}) {
  final result = jobs.map((job) {
    final role = findBestRoleForTitle(roles, job.title);
    if (role == null || role.skills.isEmpty) {
      return job.copyWith(matchedSkills: const [], unmatchedSkills: const []);
    }
    final split = splitSkillsByOwnership(role.skills, mySkillKeys);
    final percent = (split.matched.length / role.skills.length * 100).round();
    return job.copyWith(
      matchPercentage: percent,
      matchedSkills: split.matched,
      unmatchedSkills: split.unmatched,
    );
  }).toList();
  result.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
  return result;
}
