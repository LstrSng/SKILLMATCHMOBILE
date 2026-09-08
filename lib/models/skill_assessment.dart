int _asInt(dynamic raw, [int fallback = 0]) {
  if (raw == null) return fallback;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) {
    return int.tryParse(raw.trim()) ?? double.tryParse(raw.trim())?.toInt() ?? fallback;
  }
  return fallback;
}

double _asDouble(dynamic raw, [double fallback = 0.0]) {
  if (raw == null) return fallback;
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    return double.tryParse(raw.trim()) ?? fallback;
  }
  return fallback;
}

/// A single multiple-choice question tagged with difficulty, competency,
/// and explanation from the Philippine Skills Framework (PSF-SDS) database.
class AssessmentQuestion {
  final String id;
  final String text;
  final List<String> options;
  final String correctAnswer;
  final int correctIndex;
  final int difficulty; // 1 = Junior/Easy, 2 = Mid/Intermediate, 3 = Senior/Hard
  final String difficultyLabel;
  final String explanation;
  final String competency;
  final String skillType;
  final int points;
  final int timeLimitSeconds;

  const AssessmentQuestion({
    required this.id,
    required this.text,
    required this.options,
    this.correctAnswer = '',
    required this.correctIndex,
    required this.difficulty,
    this.difficultyLabel = 'Mid-Level',
    this.explanation = '',
    this.competency = '',
    this.skillType = 'Functional Competency',
    this.points = 5,
    this.timeLimitSeconds = 30,
  });

  static int _parseDifficultyTier(dynamic raw) {
    if (raw is num) return raw.toInt().clamp(1, 3);
    final str = (raw?.toString() ?? '').toLowerCase().trim();
    if (str.contains('junior') || str.contains('easy') || str.contains('beginner')) {
      return 1;
    }
    if (str.contains('senior') || str.contains('lead') || str.contains('hard') || str.contains('advanced')) {
      return 3;
    }
    return 2; // Mid-Level / Intermediate default
  }

  factory AssessmentQuestion.fromJson(Map raw) {
    final id = (raw['questionId'] ?? raw['_id'] ?? raw['id'] ?? '').toString();
    final text = (raw['prompt'] ?? raw['text'] ?? raw['question'] ?? '').toString().trim();
    final optionsRaw = raw['options'];
    final options = optionsRaw is List
        ? optionsRaw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final correctAnswer = (raw['correctAnswer'] ?? raw['answer'] ?? '').toString().trim();
    int correctIndex = -1;
    if (correctAnswer.isNotEmpty) {
      correctIndex = options.indexWhere(
        (o) => o.toLowerCase() == correctAnswer.toLowerCase(),
      );
    }
    if (correctIndex < 0 && raw['correctIndex'] != null) {
      correctIndex = _asInt(raw['correctIndex'], 0);
    }
    if (correctIndex < 0 || correctIndex >= options.length) {
      correctIndex = 0; // safe fallback
    }

    final diffTier = _parseDifficultyTier(raw['difficulty']);
    final diffLabel = (raw['difficulty']?.toString().trim().isNotEmpty == true)
        ? raw['difficulty'].toString().trim()
        : (diffTier == 1 ? 'Junior' : diffTier == 3 ? 'Senior' : 'Mid-Level');

    return AssessmentQuestion(
      id: id,
      text: text,
      options: options,
      correctAnswer: correctAnswer.isNotEmpty ? correctAnswer : (options.isNotEmpty ? options[correctIndex] : ''),
      correctIndex: correctIndex,
      difficulty: diffTier,
      difficultyLabel: diffLabel,
      explanation: (raw['explanation'] ?? '').toString().trim(),
      competency: (raw['competency'] ?? '').toString().trim(),
      skillType: (raw['skillType'] ?? 'Functional Competency').toString().trim(),
      points: _asInt(raw['points'], 5),
      timeLimitSeconds: _asInt(raw['timeLimitSeconds'], 30),
    );
  }

  Map<String, dynamic> toJson() => {
    'questionId': id,
    'prompt': text,
    'options': options,
    'correctAnswer': correctAnswer,
    'correctIndex': correctIndex,
    'difficulty': difficultyLabel,
    'explanation': explanation,
    'competency': competency,
    'skillType': skillType,
    'points': points,
    'timeLimitSeconds': timeLimitSeconds,
  };
}

/// An assessment category or role competency test fetched from MongoDB.
class AssessmentCategory {
  final String id;
  final String key; // roleId
  final String label; // roleTitle
  final String title;
  final String track;
  final String description;
  final int passingScorePercentage;
  final int timeLimitMinutes;
  final int questionsCount;
  final List<AssessmentQuestion> questions;

  const AssessmentCategory({
    this.id = '',
    required this.key,
    required this.label,
    this.title = '',
    this.track = 'General',
    required this.description,
    this.passingScorePercentage = 70,
    this.timeLimitMinutes = 25,
    this.questionsCount = 0,
    required this.questions,
  });

  factory AssessmentCategory.fromJson(Map raw) {
    final id = (raw['_id'] ?? raw['id'] ?? '').toString();
    final roleId = (raw['roleId'] ?? raw['key'] ?? id).toString();
    final roleTitle = (raw['roleTitle'] ?? raw['label'] ?? raw['title'] ?? roleId).toString();
    final title = (raw['title'] ?? roleTitle).toString();
    final track = (raw['track'] ?? 'General').toString();
    final description = (raw['description'] ?? '').toString();
    final passingScore = _asInt(raw['passingScorePercentage'], 70);
    final timeLimit = _asInt(raw['timeLimitMinutes'], 25);

    final qList = <AssessmentQuestion>[];
    if (raw['questions'] is List) {
      for (final q in raw['questions']) {
        if (q is Map) {
          qList.add(AssessmentQuestion.fromJson(q));
        }
      }
    }

    final qCount = _asInt(raw['questionsCount'], qList.length);

    return AssessmentCategory(
      id: id,
      key: roleId,
      label: roleTitle,
      title: title,
      track: track,
      description: description,
      passingScorePercentage: passingScore,
      timeLimitMinutes: timeLimit,
      questionsCount: qCount,
      questions: qList,
    );
  }
}

/// A question ready to render with options.
class PresentedQuestion {
  final AssessmentQuestion source;
  final List<String> options;
  final int correctIndex;

  const PresentedQuestion({
    required this.source,
    required this.options,
    required this.correctIndex,
  });
}

const List<String> kProficiencyLevels = [
  'Beginner',
  'Intermediate',
  'Advanced',
  'Job-ready',
];

class AssessmentResult {
  final String categoryKey;
  final String? roleTitle;
  final String? track;
  final String level;
  final double ability;
  final int correctCount;
  final int totalCount;
  final int scorePercentage;
  final bool passed;
  final int passingScorePercentage;
  final DateTime takenAt;

  const AssessmentResult({
    required this.categoryKey,
    this.roleTitle,
    this.track,
    required this.level,
    required this.ability,
    required this.correctCount,
    required this.totalCount,
    this.scorePercentage = 0,
    this.passed = false,
    this.passingScorePercentage = 70,
    required this.takenAt,
  });

  Map<String, dynamic> toJson() => {
    'level': level,
    'ability': ability,
    'correctCount': correctCount,
    'totalCount': totalCount,
    'scorePercentage': scorePercentage,
    'passed': passed,
    'passingScorePercentage': passingScorePercentage,
    'roleTitle': roleTitle ?? '',
    'track': track ?? '',
    'takenAt': takenAt.toIso8601String(),
  };

  /// Formatted date and time, e.g. "Sep 8, 2026 • 11:21 PM"
  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final local = takenAt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} • $hour:$minute $ampm';
  }

  /// Formatted date only, e.g. "Sep 8, 2026"
  String get formattedDateOnly {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final local = takenAt.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  static AssessmentResult? fromJson(String categoryKey, Map raw) {
    final level = (raw['level'] as Object?)?.toString().trim() ?? '';
    if (level.isEmpty) return null;
    final correct = _asInt(raw['correctCount'], 0);
    final total = _asInt(raw['totalCount'], 0);
    final calculatedPercent = total > 0 ? ((correct / total) * 100).round() : 0;
    final scorePercent = raw['scorePercentage'] != null
        ? _asInt(raw['scorePercentage'], calculatedPercent)
        : calculatedPercent;
    final passingScore = _asInt(raw['passingScorePercentage'], 70);
    final isPassed = raw['passed'] is bool
        ? (raw['passed'] as bool)
        : (raw['passed']?.toString().toLowerCase() == 'true' || scorePercent >= passingScore);

    return AssessmentResult(
      categoryKey: categoryKey,
      roleTitle: (raw['roleTitle'] as Object?)?.toString().trim(),
      track: (raw['track'] as Object?)?.toString().trim(),
      level: level,
      ability: _asDouble(raw['ability'], 0.0),
      correctCount: correct,
      totalCount: total,
      scorePercentage: scorePercent,
      passed: isPassed,
      passingScorePercentage: passingScore,
      takenAt:
          DateTime.tryParse((raw['takenAt'] as Object?)?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
