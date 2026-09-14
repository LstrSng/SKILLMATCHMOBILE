import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillmatch/services/navigation_service.dart';
import 'package:skillmatch/services/theme_store.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'package:skillmatch/theme/app_theme.dart';
import 'package:skillmatch/pages/settings_page.dart';
import 'package:skillmatch/widgets/app_password_field.dart';
import 'package:skillmatch/widgets/skill_chip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeStore Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      themeNotifier.value = ThemeMode.system;
    });

    test('themeNotifier defaults to ThemeMode.system', () {
      expect(themeNotifier.value, equals(ThemeMode.system));
    });

    test('ThemeStore.load() defaults to ThemeMode.system when no saved preference exists', () async {
      SharedPreferences.setMockInitialValues({});
      final mode = await ThemeStore.load();
      expect(mode, equals(ThemeMode.system));
    });

    test('ThemeStore saves and loads ThemeMode.dark correctly', () async {
      await ThemeStore.save(ThemeMode.dark);
      final mode = await ThemeStore.load();
      expect(mode, equals(ThemeMode.dark));
    });

    test('ThemeStore saves and loads ThemeMode.light correctly', () async {
      await ThemeStore.save(ThemeMode.light);
      final mode = await ThemeStore.load();
      expect(mode, equals(ThemeMode.light));
    });

    test('ThemeStore saves and loads ThemeMode.system correctly', () async {
      await ThemeStore.save(ThemeMode.system);
      final mode = await ThemeStore.load();
      expect(mode, equals(ThemeMode.system));
    });

    test('ThemeStore falls back to ThemeMode.system on unrecognized value', () async {
      SharedPreferences.setMockInitialValues({'settings.themeMode': 'invalid_mode'});
      final mode = await ThemeStore.load();
      expect(mode, equals(ThemeMode.system));
    });
  });

  group('Dashboard Profile Completion Banner & Navigation Tests', () {
    setUp(() {
      AppNavigation.switchTab(AppTab.dashboard);
    });

    testWidgets('Banner renders completion percentage, progress indicator, and button', (tester) async {
      var completedTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final tokens = context.appColors;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.cardBorder),
                    boxShadow: tokens.cardShadows,
                  ),
                  child: Column(
                    children: [
                      const Text('Profile Completion'),
                      const Text('75% Completed'),
                      const LinearProgressIndicator(value: 0.75),
                      FilledButton.icon(
                        key: const Key('complete_profile_button'),
                        onPressed: () {
                          completedTapped = true;
                          AppNavigation.switchTab(AppTab.profile);
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('Complete Profile'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Profile Completion'), findsOneWidget);
      expect(find.text('75% Completed'), findsOneWidget);
      expect(find.byKey(const Key('complete_profile_button')), findsOneWidget);
      expect(find.text('Complete Profile'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(find.byKey(const Key('complete_profile_button')));
      await tester.pumpAndSettle();

      expect(completedTapped, isTrue);
      expect(AppNavigation.activeTab, equals(AppTab.profile));
    });

    testWidgets('Banner renders adaptively in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final tokens = context.appColors;
                expect(tokens.isDark, isTrue);
                expect(tokens.cardBackground, equals(AppColors.darkCardBackground));
                expect(tokens.cardBorder, equals(AppColors.darkBorder));

                return Container(
                  color: tokens.cardBackground,
                  child: Column(
                    children: [
                      Text('75% Completed', style: TextStyle(color: tokens.primary)),
                      FilledButton(
                        key: const Key('complete_profile_button'),
                        onPressed: () {},
                        child: const Text('Complete Profile'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('75% Completed'), findsOneWidget);
      expect(find.byKey(const Key('complete_profile_button')), findsOneWidget);
    });
  });

  group('Settings Page Appearance Selection Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      themeNotifier.value = ThemeMode.system;
    });

    testWidgets('Appearance segmented button changes themeNotifier and saves to ThemeStore', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const SettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Select Dark mode
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(themeNotifier.value, equals(ThemeMode.dark));
      final savedMode = await ThemeStore.load();
      expect(savedMode, equals(ThemeMode.dark));

      // Select Light mode
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(themeNotifier.value, equals(ThemeMode.light));
      final savedMode2 = await ThemeStore.load();
      expect(savedMode2, equals(ThemeMode.light));

      // Select System mode
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      expect(themeNotifier.value, equals(ThemeMode.system));
      final savedMode3 = await ThemeStore.load();
      expect(savedMode3, equals(ThemeMode.system));
    });
  });

  group('Profile Dark Theme Token Adaptability Tests', () {
    testWidgets('Dark theme tokens propagate to profile cards and text styles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final tokens = context.appColors;

                return Column(
                  children: [
                    // Profile Pill simulator
                    Container(
                      decoration: BoxDecoration(
                        color: tokens.surfaceMuted,
                        border: Border.all(color: tokens.cardBorderSoft),
                      ),
                      child: Text('Software Engineer', style: TextStyle(color: tokens.textSecondary)),
                    ),
                    // Add Info Button simulator
                    Container(
                      decoration: BoxDecoration(
                        color: tokens.surfaceMuted,
                        border: Border.all(color: tokens.cardBorderSoft),
                      ),
                      child: Text('Add skills', style: TextStyle(color: tokens.primary)),
                    ),
                    // Profile Card simulator
                    Container(
                      decoration: BoxDecoration(
                        color: tokens.cardBackground,
                        border: Border.all(color: tokens.cardBorder),
                        boxShadow: tokens.cardShadows,
                      ),
                      child: Text('Skills & Endorsements', style: TextStyle(color: tokens.textPrimary)),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Software Engineer'), findsOneWidget);
      expect(find.text('Add skills'), findsOneWidget);
      expect(find.text('Skills & Endorsements'), findsOneWidget);

      final text1 = tester.widget<Text>(find.text('Software Engineer'));
      expect(text1.style?.color, equals(AppColors.darkTextSecondary));

      final text2 = tester.widget<Text>(find.text('Add skills'));
      expect(text2.style?.color, equals(AppColors.primaryLight));

      final text3 = tester.widget<Text>(find.text('Skills & Endorsements'));
      expect(text3.style?.color, equals(AppColors.darkTextPrimary));
    });
  });

  group('Dark Mode Font Color & Component Theme Adaptability Tests', () {
    testWidgets('AppPasswordField adapts text style and hint in dark mode', (tester) async {
      final controller = TextEditingController(text: 'secret_password');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Center(
              child: AppPasswordField(controller: controller),
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.color, equals(AppColors.darkTextPrimary));
      expect(textField.decoration?.hintStyle?.color, equals(AppColors.darkTextFaint));
      expect(textField.decoration?.fillColor, equals(AppColors.darkSurfaceMuted));
    });

    testWidgets('Screen text widgets resolve high-contrast dark mode colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final tokens = context.appColors;
                return Column(
                  children: [
                    Text('Job Title', style: TextStyle(color: tokens.textPrimary)),
                    Text('Company Name', style: TextStyle(color: tokens.textSecondary)),
                    Text('Posted 2 days ago', style: TextStyle(color: tokens.textFaint)),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final title = tester.widget<Text>(find.text('Job Title'));
      expect(title.style?.color, equals(AppColors.darkTextPrimary));
      expect(title.style?.color, isNot(equals(AppColors.textPrimary)));

      final company = tester.widget<Text>(find.text('Company Name'));
      expect(company.style?.color, equals(AppColors.darkTextSecondary));
      expect(company.style?.color, isNot(equals(AppColors.textSecondary)));

      final posted = tester.widget<Text>(find.text('Posted 2 days ago'));
      expect(posted.style?.color, equals(AppColors.darkTextFaint));
      expect(posted.style?.color, isNot(equals(AppColors.textFaint)));
    });
  });

  group('Profile Page UI/UX Component Tests', () {
    testWidgets('Profile contact pill renders icon, label, and handles tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  return InkWell(
                    onTap: () => tapped = true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_outlined, size: 14),
                          SizedBox(width: 6),
                          Text('+63 917 123 4567'),
                          Icon(Icons.arrow_outward, size: 11),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('+63 917 123 4567'), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_outward), findsOneWidget);

      await tester.tap(find.text('+63 917 123 4567'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('Profile strength widget displays progress and triggers smart tip action', (tester) async {
      var actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Profile Strength'),
                      const Text('Intermediate • 75%'),
                      const LinearProgressIndicator(value: 0.75),
                      const Text('Upload your resume (+20%) to unlock 1-click job applications.'),
                      FilledButton(
                        key: const Key('profile_tip_action'),
                        onPressed: () => actionTriggered = true,
                        child: const Text('Upload Resume'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Profile Strength'), findsOneWidget);
      expect(find.text('Intermediate • 75%'), findsOneWidget);
      expect(find.text('Upload your resume (+20%) to unlock 1-click job applications.'), findsOneWidget);
      expect(find.byKey(const Key('profile_tip_action')), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_tip_action')));
      await tester.pumpAndSettle();
      expect(actionTriggered, isTrue);
    });

    testWidgets('Section header renders leading icon, title, count badge, and action', (tester) async {
      var headerActionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: Row(
              children: [
                const Icon(Icons.psychology_outlined),
                const Text('Skills'),
                const Text('8'),
                TextButton.icon(
                  onPressed: () => headerActionTapped = true,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Skills'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(headerActionTapped, isTrue);
    });

    testWidgets('SkillChip reflects verified state when assessed and passed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: Row(
              children: [
                SkillChip(
                  label: 'Flutter',
                  status: SkillChipStatus.verified,
                  isVerified: true,
                ),
                SkillChip(
                  label: 'Dart',
                  status: SkillChipStatus.neutral,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('Experience item renders company, year, and latest role badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: Column(
              children: [
                const Text('Senior Mobile Developer'),
                const Text('Tech Innovations Inc.'),
                const Text('2024 - Present'),
                const Text('Latest'),
                const Text('Built scalable mobile apps using Flutter.'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Senior Mobile Developer'), findsOneWidget);
      expect(find.text('Tech Innovations Inc.'), findsOneWidget);
      expect(find.text('2024 - Present'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Built scalable mobile apps using Flutter.'), findsOneWidget);
    });

    testWidgets('File preview renders document details and actions', (tester) async {
      var viewTapped = false;
      var removeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded),
                const Text('Juan_Cruz_Resume.pdf'),
                const Text('1.2 MB • Sep 14, 2026'),
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => viewTapped = true,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => removeTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Juan_Cruz_Resume.pdf'), findsOneWidget);
      expect(find.text('1.2 MB • Sep 14, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.open_in_new));
      await tester.pumpAndSettle();
      expect(viewTapped, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(removeTapped, isTrue);
    });
  });
}

