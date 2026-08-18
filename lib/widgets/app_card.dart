import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The standard SkillMatch card container: theme surface color, 16px
/// radius, soft floating shadow instead of a flat border. This exact
/// decoration was previously duplicated as an inline
/// `Container(decoration: BoxDecoration(...))` across most pages — use
/// this instead of retyping it.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final decorated = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: radius,
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
    );
    return margin == null ? decorated : Padding(padding: margin!, child: decorated);
  }
}
