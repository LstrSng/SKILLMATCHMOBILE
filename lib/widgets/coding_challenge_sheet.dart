import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/coding_challenge_bank.dart';
import 'package:skillmatch/theme/app_colors.dart';

/// Shows a mini coding question for a developer-aligned job. Returns the
/// result to attach to the application, or null if the user backed out.
Future<Map<String, dynamic>?> showCodingChallengeSheet(
  BuildContext context, {
  required String jobTitle,
  List<String> userSkills = const [],
}) {
  final challenge = pickCodingChallenge(jobTitle, userSkills: userSkills);
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.appColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CodingChallengeSheet(challenge: challenge),
  );
}

class _CodingChallengeSheet extends StatefulWidget {
  const _CodingChallengeSheet({required this.challenge});

  final CodingChallenge challenge;

  @override
  State<_CodingChallengeSheet> createState() => _CodingChallengeSheetState();
}

class _CodingChallengeSheetState extends State<_CodingChallengeSheet> {
  final _stopwatch = Stopwatch()..start();
  int? _selected;
  bool _submitted = false;

  bool get _correct => _selected == widget.challenge.correctIndex;

  void _submit() {
    if (_selected == null) return;
    _stopwatch.stop();
    HapticFeedback.mediumImpact();
    setState(() => _submitted = true);
  }

  void _continue() {
    final c = widget.challenge;
    Navigator.pop(context, {
      'questionId': c.id,
      'language': c.language,
      'selectedAnswer': c.options[_selected!],
      'correct': _correct,
      'timeTakenSeconds': _stopwatch.elapsed.inSeconds,
      'answeredAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final c = widget.challenge;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.code_rounded, color: tokens.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quick coding check',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.primarySoftBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    c.language,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'This is a developer role. Answer one short question; your result is sent to the employer with your application.',
              style: TextStyle(fontSize: 13, color: tokens.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              c.prompt,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  c.code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(c.options.length, (i) {
              final isSelected = _selected == i;
              final isAnswer = i == c.correctIndex;
              Color border = isSelected ? tokens.primary : tokens.cardBorderSoft;
              Color bg = isSelected ? tokens.primarySoftBg : tokens.cardBackground;
              if (_submitted && isAnswer) {
                border = tokens.success;
                bg = tokens.successBg;
              } else if (_submitted && isSelected) {
                border = tokens.danger;
                bg = tokens.dangerBg;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _submitted
                      ? null
                      : () => setState(() => _selected = i),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: Text(
                      c.options[i],
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (_submitted) ...[
              const SizedBox(height: 6),
              Text(
                _correct ? 'Correct!' : 'Not quite.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _correct ? tokens.success : tokens.danger,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                c.explanation,
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _submitted
                    ? _continue
                    : (_selected == null ? null : _submit),
                child: Text(
                  _submitted ? 'Submit application' : 'Check answer',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
