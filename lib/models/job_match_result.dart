class JobMatchResult {
  const JobMatchResult({
    required this.jobTitle,
    required this.matchScore,
    required this.matchedSkills,
    required this.missingSkills,
    required this.recommendation,
  });

  final String jobTitle;
  final int matchScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final String recommendation;

  int get totalSkills => matchedSkills.length + missingSkills.length;
}
