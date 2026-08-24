import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// Style variants supported by [AppCard].
enum AppCardVariant {
  /// Standard elevated card with ambient depth shadows and subtle border.
  elevated,

  /// Crisp flat outlined card with no shadow.
  outlined,

  /// Softly filled background with no elevation shadow.
  filled,

  /// Glassmorphic translucent card with subtle background blur.
  glass,

  /// Custom or themed gradient surface card.
  gradient,
}

/// The standard SkillMatch elevated card system:
/// - Subtle borders matching light/dark themes
/// - Multi-layer ambient and key elevation shadows
/// - Springy touch-scale micro-animations on tap/press
/// - Full variant system ([AppCardVariant.elevated], [AppCardVariant.outlined], etc.)
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.elevated,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.color,
    this.borderColor,
    this.borderWidth,
    this.boxShadow,
    this.gradient,
    this.onTap,
    this.onLongPress,
    this.animateScaleOnTap = true,
    this.enableFeedback = true,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final Color? borderColor;
  final double? borderWidth;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool animateScaleOnTap;
  final bool enableFeedback;
  final Clip clipBehavior;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  bool get _isInteractive => widget.onTap != null || widget.onLongPress != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.982).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (_isInteractive && widget.animateScaleOnTap) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isInteractive && widget.animateScaleOnTap) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isInteractive && widget.animateScaleOnTap) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appTokens = context.appColors;
    final isDark = context.isDarkMode;
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(16);

    Color surfaceColor;
    Border? border;
    List<BoxShadow>? shadows;
    Gradient? effectiveGradient = widget.gradient;

    switch (widget.variant) {
      case AppCardVariant.elevated:
        surfaceColor = widget.color ?? (isDark ? appTokens.cardBackground : Colors.white);
        border = Border.all(
          color: widget.borderColor ?? appTokens.cardBorderSoft,
          width: widget.borderWidth ?? 1.0,
        );
        shadows = widget.boxShadow ?? appTokens.cardShadows;
        break;

      case AppCardVariant.outlined:
        surfaceColor = widget.color ?? (isDark ? appTokens.cardBackground : Colors.white);
        border = Border.all(
          color: widget.borderColor ?? appTokens.cardBorder,
          width: widget.borderWidth ?? 1.0,
        );
        shadows = widget.boxShadow;
        break;

      case AppCardVariant.filled:
        surfaceColor = widget.color ?? appTokens.surfaceMuted;
        border = Border.all(
          color: widget.borderColor ?? appTokens.cardBorderSoft,
          width: widget.borderWidth ?? 1.0,
        );
        shadows = widget.boxShadow;
        break;

      case AppCardVariant.glass:
        surfaceColor = widget.color ?? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.75));
        border = Border.all(
          color: widget.borderColor ?? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.6)),
          width: widget.borderWidth ?? 1.0,
        );
        shadows = widget.boxShadow ?? [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0x0A0F172A),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];
        break;

      case AppCardVariant.gradient:
        surfaceColor = widget.color ?? Colors.transparent;
        effectiveGradient ??= appTokens.primaryGradient;
        border = Border.all(
          color: widget.borderColor ?? Colors.white.withValues(alpha: 0.15),
          width: widget.borderWidth ?? 1.0,
        );
        shadows = widget.boxShadow ?? [
          BoxShadow(
            color: appTokens.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];
        break;
    }

    Widget content = Padding(
      padding: widget.padding,
      child: widget.child,
    );

    if (_isInteractive) {
      content = Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        clipBehavior: widget.clipBehavior,
        child: InkWell(
          borderRadius: effectiveRadius,
          enableFeedback: widget.enableFeedback,
          onTap: widget.onTap != null
              ? () {
                  if (widget.enableFeedback) {
                    HapticFeedback.selectionClick();
                  }
                  widget.onTap!();
                }
              : null,
          onLongPress: widget.onLongPress != null
              ? () {
                  if (widget.enableFeedback) {
                    HapticFeedback.mediumImpact();
                  }
                  widget.onLongPress!();
                }
              : null,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    Widget cardBody = Container(
      decoration: BoxDecoration(
        color: effectiveGradient == null ? surfaceColor : null,
        gradient: effectiveGradient,
        borderRadius: effectiveRadius,
        border: border,
        boxShadow: shadows,
      ),
      clipBehavior: widget.clipBehavior,
      child: widget.variant == AppCardVariant.glass
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: content,
            )
          : content,
    );

    if (_isInteractive && widget.animateScaleOnTap) {
      cardBody = AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: cardBody,
      );
    }

    if (widget.margin != null) {
      cardBody = Padding(padding: widget.margin!, child: cardBody);
    }

    return cardBody;
  }
}
