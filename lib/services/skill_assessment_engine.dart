import 'dart:math';

import '../models/skill_assessment.dart';

const int kAssessmentSessionLength = 8;
const double _kStartAbility = 2.0;
const double _kMinAbility = 1.0;
const double _kMaxAbility = 4.0;
const double _kAbilityStep = 0.4;

String levelForAbility(double ability) {
  if (ability < 1.8) return kProficiencyLevels[0]; // Beginner
  if (ability < 2.6) return kProficiencyLevels[1]; // Intermediate
  if (ability < 3.4) return kProficiencyLevels[2]; // Advanced
  return kProficiencyLevels[3]; // Job-ready
}

/// Recorded answer details for post-quiz review.
class RecordedAnswer {
  final PresentedQuestion question;
  final int selectedIndex;
  final bool isCorrect;

  const RecordedAnswer({
    required this.question,
    required this.selectedIndex,
    required this.isCorrect,
  });
}

/// Runs an assessment session for a single category/role.
class AssessmentEngine {
  AssessmentEngine(
    this.category, {
    Random? random,
    int? sessionLength,
    this.isAdaptive = false,
  })  : _random = random ?? Random(),
        sessionLength = sessionLength ??
            (category.questions.isNotEmpty
                ? min(category.questions.length, kAssessmentSessionLength)
                : kAssessmentSessionLength);

  final AssessmentCategory category;
  final Random _random;
  final int sessionLength;
  final bool isAdaptive;

  double _ability = _kStartAbility;
  final Set<String> _askedIds = {};
  final List<RecordedAnswer> _recordedAnswers = [];
  int _correctCount = 0;
  int _askedCount = 0;
  PresentedQuestion? _current;

  double get ability => _ability;
  int get correctCount => _correctCount;
  int get askedCount => _askedCount;
  int get totalQuestions => min(sessionLength, category.questions.length);
  bool get isComplete =>
      _askedCount >= sessionLength || _askedCount >= category.questions.length;
  PresentedQuestion? get current => _current;
  List<RecordedAnswer> get recordedAnswers => List.unmodifiable(_recordedAnswers);

  PresentedQuestion? nextQuestion() {
    if (isComplete) {
      _current = null;
      return null;
    }

    AssessmentQuestion? source;
    if (isAdaptive) {
      final tier = _ability.round().clamp(1, 3);
      source = _pickQuestionAdaptive(preferredTier: tier);
    } else {
      source = _pickQuestionSequential();
    }

    if (source == null) {
      _current = null;
      return null;
    }
    _askedIds.add(source.id);
    _current = _present(source);
    return _current;
  }

  AssessmentQuestion? _pickQuestionSequential() {
    for (final q in category.questions) {
      if (!_askedIds.contains(q.id)) {
        return q;
      }
    }
    return null;
  }

  AssessmentQuestion? _pickQuestionAdaptive({required int preferredTier}) {
    final unused =
        category.questions.where((q) => !_askedIds.contains(q.id)).toList();
    if (unused.isEmpty) return null;

    for (final distance in [0, 1, 2]) {
      final candidates = unused
          .where((q) => (q.difficulty - preferredTier).abs() == distance)
          .toList();
      if (candidates.isNotEmpty) {
        return candidates[_random.nextInt(candidates.length)];
      }
    }
    return unused[_random.nextInt(unused.length)];
  }

  PresentedQuestion _present(AssessmentQuestion source) {
    return PresentedQuestion(
      source: source,
      options: source.options,
      correctIndex: source.correctIndex,
    );
  }

  /// Records an answer for the current question. Returns whether it was correct.
  bool submitAnswer(int selectedIndex) {
    final q = _current;
    if (q == null) return false;
    final isCorrect = selectedIndex == q.correctIndex;
    _askedCount += 1;
    if (isCorrect) {
      _correctCount += 1;
      _ability = min(_kMaxAbility, _ability + _kAbilityStep);
    } else {
      _ability = max(_kMinAbility, _ability - _kAbilityStep);
    }

    _recordedAnswers.add(RecordedAnswer(
      question: q,
      selectedIndex: selectedIndex,
      isCorrect: isCorrect,
    ));

    return isCorrect;
  }

  AssessmentResult buildResult() {
    final percentage =
        _askedCount > 0 ? ((_correctCount / _askedCount) * 100).round() : 0;
    final passed = percentage >= category.passingScorePercentage;

    String level;
    if (percentage >= 85) {
      level = 'Job-ready';
    } else if (percentage >= 70) {
      level = 'Advanced';
    } else if (percentage >= 50) {
      level = 'Intermediate';
    } else {
      level = 'Beginner';
    }

    return AssessmentResult(
      categoryKey: category.key,
      roleTitle: category.label,
      track: category.track,
      level: level,
      ability: _ability,
      correctCount: _correctCount,
      totalCount: _askedCount,
      scorePercentage: percentage,
      passed: passed,
      passingScorePercentage: category.passingScorePercentage,
      takenAt: DateTime.now(),
    );
  }
}

/// Reads previously saved assessment results out of the user's
/// `profile.skillAssessments` bucket.
Map<String, AssessmentResult> readAssessmentResults(
  Map<String, dynamic> profileData,
) {
  final raw = profileData['skillAssessments'];
  if (raw is! Map) return {};
  final out = <String, AssessmentResult>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString();
    final value = entry.value;
    if (value is! Map) continue;
    final result = AssessmentResult.fromJson(key, value);
    if (result != null) out[key] = result;
  }
  return out;
}

/// Reads the historical log of assessment attempts from the user's
/// `profile.assessmentRecords` bucket. Returns results sorted with newest first.
List<AssessmentResult> readAssessmentHistory(
  Map<String, dynamic> profileData,
) {
  final raw = profileData['assessmentRecords'];
  final list = <AssessmentResult>[];

  if (raw is List) {
    for (final item in raw) {
      if (item is! Map) continue;
      final categoryKey = (item['categoryKey'] ?? item['roleId'] ?? '').toString();
      final parsed = AssessmentResult.fromJson(categoryKey, item);
      if (parsed != null) {
        list.add(parsed);
      }
    }
  }

  // Fallback: If assessmentRecords is empty, populate from skillAssessments map
  if (list.isEmpty) {
    list.addAll(readAssessmentResults(profileData).values);
  }

  // Sort newest first
  list.sort((a, b) => b.takenAt.compareTo(a.takenAt));
  return list;
}

/// Merges a new result into the existing `profile` map, ready to send
/// as the `profile` patch to `updateMyProfile`.
Map<String, dynamic> mergeAssessmentResult(
  Map<String, dynamic> profileData,
  AssessmentResult result,
) {
  final profile = Map<String, dynamic>.from(profileData);
  final existing = profile['skillAssessments'];
  final assessments = existing is Map
      ? Map<String, dynamic>.from(existing)
      : <String, dynamic>{};
  assessments[result.categoryKey] = result.toJson();
  profile['skillAssessments'] = assessments;

  // Maintain a chronological assessment history log (up to 50 records)
  final existingHistory = profile['assessmentRecords'];
  final history = existingHistory is List
      ? List<Map<String, dynamic>>.from(
          existingHistory.whereType<Map>().map((m) => m.map((k, v) => MapEntry(k.toString(), v))),
        )
      : <Map<String, dynamic>>[];

  final recordMap = Map<String, dynamic>.from(result.toJson());
  recordMap['categoryKey'] = result.categoryKey;
  history.insert(0, recordMap);
  if (history.length > 50) {
    history.removeRange(50, history.length);
  }
  profile['assessmentRecords'] = history;

  return profile;
}
