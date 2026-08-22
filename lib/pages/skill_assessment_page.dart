import 'package:flutter/material.dart';

import '../models/skill_assessment.dart';
import '../services/profile_api.dart';
import '../services/skill_assessment_bank.dart';
import '../services/skill_assessment_engine.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';

enum _Step { categories, question, result }

class SkillAssessmentPage extends StatefulWidget {
  const SkillAssessmentPage({super.key});

  @override
  State<SkillAssessmentPage> createState() => _SkillAssessmentPageState();
}

class _SkillAssessmentPageState extends State<SkillAssessmentPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _profileData = {};
  Map<String, AssessmentResult> _results = {};

  _Step _step = _Step.categories;
  AssessmentCategory? _activeCategory;
  AssessmentEngine? _engine;
  PresentedQuestion? _question;
  int? _selectedIndex;
  AssessmentResult? _sessionResult;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _asStringKeyed(Object? raw) {
    if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await fetchMyProfile();
      if (!mounted) return;
      final profileData = _asStringKeyed(user['profile']);
      setState(() {
        _profileData = profileData;
        _results = readAssessmentResults(profileData);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startCategory(AssessmentCategory category) {
    final engine = AssessmentEngine(category);
    setState(() {
      _activeCategory = category;
      _engine = engine;
      _question = engine.nextQuestion();
      _selectedIndex = null;
      _step = _Step.question;
    });
  }

  void _selectOption(int index) {
    setState(() => _selectedIndex = index);
  }

  void _submitAnswer() {
    final engine = _engine;
    final selected = _selectedIndex;
    if (engine == null || selected == null) return;
    engine.submitAnswer(selected);
    if (engine.isComplete) {
      setState(() {
        _sessionResult = engine.buildResult();
        _step = _Step.result;
      });
      return;
    }
    setState(() {
      _question = engine.nextQuestion();
      _selectedIndex = null;
    });
  }

  Future<void> _saveResult() async {
    final result = _sessionResult;
    if (result == null) return;
    setState(() => _saving = true);
    try {
      final mergedProfile = mergeAssessmentResult(_profileData, result);
      final updated = await updateMyProfile({'profile': mergedProfile});
      if (!mounted) return;
      final profileData = _asStringKeyed(updated['profile']);
      setState(() {
        _profileData = profileData;
        _results = readAssessmentResults(profileData);
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Result saved to your profile.')),
      );
      _exitToCategories();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _exitToCategories() {
    setState(() {
      _step = _Step.categories;
      _activeCategory = null;
      _engine = null;
      _question = null;
      _selectedIndex = null;
      _sessionResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(_titleForStep()),
        leading: _step == _Step.categories
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _exitToCategories,
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _buildStep(context),
    );
  }

  String _titleForStep() {
    switch (_step) {
      case _Step.categories:
        return 'Skill assessment';
      case _Step.question:
        return _activeCategory?.label ?? 'Assessment';
      case _Step.result:
        return 'Your results';
    }
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case _Step.categories:
        return _buildCategoryList(context);
      case _Step.question:
        return _buildQuestion(context);
      case _Step.result:
        return _buildResult(context);
    }
  }

  Widget _buildCategoryList(BuildContext context) {
    final horizontalPadding = MediaQuery.of(context).size.width > 600
        ? 32.0
        : 16.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        16,
        horizontalPadding,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find your level',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Answer a short adaptive quiz per topic — questions get harder or '
            'easier as you go, then we place you at your level.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          for (final category in kAssessmentCategories) ...[
            _CategoryCard(
              category: category,
              result: _results[category.key],
              onTap: () => _startCategory(category),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final engine = _engine;
    final question = _question;
    if (engine == null || question == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final horizontalPadding = MediaQuery.of(context).size.width > 600
        ? 32.0
        : 16.0;
    final progress = engine.askedCount / kAssessmentSessionLength;
    final tierLabel = switch (question.source.difficulty) {
      1 => 'Difficulty: easy',
      2 => 'Difficulty: intermediate',
      _ => 'Difficulty: advanced',
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        16,
        horizontalPadding,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${engine.askedCount + 1} of $kAssessmentSessionLength',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textFaint,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tierLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.source.text,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < question.options.length; i++) ...[
                    _OptionTile(
                      label: question.options[i],
                      selected: _selectedIndex == i,
                      onTap: () => _selectOption(i),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedIndex == null ? null : _submitAnswer,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                engine.askedCount + 1 >= kAssessmentSessionLength
                    ? 'Finish'
                    : 'Next question',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final result = _sessionResult;
    final category = _activeCategory;
    if (result == null || category == null) return const SizedBox.shrink();
    final horizontalPadding = MediaQuery.of(context).size.width > 600
        ? 32.0
        : 16.0;
    final colors = _levelColors(result.level);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        16,
        horizontalPadding,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Assessment complete',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.fg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.level,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${result.correctCount} of ${result.totalCount} answered correctly',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (kAssessmentCategories.length > 1) ...[
            const Text(
              'Other categories',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final other in kAssessmentCategories.where(
              (c) => c.key != category.key,
            )) ...[
              _CategorySummaryRow(category: other, result: _results[other.key]),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveResult,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save to profile'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _exitToCategories,
              child: const Text('Back to categories'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelColors {
  final Color bg;
  final Color fg;
  const _LevelColors(this.bg, this.fg);
}

_LevelColors _levelColors(String level) {
  switch (level) {
    case 'Beginner':
      return const _LevelColors(AppColors.warningBg, AppColors.warning);
    case 'Advanced':
    case 'Job-ready':
      return const _LevelColors(AppColors.successBg, AppColors.success);
    case 'Intermediate':
    default:
      return const _LevelColors(AppColors.primarySoftBg, AppColors.primary);
  }
}

IconData categoryIcon(String key) {
  switch (key) {
    case 'programming':
      return Icons.code;
    case 'database':
      return Icons.storage_outlined;
    case 'networking':
      return Icons.router_outlined;
    case 'cybersecurity':
      return Icons.shield_outlined;
    case 'data_analytics':
      return Icons.bar_chart_outlined;
    case 'cloud_computing':
      return Icons.cloud_outlined;
    case 'software_testing':
      return Icons.bug_report_outlined;
    case 'communication':
      return Icons.forum_outlined;
    default:
      return Icons.quiz_outlined;
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.result,
    required this.onTap,
  });

  final AssessmentCategory category;
  final AssessmentResult? result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoftBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              categoryIcon(category.key),
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (result != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _levelColors(result!.level).bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                result!.level,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _levelColors(result!.level).fg,
                ),
              ),
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.textFaint),
        ],
      ),
    );
  }
}

class _CategorySummaryRow extends StatelessWidget {
  const _CategorySummaryRow({required this.category, required this.result});

  final AssessmentCategory category;
  final AssessmentResult? result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(category.label, style: const TextStyle(fontSize: 13)),
          if (result != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _levelColors(result!.level).bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                result!.level,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _levelColors(result!.level).fg,
                ),
              ),
            )
          else
            const Text(
              'Not taken',
              style: TextStyle(fontSize: 12, color: AppColors.textFaint),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoftBg : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? AppColors.primaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
