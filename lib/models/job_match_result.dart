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

  factory JobMatchResult.fromJson(Map<String, dynamic> json) {
    List<String> readList(String key) {
      final value = json[key];
      if (value is! List) return const [];
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    int readInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    return JobMatchResult(
      jobTitle: (json['jobTitle'] as String?)?.trim() ?? '',
      matchScore: readInt('matchScore'),
      matchedSkills: readList('matchedSkills'),
      missingSkills: readList('missingSkills'),
      recommendation: (json['recommendation'] as String?)?.trim() ?? '',
    );
  }
}
