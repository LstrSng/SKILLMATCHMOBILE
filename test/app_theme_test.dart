import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'package:skillmatch/theme/app_theme.dart';

void main() {
  group('AppTheme Tests', () {
    test('buildLightTheme generates light theme data with AppThemeExtension', () {
      final theme = buildLightTheme();
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.pageBackground));

      final ext = theme.extension<AppThemeExtension>();
      expect(ext, isNotNull);
      expect(ext!.isDark, isFalse);
      expect(ext.cardBackground, equals(Colors.white));
      expect(ext.textPrimary, equals(AppColors.textPrimary));
    });

    test('buildDarkTheme generates dark theme data with AppThemeExtension', () {
      final theme = buildDarkTheme();
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.darkPageBackground));

      final ext = theme.extension<AppThemeExtension>();
      expect(ext, isNotNull);
      expect(ext!.isDark, isTrue);
      expect(ext.cardBackground, equals(AppColors.darkCardBackground));
      expect(ext.textPrimary, equals(AppColors.darkTextPrimary));
    });

    test('Typography scale has calibrated letter-spacing and line-heights', () {
      final theme = buildLightTheme();
      final textTheme = theme.textTheme;

      expect(textTheme.headlineLarge?.letterSpacing, equals(-0.6));
      expect(textTheme.headlineMedium?.letterSpacing, equals(-0.4));
      expect(textTheme.titleLarge?.letterSpacing, equals(-0.2));
      expect(textTheme.bodyLarge?.letterSpacing, equals(0.1));
      expect(textTheme.labelSmall?.letterSpacing, equals(0.4));
    });

    testWidgets('BuildContext extension resolves light tokens in light mode', (tester) async {
      late AppThemeExtension lightTokens;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Builder(
            builder: (context) {
              lightTokens = context.appColors;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(lightTokens.isDark, isFalse);
      expect(lightTokens.cardBackground, equals(Colors.white));
    });

    testWidgets('BuildContext extension resolves dark tokens in dark mode', (tester) async {
      late AppThemeExtension darkTokens;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Builder(
            builder: (context) {
              darkTokens = context.appColors;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(darkTokens.isDark, isTrue);
      expect(darkTokens.cardBackground, equals(AppColors.darkCardBackground));
    });
  });
}
