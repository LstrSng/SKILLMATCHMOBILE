import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillmatch/models/training_pathway.dart';
import 'package:skillmatch/pages/pathway_page.dart';
import 'package:skillmatch/services/pathway_links_data.dart';
import 'package:skillmatch/widgets/training_pathway_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pathway Links Data Tests', () {
    test('allTrainingPathways includes enriched mobile and web pathways', () async {
      final pathways = await allTrainingPathways();
      expect(pathways.isNotEmpty, isTrue);

      final mobilePathway = pathways.firstWhere(
        (p) => p.name == 'Mobile App Development (Cross-Platform)',
      );
      expect(mobilePathway.links.length, greaterThanOrEqualTo(4));

      final androidPathway = pathways.firstWhere(
        (p) => p.name == 'Android Development',
      );
      expect(androidPathway.links.length, greaterThanOrEqualTo(4));

      final iosPathway = pathways.firstWhere(
        (p) => p.name == 'iOS Development',
      );
      expect(iosPathway.links.length, greaterThanOrEqualTo(4));

      final fullStackPathway = pathways.firstWhere(
        (p) => p.name == 'Full-Stack & General Development',
      );
      expect(fullStackPathway.links.length, greaterThanOrEqualTo(4));

      final frontEndPathway = pathways.firstWhere(
        (p) => p.name == 'JavaScript & Front-End',
      );
      expect(frontEndPathway.links.length, greaterThanOrEqualTo(4));

      final backEndPathway = pathways.firstWhere(
        (p) => p.name == 'Back-End Development',
      );
      expect(backEndPathway.links.length, greaterThanOrEqualTo(4));

      final generalWebPathway = pathways.firstWhere(
        (p) => p.name == 'General Web / CMS',
      );
      expect(generalWebPathway.links.length, greaterThanOrEqualTo(3));

      final typeScriptPathway = pathways.firstWhere(
        (p) => p.name == 'TypeScript Development',
      );
      expect(typeScriptPathway.links.length, greaterThanOrEqualTo(4));
    });

    test('all links have valid HTTPS URLs and descriptive labels', () async {
      final pathways = await allTrainingPathways();
      for (final pathway in pathways) {
        for (final link in pathway.links) {
          expect(link.label.trim().isNotEmpty, isTrue);
          expect(link.url.startsWith('https://'), isTrue);
          final uri = Uri.tryParse(link.url);
          expect(uri, isNotNull);
          expect(uri!.hasScheme, isTrue);
          expect(uri.host.isNotEmpty, isTrue);
        }
      }
    });

    test('trainingPathwayForRole correctly maps mobile and web job roles', () async {
      final flutterRole = await trainingPathwayForRole('Flutter Developer');
      expect(flutterRole, isNotNull);
      expect(flutterRole!.name, equals('Mobile App Development (Cross-Platform)'));

      final reactNativeRole = await trainingPathwayForRole('React Native Developer');
      expect(reactNativeRole, isNotNull);
      expect(reactNativeRole!.name, equals('Mobile App Development (Cross-Platform)'));

      final mobileRole = await trainingPathwayForRole('Mobile Developer');
      expect(mobileRole, isNotNull);
      expect(mobileRole!.name, equals('Mobile App Development (Cross-Platform)'));

      final androidRole = await trainingPathwayForRole('Android Developer');
      expect(androidRole, isNotNull);
      expect(androidRole!.name, equals('Android Development'));

      final iosRole = await trainingPathwayForRole('iOS Developer');
      expect(iosRole, isNotNull);
      expect(iosRole!.name, equals('iOS Development'));

      final webRole = await trainingPathwayForRole('Web Developer');
      expect(webRole, isNotNull);
      expect(webRole!.name, equals('General Web / CMS'));

      final frontEndRole = await trainingPathwayForRole('Front End Developer');
      expect(frontEndRole, isNotNull);
      expect(frontEndRole!.name, equals('JavaScript & Front-End'));

      final fullStackRole = await trainingPathwayForRole('Full Stack Developer');
      expect(fullStackRole, isNotNull);
      expect(fullStackRole!.name, equals('Full-Stack & General Development'));

      final typeScriptRole = await trainingPathwayForRole('TypeScript Developer');
      expect(typeScriptRole, isNotNull);
      expect(typeScriptRole!.name, equals('TypeScript Development'));
    });

    test('pathways offer extensive free certification paths across tech domains', () async {
      final pathways = await allTrainingPathways();
      final allLinks = pathways.expand((p) => p.links).toList();
      final freeLinks = allLinks.where((l) => l.isFree).toList();

      // Over 100 free certification and training options are available
      expect(freeLinks.length, greaterThanOrEqualTo(100));

      // Every pathway can be learned for free (fully free, or free to
      // learn with a paid certificate/exam).
      final pathwaysWithFree = pathways.where(
        (p) => p.links.any((l) => l.cost != TrainingCost.paid),
      ).toList();
      expect(pathwaysWithFree.length, equals(pathways.length));

      // Check specific domains have recognized free certifications
      final mobile = pathways.firstWhere((p) => p.name == 'Mobile App Development (Cross-Platform)');
      expect(mobile.links.any((l) => l.label.contains('CS50M') && l.isFree), isTrue);

      final fullStack = pathways.firstWhere((p) => p.name == 'Full-Stack & General Development');
      expect(fullStack.links.any((l) => l.label.contains('CS50W') && l.isFree), isTrue);
      expect(fullStack.links.any((l) => l.label.contains('freeCodeCamp') && l.isFree), isTrue);

      final cyber = pathways.firstWhere((p) => p.name == 'Cybersecurity Analysis');
      expect(cyber.links.any((l) => l.label.contains('ISC2') && l.isFree), isTrue);

      final csharp = pathways.firstWhere((p) => p.name == '.NET / C# Development');
      expect(csharp.links.any((l) => l.label.contains('Microsoft') && l.isFree), isTrue);

      // Verify other fields now have verified free options
      final ux = pathways.firstWhere((p) => p.name == 'UX/UI Design');
      expect(ux.field, equals('Design'));
      expect(ux.links.any((l) => l.isFree), isTrue);

      final gameDev = pathways.firstWhere((p) => p.name == 'Game Development');
      expect(gameDev.field, equals('Game Dev'));
      expect(gameDev.links.any((l) => l.isFree && l.provider == 'Harvard'), isTrue);

      final itSupport = pathways.firstWhere((p) => p.name == 'IT Support & Help Desk');
      expect(itSupport.field, equals('IT & Support'));
      expect(itSupport.links.any((l) => l.isFree), isTrue);

      final dataEng = pathways.firstWhere((p) => p.name == 'Data Engineering & Big Data');
      expect(dataEng.field, equals('Data & AI'));
      expect(dataEng.links.any((l) => l.isFree), isTrue);

      final management = pathways.firstWhere((p) => p.name == 'Project, Program & Product Management');
      expect(management.field, equals('Management'));
      expect(management.links.any((l) => l.isFree), isTrue);
    });

    test('metadata fields (field, provider, type, isFree) are correctly loaded', () async {
      final pathways = await allTrainingPathways();
      for (final p in pathways) {
        expect(p.field, isNotNull);
        expect(p.field!.isNotEmpty, isTrue);
        for (final l in p.links) {
          expect(l.provider, isNotNull);
          expect(l.type, isNotNull);
        }
      }
    });

    testWidgets('PathwayPage renders without errors', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: PathwayPage(),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(PathwayPage), findsOneWidget);
      expect(find.text('Certifications & Pathways'), findsOneWidget);
      expect(find.text('FREE OPTIONS'), findsWidgets);

      // Tap on the first pathway card to expand it and build TrainingPathwayCard
      await tester.tap(find.text('FREE OPTIONS').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TrainingPathwayCard), findsOneWidget);

      // Test tapping Free Certs category filter
      await tester.ensureVisible(find.text('Free Certs'));
      await tester.tap(find.text('Free Certs'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('FREE OPTIONS'), findsWidgets);

      // Test tapping Mobile category filter
      await tester.ensureVisible(find.text('Mobile'));
      await tester.tap(find.text('Mobile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Android Development'), findsOneWidget);

      // Test tapping Web category filter
      await tester.ensureVisible(find.text('Web'));
      await tester.tap(find.text('Web'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Full-Stack & General Development'), findsOneWidget);
    });

    testWidgets('PathwayPage searches and filters TypeScript pathways correctly', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: PathwayPage(initialQuery: 'TypeScript'),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('TypeScript Development'), findsOneWidget);
      expect(find.text('JavaScript & Front-End'), findsOneWidget);
      expect(find.text('FREE OPTIONS'), findsWidgets);
    });

    testWidgets('PathwayPage resolves TS abbreviation via alias search', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: PathwayPage(initialQuery: 'TS'),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('TypeScript Development'), findsOneWidget);
    });
  });
}

