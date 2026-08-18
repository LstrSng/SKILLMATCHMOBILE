import 'package:flutter/material.dart';

/// Constrains and centers form content on wide screens (tablets, desktop
/// windows) so buttons and text fields don't stretch edge-to-edge, while
/// staying full-width on phones. Wrap the top-level `Column` of an
/// auth-style page's scroll view with this.
class CenteredFormWidth extends StatelessWidget {
  const CenteredFormWidth({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
