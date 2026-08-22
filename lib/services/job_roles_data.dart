import 'package:flutter/services.dart' show rootBundle;

import '../models/job_role_skills.dart';

const String _csvAssetPath = 'assets/data/IT_Job_Roles_Skills.csv';

List<JobRoleSkills>? _cache;
Future<List<JobRoleSkills>>? _loading;

/// Loads and parses the bundled IT job-role/skills dataset. When the same
/// job title (case-insensitively) appears on more than one CSV row, only
/// the first row is kept — its skills and certifications are used exactly
/// as listed, never merged with a later duplicate row's.
Future<List<JobRoleSkills>> loadJobRoles() {
  if (_cache != null) return Future.value(_cache);
  return _loading ??= _load().then((roles) {
    _cache = roles;
    return roles;
  });
}

const _kSeniorityWords = {
  'senior',
  'sr',
  'junior',
  'jr',
  'lead',
  'staff',
  'principal',
  'associate',
  'entry',
  'level',
  'i',
  'ii',
  'iii',
  'iv',
  'chief',
  'new',
  'grad',
};

/// Generic job-title "type" words that appear across dozens of unrelated
/// roles — excluded from the keyword-overlap vocabulary so a shared
/// generic word alone can't trigger a match (see [findBestRoleForTitle]).
const _kGenericRoleWords = {
  'engineer',
  'engineers',
  'developer',
  'developers',
  'manager',
  'managers',
  'analyst',
  'analysts',
  'specialist',
  'specialists',
  'consultant',
  'consultants',
  'architect',
  'architects',
  'administrator',
  'administrators',
  'director',
  'directors',
  'officer',
  'officers',
  'coordinator',
  'coordinators',
  'executive',
  'executives',
  'representative',
  'representatives',
  'technician',
  'technicians',
  'designer',
  'designers',
  'lead',
  'leads',
  'head',
  'professional',
};

String _normalizeSpacing(String s) {
  return s
      .replaceAll('front-end', 'front end')
      .replaceAll('frontend', 'front end')
      .replaceAll('back-end', 'back end')
      .replaceAll('backend', 'back end')
      .replaceAll('full-stack', 'full stack')
      .replaceAll('fullstack', 'full stack');
}

Set<String> _keywordVocab(String normalized) {
  return _normalizeSpacing(normalized)
      .split(RegExp(r'[\s/,-]+'))
      .where(
        (w) =>
            w.length > 2 &&
            !_kSeniorityWords.contains(w) &&
            !_kGenericRoleWords.contains(w),
      )
      .toSet();
}

String _stripSeniority(String normalized) {
  final words = normalized
      .split(RegExp(r'[\s/,-]+'))
      .where((w) => w.isNotEmpty && !_kSeniorityWords.contains(w));
  return words.join(' ').trim();
}

/// Finds the entry in [roles] whose canonical title best matches a real
/// job posting's [jobTitle] — exact match first, then seniority-stripped
/// match, then keyword overlap (same approach as
/// `pathway_links_data.dart`'s pathway matching, applied to CSV roles
/// instead). Returns null if nothing reasonable is found.
JobRoleSkills? findBestRoleForTitle(
  List<JobRoleSkills> roles,
  String jobTitle,
) {
  final normalized = jobTitle.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  for (final r in roles) {
    if (r.title.toLowerCase() == normalized) return r;
  }

  final stripped = _stripSeniority(normalized);
  for (final r in roles) {
    if (_stripSeniority(r.title.toLowerCase()) == stripped) return r;
  }

  final words = _keywordVocab(stripped.isNotEmpty ? stripped : normalized);
  if (words.isEmpty) return null;

  JobRoleSkills? best;
  var bestScore = 0;
  for (final r in roles) {
    final roleWords = _keywordVocab(r.title.toLowerCase());
    if (roleWords.isEmpty) continue;
    final isFullyContained = roleWords.every(words.contains);
    if (isFullyContained && roleWords.length > bestScore) {
      bestScore = roleWords.length;
      best = r;
    }
  }
  return best;
}

/// Strips a competency-framework skill entry down to its plain skill name,
/// e.g. "Business Needs Analysis Level 2" -> "Business Needs Analysis" and
/// "Collaboration Basic" -> "Collaboration". Used to build a clean list of
/// pickable skill names for the profile skills selector.
String _stripLevelSuffix(String s) {
  var out = s.trim();
  out = out.replaceFirst(
    RegExp(r'^-?\s*Level\s*\d+(?:-\d+)?\s*', caseSensitive: false),
    '',
  );
  out = out.replaceFirst(
    RegExp(r'\s*Level\s*\d+(?:-\d+)?\s*$', caseSensitive: false),
    '',
  );
  out = out.replaceFirst(
    RegExp(r'\s*(Basic|Intermediate|Advanced)\s*$', caseSensitive: false),
    '',
  );
  return out.trim();
}

/// Concrete tools, languages, and platforms that real applicants list on
/// their profiles but that never appear in the bundled competency-framework
/// dataset (which only has broad process/soft skills like "Programming and
/// Coding" or "Cloud Computing", not "Python" or "AWS"). Merged into the
/// profile skill picker's options so it covers what people actually search
/// for, on top of the vocabulary job postings are matched against.
const List<String> _kCommonTechSkills = [
  // Programming languages
  'Python', 'Java', 'JavaScript', 'TypeScript', 'C', 'C++', 'C#', 'Dart',
  'Kotlin', 'Swift', 'PHP', 'Ruby', 'Go', 'Rust', 'R', 'MATLAB', 'Scala',
  'Perl', 'Objective-C', 'VB.NET', 'SQL',
  // Web front end
  'HTML', 'CSS', 'Sass', 'React', 'React Native', 'Angular', 'Vue.js',
  'Next.js', 'Svelte', 'jQuery', 'Tailwind CSS', 'Bootstrap', 'Redux',
  // Mobile
  'Flutter', 'Android Development', 'iOS Development', 'Xamarin',
  // Backend & frameworks
  'Node.js', 'Express.js', 'Django', 'Flask', 'FastAPI', 'Spring Boot',
  'Laravel', 'Ruby on Rails', 'ASP.NET', '.NET', 'GraphQL', 'REST APIs',
  // Databases
  'MySQL', 'PostgreSQL', 'MongoDB', 'Firebase', 'Oracle Database',
  'Microsoft SQL Server', 'Redis', 'SQLite', 'Elasticsearch', 'DynamoDB',
  // Cloud & DevOps
  'Amazon Web Services (AWS)', 'Microsoft Azure', 'Google Cloud Platform',
  'Docker', 'Kubernetes', 'Jenkins', 'Terraform', 'Ansible', 'CI/CD',
  'Git', 'GitHub', 'GitLab', 'Bitbucket', 'Linux Administration',
  'Shell Scripting', 'Nginx',
  // Data, AI & analytics
  'Data Science', 'Machine Learning', 'Deep Learning',
  'Natural Language Processing', 'Computer Vision', 'TensorFlow', 'PyTorch',
  'Pandas', 'NumPy', 'Power BI', 'Tableau', 'Apache Spark', 'ETL',
  'Big Data',
  // Design
  'UI/UX Design', 'Figma', 'Adobe XD', 'Adobe Photoshop',
  'Adobe Illustrator', 'Sketch', 'Canva', 'Wireframing', 'Prototyping',
  // QA & testing
  'Manual Testing', 'Automated Testing', 'Selenium', 'JUnit', 'Cypress',
  'API Testing', 'Postman',
  // Project management & methodology
  'Agile', 'Scrum', 'Kanban', 'Waterfall', 'Jira', 'Trello',
  'Project Planning',
  // Security & networking
  'Ethical Hacking', 'Penetration Testing', 'Firewall Configuration',
  'Cloud Security',
  // Office & productivity
  'Microsoft Excel', 'Microsoft Word', 'Microsoft PowerPoint',
  'Google Sheets', 'Google Docs',
  // Common soft skills
  'Leadership', 'Time Management', 'Customer Service', 'Creativity',
  'Attention to Detail', 'Public Speaking', 'Negotiation',
  'Conflict Resolution',
];

/// Returns the deduplicated, alphabetically sorted list of pickable skill
/// names shown in the profile page's skill picker: the curated
/// [_kCommonTechSkills] (concrete languages/tools/soft skills applicants
/// actually search for) plus every plain skill name (competency levels
/// stripped) drawn from the bundled IT job-role/skills dataset — the same
/// vocabulary job postings are matched against. Deduplicated
/// case-insensitively, keeping the curated list's casing on overlaps
/// (e.g. "Communication" appears in both).
Future<List<String>> loadSkillOptions() async {
  final roles = await loadJobRoles();
  final seen = <String>{};
  final out = <String>[];

  for (final skill in _kCommonTechSkills) {
    if (seen.add(skill.toLowerCase())) out.add(skill);
  }
  for (final role in roles) {
    for (final skill in role.skills) {
      final base = _stripLevelSuffix(skill);
      if (base.isEmpty) continue;
      if (seen.add(base.toLowerCase())) out.add(base);
    }
  }

  out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return out;
}

/// Splits [skills] into (matched, unmatched) based on whether each skill
/// (case-insensitively) is present in [mySkillKeys].
({List<String> matched, List<String> unmatched}) splitSkillsByOwnership(
  List<String> skills,
  Set<String> mySkillKeys,
) {
  final matched = <String>[];
  final unmatched = <String>[];
  for (final s in skills) {
    if (mySkillKeys.contains(s.trim().toLowerCase())) {
      matched.add(s);
    } else {
      unmatched.add(s);
    }
  }
  return (matched: matched, unmatched: unmatched);
}

Future<List<JobRoleSkills>> _load() async {
  final raw = await rootBundle.loadString(_csvAssetPath);
  final lines = raw.split(RegExp(r'\r\n|\r|\n')).where((l) => l.isNotEmpty);

  final byKey = <String, _MergingRole>{};
  var first = true;
  for (final line in lines) {
    if (first) {
      first = false;
      continue; // header row
    }
    final fields = _parseCsvLine(line);
    if (fields.length < 3) continue;
    final title = fields[0].trim();
    if (title.isEmpty) continue;
    final description = fields[1].trim();
    final skills = _splitList(fields[2]);
    final certifications = fields.length > 3
        ? _splitList(fields[3])
        : const <String>[];

    final key = title.toLowerCase();
    // First occurrence wins: use that row's skills/certifications exactly
    // as listed in the CSV. Don't union them with any later duplicate-title
    // rows — a role's skill list should match one real CSV row, not a
    // merged combination of several.
    if (byKey.containsKey(key)) continue;
    byKey[key] = _MergingRole(title: title, description: description)
      ..addSkills(skills)
      ..addCertifications(certifications);
  }

  final roles = byKey.values.map((m) => m.toJobRoleSkills()).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return roles;
}

class _MergingRole {
  final String title;
  String description;
  final List<String> _skills = [];
  final Set<String> _skillKeys = {};
  final List<String> _certifications = [];
  final Set<String> _certKeys = {};

  _MergingRole({required this.title, required this.description});

  void addSkills(List<String> skills) {
    for (final s in skills) {
      final key = s.toLowerCase();
      if (_skillKeys.add(key)) _skills.add(s);
    }
  }

  void addCertifications(List<String> certs) {
    for (final c in certs) {
      final key = c.toLowerCase();
      if (_certKeys.add(key)) _certifications.add(c);
    }
  }

  JobRoleSkills toJobRoleSkills() => JobRoleSkills(
    title: title,
    description: description,
    skills: _skills,
    certifications: _certifications,
  );
}

List<String> _splitList(String field) {
  return field
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Minimal RFC4180-style CSV line parser: handles double-quoted fields,
/// commas inside quotes, and "" as an escaped quote.
List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buffer.write(ch);
      }
    } else {
      if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
  }
  fields.add(buffer.toString());
  return fields;
}
