import 'dart:math';

/// A short "read the code, pick the output" question shown before a user
/// applies to a developer-aligned job.
class CodingChallenge {
  final String id;
  final String language;
  final String prompt;
  final String code;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const CodingChallenge({
    required this.id,
    required this.language,
    required this.prompt,
    required this.code,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

final _kDeveloperTitleRegex = RegExp(
  r'develop|programmer|software|full[\s-]?stack|front[\s-]?end|back[\s-]?end|'
  r'web engineer|mobile engineer|app engineer|android|\bios\b|flutter|'
  r'\bcoder\b|devops|automation engineer|game (dev|programmer)',
  caseSensitive: false,
);

/// Whether [jobTitle] is a developer/programming role that should get a
/// mini coding question before applying.
bool isDeveloperRole(String jobTitle) =>
    _kDeveloperTitleRegex.hasMatch(jobTitle);

const List<CodingChallenge> _kChallenges = [
  CodingChallenge(
    id: 'py-list-sum',
    language: 'Python',
    prompt: 'What does this code print?',
    code: 'nums = [1, 2, 3, 4]\n'
        'total = 0\n'
        'for n in nums:\n'
        '    if n % 2 == 0:\n'
        '        total += n\n'
        'print(total)',
    options: ['4', '6', '10', '2'],
    correctIndex: 1,
    explanation: 'Only even numbers (2 and 4) are added: 2 + 4 = 6.',
  ),
  CodingChallenge(
    id: 'py-slice',
    language: 'Python',
    prompt: 'What does this code print?',
    code: 'word = "SkillMatch"\nprint(word[0:5].upper())',
    options: ['SKILL', 'SKILLM', 'skill', 'MATCH'],
    correctIndex: 0,
    explanation: 'word[0:5] is "Skill" (indexes 0–4), then upper() gives "SKILL".',
  ),
  CodingChallenge(
    id: 'js-equality',
    language: 'JavaScript',
    prompt: 'What does this code log?',
    code: 'const a = "5";\nconst b = 5;\nconsole.log(a == b, a === b);',
    options: ['true true', 'false false', 'true false', 'false true'],
    correctIndex: 2,
    explanation:
        '== converts types before comparing (true); === also checks the type (false).',
  ),
  CodingChallenge(
    id: 'js-map-filter',
    language: 'JavaScript',
    prompt: 'What does this code log?',
    code: 'const nums = [1, 2, 3, 4, 5];\n'
        'const out = nums.filter(n => n > 2).map(n => n * 2);\n'
        'console.log(out.length);',
    options: ['5', '2', '3', '6'],
    correctIndex: 2,
    explanation: 'filter keeps [3, 4, 5] (3 items); map does not change the length.',
  ),
  CodingChallenge(
    id: 'java-loop',
    language: 'Java',
    prompt: 'What is printed?',
    code: 'int count = 0;\n'
        'for (int i = 0; i < 10; i += 3) {\n'
        '    count++;\n'
        '}\n'
        'System.out.println(count);',
    options: ['3', '4', '10', '9'],
    correctIndex: 1,
    explanation: 'i takes the values 0, 3, 6, 9, so the loop body runs 4 times.',
  ),
  CodingChallenge(
    id: 'dart-null',
    language: 'Dart',
    prompt: 'What is printed?',
    code: 'String? name;\nprint(name ?? "Guest");',
    options: ['null', 'Guest', 'An error', '""'],
    correctIndex: 1,
    explanation: '?? returns the right side when the left side is null.',
  ),
  CodingChallenge(
    id: 'sql-count',
    language: 'SQL',
    prompt: 'The users table has 5 rows; 2 of them have a NULL email. What does this return?',
    code: 'SELECT COUNT(email) FROM users;',
    options: ['5', '2', '3', 'NULL'],
    correctIndex: 2,
    explanation: 'COUNT(column) ignores NULL values, so it counts 5 − 2 = 3 rows.',
  ),
  CodingChallenge(
    id: 'generic-fizz',
    language: 'Pseudocode',
    prompt: 'What is the output?',
    code: 'x = 15\n'
        'if x % 3 == 0 and x % 5 == 0: print("FizzBuzz")\n'
        'elif x % 3 == 0: print("Fizz")\n'
        'elif x % 5 == 0: print("Buzz")\n'
        'else: print(x)',
    options: ['Fizz', 'Buzz', 'FizzBuzz', '15'],
    correctIndex: 2,
    explanation: '15 is divisible by both 3 and 5, so the first branch runs.',
  ),
];

const Map<String, List<String>> _kLanguageHints = {
  'Python': ['python', 'django', 'flask', 'data', 'machine learning'],
  'JavaScript': [
    'javascript', 'js', 'react', 'node', 'front', 'web', 'full stack',
    'full-stack', 'vue', 'angular', 'typescript',
  ],
  'Java': ['java', 'spring', 'android'],
  'Dart': ['flutter', 'dart', 'mobile'],
  'SQL': ['sql', 'database', 'back end', 'back-end', 'backend'],
};

/// Picks a challenge whose language fits the job title (and optionally the
/// user's skills), falling back to any challenge.
CodingChallenge pickCodingChallenge(
  String jobTitle, {
  List<String> userSkills = const [],
  Random? random,
}) {
  final rng = random ?? Random();
  final haystack = '${jobTitle.toLowerCase()} ${userSkills.join(' ').toLowerCase()}';

  final languages = <String>[];
  _kLanguageHints.forEach((lang, hints) {
    if (hints.any(haystack.contains)) languages.add(lang);
  });

  final pool = languages.isEmpty
      ? _kChallenges
      : _kChallenges.where((c) => languages.contains(c.language)).toList();
  return pool[rng.nextInt(pool.length)];
}
