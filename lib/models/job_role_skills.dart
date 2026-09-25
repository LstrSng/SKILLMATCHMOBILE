/// A PSF-SDS job role from `assets/data/psf_sds_data.json`.
class JobRoleSkills {
  final String title;
  final String description;

  /// Functional and enabling skills with their required level, e.g.
  /// "Business Needs Analysis Level 2" or "Communication Basic".
  final List<String> skills;

  const JobRoleSkills({
    required this.title,
    required this.description,
    required this.skills,
  });
}
