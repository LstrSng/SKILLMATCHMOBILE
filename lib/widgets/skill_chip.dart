import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// Semantic status of a [SkillChip].
enum SkillChipStatus {
  /// User's skills match the job requirement (Emerald / Success).
  matched,

  /// Skill is required but currently missing from user's profile (Rose / Alert).
  missing,

  /// Skill has been proven / verified via skill assessment (Indigo / Verified).
  verified,

  /// Neutral skill tag without specific match state.
  neutral,

  /// Interactive selectable chip (e.g. for filter bars and skill selectors).
  selectable,
}

/// Sizing scale for [SkillChip].
enum SkillChipSize {
  /// Compact for dense list cards and wrap rows.
  small,

  /// Standard for profile sections, detail views, and pathways.
  medium,

  /// Prominent for filters and interactive quiz tags.
  large,
}

/// A versatile, elevated skill chip component for SkillMatch+.
/// Supports verified badges, missing skill alerts, selection toggles,
/// delete actions, and interactive touch-scale micro-animations.
class SkillChip extends StatefulWidget {
  const SkillChip({
    super.key,
    required this.label,
    this.status = SkillChipStatus.neutral,
    this.size = SkillChipSize.medium,
    this.isVerified = false,
    this.isMissingAlert = false,
    this.selected = false,
    this.showIcon = true,
    this.customIcon,
    this.avatar,
    this.onTap,
    this.onSelected,
    this.onDeleted,
    this.tooltip,
    this.animateOnTap = true,
  });

  /// Skill label text.
  final String label;

  /// Semantic match/state status.
  final SkillChipStatus status;

  /// Sizing dimension.
  final SkillChipSize size;

  /// Whether to display the verified assessment badge.
  final bool isVerified;

  /// Whether to emphasize a missing skill alert.
  final bool isMissingAlert;

  /// Selection state (used when [status] is [SkillChipStatus.selectable]).
  final bool selected;

  /// Whether to render the leading status icon.
  final bool showIcon;

  /// Custom icon override.
  final IconData? customIcon;

  /// Optional avatar widget.
  final Widget? avatar;

  /// Interactive tap callback.
  final VoidCallback? onTap;

  /// Selection toggle callback.
  final ValueChanged<bool>? onSelected;

  /// Deletion callback for removable chips.
  final VoidCallback? onDeleted;

  /// Optional tooltip message.
  final String? tooltip;

  /// Whether to animate touch scale on press.
  final bool animateOnTap;

  @override
  State<SkillChip> createState() => _SkillChipState();
}

class _SkillChipState extends State<SkillChip> with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  bool get _isInteractive =>
      widget.onTap != null || widget.onSelected != null || widget.onDeleted != null;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (_isInteractive && widget.animateOnTap) {
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isInteractive && widget.animateOnTap) {
      _pressController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isInteractive && widget.animateOnTap) {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final tokens = context.appColors;

    // Determine dimensions by size
    final double fontSize;
    final double iconSize;
    final EdgeInsetsGeometry padding;
    final double borderRadius;

    switch (widget.size) {
      case SkillChipSize.small:
        fontSize = 11.5;
        iconSize = 12.0;
        padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
        borderRadius = 10.0;
        break;
      case SkillChipSize.medium:
        fontSize = 13.0;
        iconSize = 14.0;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
        borderRadius = 12.0;
        break;
      case SkillChipSize.large:
        fontSize = 14.0;
        iconSize = 16.0;
        padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8);
        borderRadius = 14.0;
        break;
    }

    // Determine color styling
    Color bg;
    Color fg;
    Color border;
    IconData? defaultIcon;

    final effectiveStatus = (widget.status == SkillChipStatus.neutral && widget.isVerified)
        ? SkillChipStatus.verified
        : widget.status;

    switch (effectiveStatus) {
      case SkillChipStatus.matched:
        bg = isDark ? AppColors.badgeHighMatchDarkBg : AppColors.badgeHighMatchBg;
        fg = isDark ? AppColors.badgeHighMatchDark : const Color(0xFF065F46);
        border = isDark ? const Color(0xFF065F46) : const Color(0xFF6EE7B7);
        defaultIcon = Icons.check_circle_rounded;
        break;

      case SkillChipStatus.missing:
        bg = isDark ? AppColors.badgeGapMatchDarkBg : AppColors.badgeGapMatchBg;
        fg = isDark ? AppColors.badgeGapMatchDark : const Color(0xFF991B1B);
        border = isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5);
        defaultIcon = Icons.cancel_rounded;
        break;

      case SkillChipStatus.verified:
        bg = isDark ? AppColors.verifiedDarkSoft : AppColors.verifiedSoft;
        fg = isDark ? AppColors.verifiedDark : AppColors.verified;
        border = isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE);
        defaultIcon = Icons.verified_rounded;
        break;

      case SkillChipStatus.selectable:
        if (widget.selected) {
          bg = isDark ? tokens.primarySoftBg : AppColors.primarySoftBg;
          fg = isDark ? tokens.primary : AppColors.primary;
          border = isDark ? tokens.primary : AppColors.primaryLight;
          defaultIcon = Icons.check_rounded;
        } else {
          bg = isDark ? tokens.surfaceMuted : AppColors.surfaceMuted;
          fg = isDark ? tokens.textSecondary : AppColors.textSecondary;
          border = isDark ? tokens.cardBorderSoft : AppColors.borderSoft;
          defaultIcon = null;
        }
        break;

      case SkillChipStatus.neutral:
        bg = isDark ? tokens.surfaceMuted : const Color(0xFFEFF6FF);
        fg = isDark ? tokens.textPrimary : const Color(0xFF1D4ED8);
        border = isDark ? tokens.cardBorder : const Color(0xFFDBEAFE);
        defaultIcon = null;
        break;
    }

    if (widget.isMissingAlert) {
      border = isDark ? AppColors.dangerLight : AppColors.danger;
    }

    final effectiveIcon = widget.customIcon ?? defaultIcon;

    Widget chipContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: border,
          width: widget.isMissingAlert ? 1.4 : 1.0,
        ),
        boxShadow: widget.isMissingAlert
            ? [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: isDark ? 0.25 : 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.avatar != null) ...[
            widget.avatar!,
            const SizedBox(width: 5),
          ] else if (widget.showIcon && effectiveIcon != null) ...[
            Icon(effectiveIcon, color: fg, size: iconSize),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: -0.1,
                height: 1.15,
              ),
            ),
          ),
          if (widget.isVerified && effectiveStatus != SkillChipStatus.verified) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.verified_rounded,
              color: isDark ? AppColors.verifiedDark : AppColors.verified,
              size: iconSize,
            ),
          ],
          if (widget.isMissingAlert) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ],
          if (widget.onDeleted != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onDeleted!();
              },
              child: Icon(
                Icons.close_rounded,
                color: fg.withValues(alpha: 0.7),
                size: iconSize + 1,
              ),
            ),
          ],
        ],
      ),
    );

    if (_isInteractive) {
      chipContent = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: () {
          HapticFeedback.selectionClick();
          if (widget.onSelected != null) {
            widget.onSelected!(!widget.selected);
          } else if (widget.onTap != null) {
            widget.onTap!();
          }
        },
        child: chipContent,
      );
    }

    if (_isInteractive && widget.animateOnTap) {
      chipContent = AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: chipContent,
      );
    }

    if (widget.tooltip != null) {
      chipContent = Tooltip(
        message: widget.tooltip!,
        child: chipContent,
      );
    }

    return chipContent;
  }
}
