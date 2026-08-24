import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// Presentation variants for [MatchScoreBadge].
enum MatchScoreBadgeVariant {
  /// Standard horizontal pill with indicator dot/icon and label (e.g., "85% Match").
  pill,

  /// Radial circular indicator with animated progress ring.
  circular,

  /// Prominent hero tile with gradient surface and tier status.
  hero,

  /// Ultra-compact percentage badge for tight list items.
  compact,
}

/// A custom, animated match score badge component for SkillMatch+.
/// Supports score tier resolution (Emerald, Cobalt, Amber, Rose),
/// multiple layout variants, animated progress sweep, and interactive taps.
class MatchScoreBadge extends StatelessWidget {
  const MatchScoreBadge({
    super.key,
    required this.score,
    this.variant = MatchScoreBadgeVariant.pill,
    this.label,
    this.showLabel = true,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 600),
    this.size,
    this.onTap,
    this.tooltip,
  });

  /// Match percentage from 0 to 100.
  final int score;

  /// Presentation layout variant.
  final MatchScoreBadgeVariant variant;

  /// Optional text label override (defaults to "Match" or tier name).
  final String? label;

  /// Whether to display the text label alongside the percentage.
  final bool showLabel;

  /// Whether to animate the score count-up / circular sweep.
  final bool animate;

  /// Duration of the score count-up / circular sweep animation.
  final Duration animationDuration;

  /// Custom size dimension (applies to circular diameter or compact sizing).
  final double? size;

  /// Interactive tap callback.
  final VoidCallback? onTap;

  /// Optional tooltip message.
  final String? tooltip;

  int get _clampedScore => score.clamp(0, 100);

  String _tierLabel(int score) {
    if (score >= 85) return 'Great Match';
    if (score >= 70) return 'Good Match';
    if (score >= 50) return 'Moderate Match';
    return 'Skill Gap';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final clamped = _clampedScore;
    final color = AppColors.matchColor(clamped, isDark: isDark);
    final bg = AppColors.matchBgColor(clamped, isDark: isDark);
    final border = AppColors.matchBorderColor(clamped, isDark: isDark);

    Widget badgeWidget;

    switch (variant) {
      case MatchScoreBadgeVariant.pill:
        badgeWidget = _buildPillBadge(context, clamped, color, bg, border, isDark);
        break;
      case MatchScoreBadgeVariant.circular:
        badgeWidget = _buildCircularBadge(context, clamped, color, bg, border, isDark);
        break;
      case MatchScoreBadgeVariant.hero:
        badgeWidget = _buildHeroBadge(context, clamped, color, bg, border, isDark);
        break;
      case MatchScoreBadgeVariant.compact:
        badgeWidget = _buildCompactBadge(context, clamped, color, bg, border, isDark);
        break;
    }

    if (tooltip != null) {
      badgeWidget = Tooltip(
        message: tooltip!,
        child: badgeWidget,
      );
    }

    if (onTap != null) {
      badgeWidget = InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        borderRadius: BorderRadius.circular(variant == MatchScoreBadgeVariant.circular ? 999 : 12),
        child: badgeWidget,
      );
    }

    return badgeWidget;
  }

  Widget _buildPillBadge(
    BuildContext context,
    int clamped,
    Color color,
    Color bg,
    Color border,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _AnimatedScoreText(
            targetScore: clamped,
            animate: animate,
            duration: animationDuration,
            suffix: '%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              letterSpacing: -0.2,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              label ?? 'Match',
              style: TextStyle(
                color: color.withValues(alpha: isDark ? 0.9 : 0.85),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularBadge(
    BuildContext context,
    int clamped,
    Color color,
    Color bg,
    Color border,
    bool isDark,
  ) {
    final effectiveSize = size ?? 54.0;
    final strokeWidth = effectiveSize * 0.095;

    Widget progressRing(double progress) {
      return SizedBox(
        width: effectiveSize,
        height: effectiveSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle track
            CustomPaint(
              size: Size(effectiveSize, effectiveSize),
              painter: _RingPainter(
                progress: 1.0,
                color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.12),
                strokeWidth: strokeWidth,
              ),
            ),
            // Progress arc
            CustomPaint(
              size: Size(effectiveSize, effectiveSize),
              painter: _RingPainter(
                progress: progress,
                color: color,
                strokeWidth: strokeWidth,
              ),
            ),
            // Center score text
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: effectiveSize * 0.28,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                if (showLabel && effectiveSize >= 56)
                  Text(
                    'Match',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: effectiveSize * 0.17,
                      height: 1.1,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (!animate) {
      return progressRing(clamped / 100.0);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: clamped / 100.0),
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      builder: (context, val, _) => progressRing(val),
    );
  }

  Widget _buildHeroBadge(
    BuildContext context,
    int clamped,
    Color color,
    Color bg,
    Color border,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildCircularBadge(context, clamped, color, bg, border, isDark),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label ?? _tierLabel(clamped),
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  clamped >= 70
                      ? 'You meet most requirements for this role'
                      : 'Closing a few skill gaps can boost this match',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBadge(
    BuildContext context,
    int clamped,
    Color color,
    Color bg,
    Color border,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.8),
      ),
      child: _AnimatedScoreText(
        targetScore: clamped,
        animate: animate,
        duration: animationDuration,
        suffix: '%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _AnimatedScoreText extends StatelessWidget {
  const _AnimatedScoreText({
    required this.targetScore,
    required this.animate,
    required this.duration,
    required this.style,
    this.suffix = '',
  });

  final int targetScore;
  final bool animate;
  final Duration duration;
  final TextStyle style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return Text('$targetScore$suffix', style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetScore.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text('${value.round()}$suffix', style: style);
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
