/// Structured applicant background used for analytics: years of work
/// experience and highest educational attainment. Kept separate from the
/// free-text `education`/`experience` lists so they can be grouped and
/// compared across users.
library;

/// Highest educational attainment choices, lowest to highest. The backend
/// accepts only these values (see `EDUCATION_LEVELS` in backend/server.js).
const List<String> kEducationLevels = [
  'Vocational / TESDA',
  'College Undergraduate',
  "Bachelor's Degree",
  "Master's Degree",
  'Doctorate',
];

/// Upper bound of the years-of-experience picker ("40+ years").
const int kMaxExperienceYears = 40;

/// The user's highest education, or null if not set / not a known level.
String? readHighestEducation(Map<String, dynamic>? user) {
  final v = user?['highestEducation']?.toString().trim() ?? '';
  return kEducationLevels.contains(v) ? v : null;
}

/// The user's years of experience, or null if not set.
int? readYearsOfExperience(Map<String, dynamic>? user) {
  final v = user?['yearsOfExperience'];
  final n = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
  return n?.clamp(0, kMaxExperienceYears);
}

/// "No experience yet", "1 year", "5 years", "40+ years".
String experienceLabel(int years) {
  if (years <= 0) return 'No experience yet';
  if (years >= kMaxExperienceYears) return '$kMaxExperienceYears+ years';
  return '$years year${years == 1 ? '' : 's'}';
}
