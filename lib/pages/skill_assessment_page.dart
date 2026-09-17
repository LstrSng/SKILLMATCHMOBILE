import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/skill_assessment.dart';
import '../services/assessments_api.dart';
import '../services/profile_api.dart';
import '../services/session_store.dart';
import '../services/skill_assessment_bank.dart';
import '../services/skill_assessment_engine.dart';
import 'package:skillmatch/theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/match_score_badge.dart';

enum _Step { categories, question, result }

class SkillAssessmentPage extends StatefulWidget {
  final String? initialRoleId;
  final String? initialTrack;
  final String? initialSkill;

  const SkillAssessmentPage({
    super.key,
    this.initialRoleId,
    this.initialTrack,
    this.initialSkill,
  });

  @override
  State<SkillAssessmentPage> createState() => _SkillAssessmentPageState();
}

class _SkillAssessmentPageState extends State<SkillAssessmentPage> {
  static const int kQuestionTimeLimitSeconds = 30;

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _profileData = {};
  Map<String, AssessmentResult> _results = {};
  List<AssessmentCategory> _categories = [];
  List<String> _tracks = ['All'];
  String _selectedTrack = 'All';
  String _debouncedQuery = '';
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();

  _Step _step = _Step.categories;
  AssessmentCategory? _activeCategory;
  AssessmentEngine? _engine;
  PresentedQuestion? _question;
  int? _selectedIndex;
  AssessmentResult? _sessionResult;
  bool _saving = false;
  bool _showReview = false;

  Timer? _questionTimer;
  int _secondsRemaining = kQuestionTimeLimitSeconds;

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() => _debouncedQuery = '');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _debouncedQuery = val.trim().toLowerCase());
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTrack != null && widget.initialTrack!.isNotEmpty) {
      _selectedTrack = widget.initialTrack!;
    }
    if (widget.initialSkill != null && widget.initialSkill!.isNotEmpty) {
      _debouncedQuery = widget.initialSkill!.trim().toLowerCase();
      _searchController.text = widget.initialSkill!;
    }
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _stopQuestionTimer();
    _searchController.dispose();
    super.dispose();
  }

  void _startQuestionTimer() {
    _stopQuestionTimer();
    _secondsRemaining = kQuestionTimeLimitSeconds;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining -= 1);
      } else {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
        _handleQuestionTimeout();
      }
    });
  }

  void _stopQuestionTimer() {
    _questionTimer?.cancel();
    _questionTimer = null;
  }

  void _handleQuestionTimeout() {
    final engine = _engine;
    if (engine == null || _step != _Step.question) return;

    HapticFeedback.mediumImpact();
    // If user has selected an option, submit it; otherwise submit -1 (unanswered/incorrect)
    final selected = _selectedIndex ?? -1;
    engine.submitAnswer(selected);

    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: selected >= 0
              ? AppColors.primary
              : AppColors.warning,
          content: Text(
            selected >= 0
                ? "Time's up! Submitted your selected answer."
                : "Time's up for this question!",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected >= 0 ? Colors.white : Colors.black,
            ),
          ),
        ),
      );
    }

    if (engine.isComplete) {
      _stopQuestionTimer();
      final res = engine.buildResult();
      setState(() {
        _sessionResult = res;
        _step = _Step.result;
      });
      _autoSaveResult(res);
      return;
    }

    setState(() {
      _question = engine.nextQuestion();
      _selectedIndex = null;
    });
    _startQuestionTimer();
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
      // 1. Load full 64 PSF assessments from local database bank first for instant reliability
      List<AssessmentCategory> dbCategories = await loadPsfAssessmentBank();

      // 2. Try fetching latest assessments from live MongoDB backend API
      try {
        final remote = await fetchAssessments();
        if (remote.isNotEmpty) {
          dbCategories = remote;
        }
      } catch (apiErr) {
        debugPrint(
          'Live API fetch skipped: $apiErr (using preloaded PSF database bank)',
        );
      }

      // Collect unique tracks
      final trackSet = <String>{'All'};
      for (final c in dbCategories) {
        if (c.track.trim().isNotEmpty) {
          trackSet.add(c.track.trim());
        }
      }

      // 2. Fetch authenticated user profile
      Map<String, dynamic> profileData = {};
      try {
        final user = await fetchMyProfile();
        profileData = _asStringKeyed(user['profile']);
      } catch (profileErr) {
        debugPrint('Could not fetch user profile: $profileErr');
      }

      if (!mounted) return;
      setState(() {
        _categories = dbCategories;
        _tracks = trackSet.toList();
        _profileData = profileData;
        _results = readAssessmentResults(profileData);
        _loading = false;
      });

      // If deep-linked to a specific roleId, launch directly if found
      if (widget.initialRoleId != null) {
        final match = dbCategories.firstWhere(
          (c) => c.key == widget.initialRoleId || c.id == widget.initialRoleId,
          orElse: () => dbCategories.first,
        );
        if (match.key == widget.initialRoleId ||
            match.id == widget.initialRoleId) {
          _startCategory(match);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _startCategory(AssessmentCategory category) async {
    HapticFeedback.selectionClick();

    // If the category does not have full questions loaded, fetch by ID/roleId
    AssessmentCategory fullCategory = category;
    if (category.questions.isEmpty && category.id.isNotEmpty) {
      try {
        fullCategory = await fetchAssessmentById(category.id);
      } catch (_) {
        try {
          fullCategory = await fetchAssessmentById(category.key);
        } catch (_) {
          fullCategory = category;
        }
      }
    }

    if (fullCategory.questions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No questions available for this assessment yet.'),
        ),
      );
      return;
    }

    final engine = AssessmentEngine(
      fullCategory,
      isAdaptive: true,
      sessionLength: fullCategory.questions.isNotEmpty
          ? fullCategory.questions.length
          : kAssessmentSessionLength,
    );
    setState(() {
      _activeCategory = fullCategory;
      _engine = engine;
      _question = engine.nextQuestion();
      _selectedIndex = null;
      _showReview = false;
      _step = _Step.question;
    });
    _startQuestionTimer();
  }

  void _selectOption(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  void _submitAnswer() {
    final engine = _engine;
    final selected = _selectedIndex;
    if (engine == null || selected == null) return;

    _stopQuestionTimer();
    HapticFeedback.lightImpact();
    engine.submitAnswer(selected);

    if (engine.isComplete) {
      final res = engine.buildResult();
      setState(() {
        _sessionResult = res;
        _step = _Step.result;
      });
      // Auto-persist assessment result to database in background
      _autoSaveResult(res);
      return;
    }

    setState(() {
      _question = engine.nextQuestion();
      _selectedIndex = null;
    });
    _startQuestionTimer();
  }

  List<Map<String, dynamic>> _collectEngineAnswers() {
    final answers = <Map<String, dynamic>>[];
    final engine = _engine;
    if (engine == null) return answers;

    for (final r in engine.recordedAnswers) {
      final opt =
          (r.selectedIndex >= 0 && r.selectedIndex < r.question.options.length)
          ? r.question.options[r.selectedIndex]
          : '';
      answers.add({
        'questionId': r.question.source.id,
        'selectedAnswer': opt,
        'selectedIndex': r.selectedIndex,
        'isCorrect': r.isCorrect,
        'prompt': r.question.source.text,
      });
    }
    return answers;
  }

  Future<void> _autoSaveResult(AssessmentResult result) async {
    try {
      final category = _activeCategory;
      final categoryId = category?.id.isNotEmpty == true
          ? category!.id
          : (category?.key ?? result.categoryKey);

      final answers = _collectEngineAnswers();

      // Save via dedicated assessment submit API in MongoDB
      final res = await submitAssessment(
        assessmentId: categoryId,
        correctCount: result.correctCount,
        totalCount: result.totalCount,
        answers: answers,
      );

      // Synchronize SessionStore and local profile without wiping out other fields
      Map<String, dynamic> updatedProfile = mergeAssessmentResult(
        _profileData,
        result,
      );
      if (res['user'] is Map) {
        final userDoc = Map<String, dynamic>.from(res['user'] as Map);
        if (userDoc['profile'] is Map) {
          updatedProfile = Map<String, dynamic>.from(userDoc['profile'] as Map);
        }
        await SessionStore.updateUser(userDoc);
      } else if (SessionStore.user != null) {
        final currentUser = Map<String, dynamic>.from(SessionStore.user!);
        currentUser['profile'] = updatedProfile;
        await SessionStore.updateUser(currentUser);
      }

      if (!mounted) return;
      setState(() {
        _profileData = updatedProfile;
        _results = readAssessmentResults(updatedProfile);
      });

      if (result.passed) {
        final skillName = (result.roleTitle ?? _activeCategory?.label ?? result.categoryKey).trim();
        if (skillName.isNotEmpty) {
          final currentSkills =
              (SessionStore.user?['skills'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final alreadyHas = currentSkills.any(
            (s) => s.toLowerCase().trim() == skillName.toLowerCase(),
          );
          if (!alreadyHas) {
            try {
              await updateMyProfile({
                'skills': [...currentSkills, skillName],
              });
            } catch (e) {
              // Non-critical: skill sync failed but assessment is saved
              debugPrint('Could not sync skill to profile: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Auto-save assessment error: $e');
    }
  }

  Future<void> _saveResult() async {
    final result = _sessionResult;
    final category = _activeCategory;
    if (result == null) return;

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final categoryId = category?.id.isNotEmpty == true
          ? category!.id
          : (category?.key ?? result.categoryKey);

      final answers = _collectEngineAnswers();

      // 1. Submit to MongoDB assessments collection backend
      final res = await submitAssessment(
        assessmentId: categoryId,
        correctCount: result.correctCount,
        totalCount: result.totalCount,
        answers: answers,
      );

      // 2. Synchronize SessionStore and local profile
      Map<String, dynamic> updatedProfile = mergeAssessmentResult(
        _profileData,
        result,
      );
      if (res['user'] is Map) {
        final userDoc = Map<String, dynamic>.from(res['user'] as Map);
        if (userDoc['profile'] is Map) {
          updatedProfile = Map<String, dynamic>.from(userDoc['profile'] as Map);
        }
        await SessionStore.updateUser(userDoc);
      } else if (SessionStore.user != null) {
        final currentUser = Map<String, dynamic>.from(SessionStore.user!);
        currentUser['profile'] = updatedProfile;
        await SessionStore.updateUser(currentUser);
      }

      if (!mounted) return;
      setState(() {
        _profileData = updatedProfile;
        _results = readAssessmentResults(updatedProfile);
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.passed
                ? 'Score saved to your profile and visible to employers!'
                : 'Assessment results recorded to your profile.',
          ),
          backgroundColor: result.passed
              ? AppColors.success
              : AppColors.primary,
        ),
      );
      _exitToCategories();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save result: $e')));
    }
  }

  Future<bool> _handleBackPress() async {
    if (_step == _Step.categories) {
      return true;
    }
    if (_step == _Step.question) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Exit Assessment?'),
          content: const Text(
            'Your progress for this assessment will be lost if you leave now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Continue Quiz'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Exit'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        _exitToCategories();
      }
      return false;
    }
    _exitToCategories();
    return false;
  }

  void _exitToCategories() {
    _stopQuestionTimer();
    setState(() {
      _step = _Step.categories;
      _activeCategory = null;
      _engine = null;
      _question = null;
      _selectedIndex = null;
      _sessionResult = null;
      _showReview = false;
    });
  }

  List<AssessmentCategory> get _filteredCategories {
    return _categories.where((c) {
      final matchesTrack =
          _selectedTrack == 'All' ||
          c.track.toLowerCase() == _selectedTrack.toLowerCase();
      if (!matchesTrack) return false;

      if (_debouncedQuery.isEmpty) return true;
      final q = _debouncedQuery;
      return c.label.toLowerCase().contains(q) ||
          c.title.toLowerCase().contains(q) ||
          c.track.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return PopScope(
      canPop: _step == _Step.categories,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: tokens.scaffoldBackground,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: tokens.cardBackground,
          surfaceTintColor: Colors.transparent,
          foregroundColor: tokens.textPrimary,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: tokens.textPrimary),
            onPressed: () {
              if (_step == _Step.categories) {
                Navigator.of(context).pop();
              } else {
                _handleBackPress();
              }
            },
          ),
          title: Text(
            _titleForStep(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          actions: [
            if (_step == _Step.categories)
              IconButton(
                tooltip: 'Refresh assessments',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _load,
              ),
          ],
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
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: tokens.textFaint,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : _buildStep(context),
      ),
    );
  }

  String _titleForStep() {
    switch (_step) {
      case _Step.categories:
        return 'Skill Assessments';
      case _Step.question:
        return _activeCategory?.label ?? 'Assessment';
      case _Step.result:
        return 'Assessment Results';
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
    final tokens = context.appColors;
    final filtered = _filteredCategories;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Hero
                  const Text(
                    'Philippine Skills Framework (PSF-SDS)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verify Your Competencies',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Take standardized multiple-choice assessments designed for IT & Design roles. '
                    'Scores and verified badges are saved to your profile and displayed directly to employers.',
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search roles, skills, or tracks...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (context, value, _) {
                          if (value.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchDebounce?.cancel();
                              _searchController.clear();
                              setState(() => _debouncedQuery = '');
                            },
                          );
                        },
                      ),
                      filled: true,
                      fillColor: tokens.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tokens.cardBorderSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tokens.cardBorderSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Track Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _tracks.map((track) {
                        final isSelected = _selectedTrack == track;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(track),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : tokens.textSecondary,
                            ),
                            backgroundColor: tokens.cardBackground,
                            selectedColor: AppColors.primary,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : tokens.cardBorderSoft,
                              ),
                            ),
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedTrack = track);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Assessments Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filtered.length} Assessment${filtered.length == 1 ? '' : 's'} available',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.textFaint,
                        ),
                      ),
                      if (_results.isNotEmpty)
                        Text(
                          '${_results.length} Completed',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Assessment Records Summary
                  if (_results.isNotEmpty) ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 18,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Assessment Records (${_results.length})',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Saved to Profile',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          for (final res in _results.values.toList().take(
                            4,
                          )) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: res.passed
                                          ? AppColors.successBg
                                          : AppColors.warningBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      res.passed
                                          ? Icons.check
                                          : Icons.priority_high,
                                      size: 12,
                                      color: res.passed
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          res.roleTitle?.isNotEmpty == true
                                              ? res.roleTitle!
                                              : res.categoryKey,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: tokens.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Score: ${res.scorePercentage}% • Recorded on ${res.formattedDateOnly}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: tokens.textFaint,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: res.passed
                                          ? AppColors.successBg
                                          : AppColors.warningBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${res.scorePercentage}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: res.passed
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),

          // Assessments List
          if (filtered.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: tokens.textFaint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _debouncedQuery.isNotEmpty
                              ? 'No assessments found matching "$_debouncedQuery"'
                              : 'No assessments found.',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final category = filtered[index];
                  return _DbAssessmentCard(
                    category: category,
                    result: _results[category.key] ?? _results[category.id],
                    onTap: () => _startCategory(category),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final tokens = context.appColors;
    final engine = _engine;
    final question = _question;
    if (engine == null || question == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalQ = engine.totalQuestions > 0 ? engine.totalQuestions : 15;
    final currentQNumber = engine.askedCount + 1;
    final progress = (engine.askedCount / totalQ).clamp(0.0, 1.0);

    final timerProgress = (_secondsRemaining / kQuestionTimeLimitSeconds).clamp(
      0.0,
      1.0,
    );
    final timerColor = _secondsRemaining <= 5
        ? AppColors.danger
        : _secondsRemaining <= 10
        ? AppColors.warning
        : AppColors.primary;
    final timerBg = _secondsRemaining <= 5
        ? AppColors.dangerBg
        : _secondsRemaining <= 10
        ? AppColors.warningBg
        : AppColors.primarySoftBg;

    final diffColor = switch (question.source.difficulty) {
      1 => AppColors.success,
      3 => AppColors.danger,
      _ => AppColors.warning,
    };

    final diffBg = switch (question.source.difficulty) {
      1 => AppColors.successBg,
      3 => AppColors.dangerBg,
      _ => AppColors.warningBg,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Assessment Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: tokens.cardBorderSoft,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 5),
            // 30-Second Question Timer Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: timerProgress,
                minHeight: 3,
                backgroundColor: tokens.cardBorderSoft.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(timerColor),
              ),
            ),
            const SizedBox(height: 10),

            // Question Meta Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question $currentQNumber of $totalQ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    // 30s Countdown Timer Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: timerBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: timerColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _secondsRemaining <= 5
                                ? Icons.alarm_on_rounded
                                : Icons.timer_outlined,
                            size: 13,
                            color: timerColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_secondsRemaining}s',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: timerColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: diffBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        question.source.difficultyLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: diffColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Competency Banner
            if (question.source.competency.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.cardBorderSoft),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${question.source.skillType} • ${question.source.competency}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Question Prompt & Options
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.source.text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < question.options.length; i++) ...[
                      _OptionSelectTile(
                        indexLabel: String.fromCharCode(65 + i), // A, B, C, D
                        text: question.options[i],
                        isSelected: _selectedIndex == i,
                        onTap: () => _selectOption(i),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _selectedIndex == null ? null : _submitAnswer,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  currentQNumber >= totalQ
                      ? 'Submit Assessment'
                      : 'Next Question',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final tokens = context.appColors;
    final result = _sessionResult;
    final category = _activeCategory;
    final engine = _engine;

    if (result == null || category == null) return const SizedBox.shrink();

    final passed = result.passed;
    final percentage = result.scorePercentage;
    final statusColor = passed ? AppColors.success : AppColors.warning;
    final statusBg = passed ? AppColors.successBg : AppColors.warningBg;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Result Card
          AppCard(
            variant: AppCardVariant.elevated,
            child: Column(
              children: [
                Row(
                  children: [
                    MatchScoreBadge(
                      score: percentage,
                      variant: MatchScoreBadgeVariant.circular,
                      size: 64,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              passed ? 'PASSED • READY' : 'NEEDS PRACTICE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            category.label,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Proficiency: ${result.level}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Statistics Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                      label: 'Correct',
                      value: '${result.correctCount}/${result.totalCount}',
                      color: AppColors.success,
                    ),
                    _StatColumn(
                      label: 'Score',
                      value: '$percentage%',
                      color: statusColor,
                    ),
                    _StatColumn(
                      label: 'Required',
                      value: '${result.passingScorePercentage}%',
                      color: tokens.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Official Assessment Record Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.cardBorderSoft),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Score Record Date: ${result.formattedDate}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Employer Visibility Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoftBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This verified assessment is automatically stored on your database profile and visible to employers during job applications.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Save & Sync Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveResult,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                _saving ? 'Syncing with database...' : 'Save & Finish',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Retake / Back Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _startCategory(category),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Retake Quiz'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: _exitToCategories,
                  child: const Text('All Assessments'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Review Answers Accordion
          if (engine != null && engine.recordedAnswers.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _showReview = !_showReview),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: tokens.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.cardBorderSoft),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _showReview
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Review Answers & Explanations (${engine.recordedAnswers.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _showReview
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: tokens.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (_showReview) ...[
              const SizedBox(height: 12),
              for (var i = 0; i < engine.recordedAnswers.length; i++) ...[
                _AnswerReviewTile(
                  index: i + 1,
                  record: engine.recordedAnswers[i],
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
      ],
    );
  }
}

class _OptionSelectTile extends StatelessWidget {
  final String indexLabel;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionSelectTile({
    required this.indexLabel,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoftBg : tokens.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : tokens.cardBorderSoft,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : tokens.surfaceMuted,
                border: Border.all(
                  color: isSelected ? AppColors.primary : tokens.cardBorderSoft,
                ),
              ),
              child: Center(
                child: Text(
                  indexLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : tokens.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: tokens.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DbAssessmentCard extends StatelessWidget {
  final AssessmentCategory category;
  final AssessmentResult? result;
  final VoidCallback onTap;

  const _DbAssessmentCard({
    required this.category,
    required this.result,
    required this.onTap,
  });

  IconData _iconForTrack(String track) {
    final t = track.toLowerCase();
    if (t.contains('ui') || t.contains('design') || t.contains('product')) {
      return Icons.palette_outlined;
    }
    if (t.contains('software') ||
        t.contains('engineering') ||
        t.contains('architecture')) {
      return Icons.code_rounded;
    }
    if (t.contains('infrastructure') ||
        t.contains('cloud') ||
        t.contains('operations')) {
      return Icons.cloud_outlined;
    }
    if (t.contains('security') || t.contains('cyber') || t.contains('audit')) {
      return Icons.shield_outlined;
    }
    if (t.contains('qa') || t.contains('testing') || t.contains('quality')) {
      return Icons.bug_report_outlined;
    }
    if (t.contains('business') ||
        t.contains('analysis') ||
        t.contains('delivery')) {
      return Icons.analytics_outlined;
    }
    return Icons.quiz_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final questionsCount = category.questionsCount > 0
        ? category.questionsCount
        : (category.questions.isNotEmpty ? category.questions.length : 15);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoftBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForTrack(category.track),
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.track,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (result != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: result!.passed
                            ? AppColors.successBg
                            : AppColors.warningBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${result!.scorePercentage}% • ${result!.passed ? 'Passed' : 'Needs Practice'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: result!.passed
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Recorded ${result!.formattedDateOnly}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: tokens.textFaint,
                      ),
                    ),
                  ],
                )
              else
                const Icon(Icons.chevron_right, color: AppColors.textFaint),
            ],
          ),
          if (category.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              category.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: tokens.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _MetaPill(
                icon: Icons.help_outline_rounded,
                label: '$questionsCount questions',
              ),
              const SizedBox(width: 8),
              const _MetaPill(
                icon: Icons.timer_outlined,
                label: '30s / question',
              ),
              const SizedBox(width: 8),
              _MetaPill(
                icon: Icons.check_circle_outline,
                label: 'Pass: ${category.passingScorePercentage}%',
              ),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.surfaceMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 12,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Score: ${result!.scorePercentage}% • Recorded on ${result!.formattedDate}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tokens.textFaint),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerReviewTile extends StatelessWidget {
  final int index;
  final RecordedAnswer record;

  const _AnswerReviewTile({required this.index, required this.record});

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final q = record.question;
    final isCorrect = record.isCorrect;
    final userOption =
        record.selectedIndex >= 0 && record.selectedIndex < q.options.length
        ? q.options[record.selectedIndex]
        : (record.selectedIndex == -1
              ? 'Timed out (No answer)'
              : 'None selected');
    final correctOption =
        q.correctIndex >= 0 && q.correctIndex < q.options.length
        ? q.options[q.correctIndex]
        : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCorrect
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: isCorrect ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 8),
              Text(
                'Question $index',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isCorrect ? AppColors.success : AppColors.danger,
                ),
              ),
              const Spacer(),
              Text(
                q.source.difficultyLabel,
                style: TextStyle(fontSize: 11, color: tokens.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            q.source.text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Answer: $userOption',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isCorrect ? AppColors.success : AppColors.danger,
            ),
          ),
          if (!isCorrect && correctOption.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Correct Answer: $correctOption',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
          if (q.source.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.surfaceMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '💡 Explanation: ${q.source.explanation}',
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textSecondary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
