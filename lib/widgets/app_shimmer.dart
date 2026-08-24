import 'package:flutter/material.dart';

import 'package:skillmatch/theme/app_colors.dart';
import 'app_card.dart';

/// A smooth, high-performance shimmer animation wrapper.
/// Animates a shimmering light gradient sweep across child placeholders.
class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final val = _controller.value;
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: [base, highlight, base],
              stops: [
                (val - 0.3).clamp(0.0, 1.0),
                val.clamp(0.0, 1.0),
                (val + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A rounded placeholder container used within shimmer skeletons.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.color,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final defaultColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? defaultColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton loader mimicking the layout of a [_JobCard].
class JobCardSkeleton extends StatelessWidget {
  const JobCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Title/Company + Score Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 44, height: 44, borderRadius: 12),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 160, height: 16, borderRadius: 6),
                      SizedBox(height: 8),
                      ShimmerBox(width: 100, height: 12, borderRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const ShimmerBox(width: 58, height: 26, borderRadius: 20),
              ],
            ),
            const SizedBox(height: 14),

            // Metadata pills row
            const Row(
              children: [
                ShimmerBox(width: 80, height: 22, borderRadius: 8),
                SizedBox(width: 6),
                ShimmerBox(width: 70, height: 22, borderRadius: 8),
                SizedBox(width: 6),
                ShimmerBox(width: 75, height: 22, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar skeleton
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 110, height: 10, borderRadius: 4),
                ShimmerBox(width: 40, height: 10, borderRadius: 4),
              ],
            ),
            const SizedBox(height: 6),
            const ShimmerBox(height: 4, borderRadius: 4),
            const SizedBox(height: 12),

            // Skill chips skeleton
            const Row(
              children: [
                ShimmerBox(width: 65, height: 24, borderRadius: 10),
                SizedBox(width: 6),
                ShimmerBox(width: 80, height: 24, borderRadius: 10),
                SizedBox(width: 6),
                ShimmerBox(width: 70, height: 24, borderRadius: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader mimicking the layout of the Job Details page.
class JobDetailSkeleton extends StatelessWidget {
  const JobDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card skeleton
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(width: 48, height: 48, borderRadius: 12),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 180, height: 20, borderRadius: 6),
                            SizedBox(height: 8),
                            ShimmerBox(width: 120, height: 14, borderRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const ShimmerBox(width: 54, height: 54, borderRadius: 27),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      ShimmerBox(width: 90, height: 24, borderRadius: 8),
                      SizedBox(width: 8),
                      ShimmerBox(width: 80, height: 24, borderRadius: 8),
                      SizedBox(width: 8),
                      ShimmerBox(width: 85, height: 24, borderRadius: 8),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const ShimmerBox(height: 48, borderRadius: 12),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Description card skeleton
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBox(width: 130, height: 16, borderRadius: 6),
                  const SizedBox(height: 12),
                  const ShimmerBox(height: 12, borderRadius: 4),
                  const SizedBox(height: 8),
                  const ShimmerBox(height: 12, borderRadius: 4),
                  const SizedBox(height: 8),
                  const ShimmerBox(width: 220, height: 12, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Skill matrix skeleton
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerBox(width: 170, height: 18, borderRadius: 6),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Expanded(child: ShimmerBox(height: 36, borderRadius: 10)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 36, borderRadius: 10)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 36, borderRadius: 10)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const ShimmerBox(height: 44, borderRadius: 12),
                  const SizedBox(height: 10),
                  const ShimmerBox(height: 44, borderRadius: 12),
                  const SizedBox(height: 10),
                  const ShimmerBox(height: 44, borderRadius: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
