import 'package:flutter/material.dart';

import 'package:skillmatch/theme/app_colors.dart';
import 'centered_form_width.dart';

/// Layout for the sign-in / sign-up screens: a gradient header with the
/// app logo, title and subtitle, and the form in a card that overlaps it.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;

  /// The form, shown inside the card.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: tokens.scaffoldBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Positioned(right: -40, top: -30, child: _circle(160, 0.10)),
                    Positioned(left: -30, bottom: 10, child: _circle(90, 0.07)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 64),
                      child: CenteredFormWidth(
                        child: Column(
                          children: [
                            SizedBox(
                              height: 40,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: canPop
                                    ? IconButton(
                                        tooltip: 'Back',
                                        icon: const Icon(
                                          Icons.arrow_back_rounded,
                                          color: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).maybePop(),
                                      )
                                    : null,
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.bolt,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CenteredFormWidth(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                    decoration: BoxDecoration(
                      color: tokens.cardBackground,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: tokens.cardBorderSoft),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.isDark
                              ? Colors.black.withValues(alpha: 0.35)
                              : const Color(0x140F172A),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Widget _circle(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}
