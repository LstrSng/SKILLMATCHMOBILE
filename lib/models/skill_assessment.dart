/// A single multiple-choice question tagged with a difficulty tier.
/// Difficulty: 1 = easy, 2 = medium, 3 = hard.
class AssessmentQuestion {
  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final int difficulty;

  const AssessmentQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
  });
}

class AssessmentCategory {
  final String key;
  final String label;
  final String description;
  final List<AssessmentQuestion> questions;

  const AssessmentCategory({
    required this.key,
    required this.label,
    required this.description,
    required this.questions,
  });
}

/// A question ready to render, with options shuffled so the correct
/// answer isn't always in the same position as in the source bank.
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
  final String level;
  final double ability;
  final int correctCount;
  final int totalCount;
  final DateTime takenAt;

  const AssessmentResult({
    required this.categoryKey,
    required this.level,
    required this.ability,
    required this.correctCount,
    required this.totalCount,
    required this.takenAt,
  });

  Map<String, dynamic> toJson() => {
    'level': level,
    'ability': ability,
    'correctCount': correctCount,
    'totalCount': totalCount,
    'takenAt': takenAt.toIso8601String(),
  };

  static AssessmentResult? fromJson(String categoryKey, Map raw) {
    final level = (raw['level'] as Object?)?.toString().trim() ?? '';
    if (level.isEmpty) return null;
    return AssessmentResult(
      categoryKey: categoryKey,
      level: level,
      ability: (raw['ability'] as num?)?.toDouble() ?? 0,
      correctCount: (raw['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (raw['totalCount'] as num?)?.toInt() ?? 0,
      takenAt:
          DateTime.tryParse((raw['takenAt'] as Object?)?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
