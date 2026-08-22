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

/// Runs one adaptive assessment session for a single category: picks
/// the next question based on a running ability estimate (higher after
/// a correct answer, lower after a miss), so the difficulty tracks the
/// user instead of following a fixed script.
class AssessmentEngine {
  AssessmentEngine(this.category, {Random? random})
    : _random = random ?? Random();

  final AssessmentCategory category;
  final Random _random;

  double _ability = _kStartAbility;
  final Set<String> _askedIds = {};
  int _correctCount = 0;
  int _askedCount = 0;
  PresentedQuestion? _current;

  double get ability => _ability;
  int get correctCount => _correctCount;
  int get askedCount => _askedCount;
  bool get isComplete =>
      _askedCount >= kAssessmentSessionLength ||
      _askedCount >= category.questions.length;
  PresentedQuestion? get current => _current;

  PresentedQuestion? nextQuestion() {
    if (isComplete) {
      _current = null;
      return null;
    }
    final tier = _ability.round().clamp(1, 3);
    final source = _pickQuestion(preferredTier: tier);
    if (source == null) {
      _current = null;
      return null;
    }
    _askedIds.add(source.id);
    _current = _present(source);
    return _current;
  }

  AssessmentQuestion? _pickQuestion({required int preferredTier}) {
    final unused = category.questions
        .where((q) => !_askedIds.contains(q.id))
        .toList();
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
    final indices = List<int>.generate(source.options.length, (i) => i)
      ..shuffle(_random);
    final shuffledOptions = [for (final i in indices) source.options[i]];
    final newCorrectIndex = indices.indexOf(source.correctIndex);
    return PresentedQuestion(
      source: source,
      options: shuffledOptions,
      correctIndex: newCorrectIndex,
    );
  }

  /// Records an answer for the current question and advances the
  /// ability estimate. Returns whether the answer was correct.
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
    return isCorrect;
  }

  AssessmentResult buildResult() {
    return AssessmentResult(
      categoryKey: category.key,
      level: levelForAbility(_ability),
      ability: _ability,
      correctCount: _correctCount,
      totalCount: _askedCount,
      takenAt: DateTime.now(),
    );
  }
}

/// Reads previously saved assessment results out of the user's
/// `profile.skillAssessments` bucket (the same flexible `profile` map
/// used for resume/certification uploads).
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
  return profile;
}
