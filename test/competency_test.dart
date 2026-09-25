import 'package:flutter_test/flutter_test.dart';
import 'package:skillmatch/services/competency.dart';

void main() {
  group('RequiredLevel.parse', () {
    test('reads PSF levels, ranges (minimum) and enabling levels', () {
      expect(RequiredLevel.parse('Budgeting Level 6')?.psfLevel, 6);
      expect(
        RequiredLevel.parse('Business Needs Analysis Level 2-3')?.psfLevel,
        2,
      );
      expect(RequiredLevel.parse('Collaboration Basic')?.enabling, 'Basic');
      expect(
        RequiredLevel.parse('Communication Intermediate')?.label,
        'Intermediate',
      );
      expect(RequiredLevel.parse('React'), isNull);
    });
  });

  test('converts 1-10 ratings to PSF and enabling levels', () {
    expect(
      [for (var r = 1; r <= 10; r++) psfLevelForRating(r)],
      [1, 2, 2, 3, 3, 4, 5, 5, 6, 6],
    );
    expect(enablingLevelForRating(3), 'Basic');
    expect(enablingLevelForRating(4), 'Intermediate');
    expect(enablingLevelForRating(8), 'Advanced');
  });

  test('assesses meets, below level and missing with partial credit', () {
    final result = assessCompetencies(
      ['Budgeting Level 3', 'Collaboration Advanced', 'React', 'Docker'],
      {
        'skills': ['Budgeting', 'Collaboration', 'React'],
        'skillLevels': {'Budgeting': 5, 'Collaboration': 4, 'React': 2},
      },
    );
    final byName = {for (final c in result) c.skill: c};
    expect(byName['Budgeting']!.status, CompetencyStatus.meets);
    expect(byName['Budgeting']!.applicantLevel, 'Level 3');
    expect(byName['Collaboration']!.status, CompetencyStatus.belowLevel);
    expect(byName['Collaboration']!.applicantLevel, 'Intermediate');
    expect(byName['Collaboration']!.credit, 0.5); // 4 of the 8 needed
    expect(byName['React']!.status, CompetencyStatus.meets); // no level
    expect(byName['Docker']!.status, CompetencyStatus.missing);
    expect(competencyMatchPercent(result), 63); // (1 + 0.5 + 1 + 0) / 4
  });

  test('unrated skills count as the default level', () {
    final c = assessCompetencies(
      ['Budgeting Level 3'],
      {
        'skills': ['Budgeting'],
      },
    ).single;
    expect(c.rating, kUnratedSkillLevel);
    expect(c.status, CompetencyStatus.meets);
  });

  test('describes what the applicant still needs', () {
    final byName = {
      for (final c in assessCompetencies(
        ['React', 'Cloud Computing Level 4', 'Budgeting Level 3'],
        {
          'skills': ['Budgeting'],
          'skillLevels': {'Budgeting': 2},
        },
      ))
        c.skill: c.gapDescription,
    };
    expect(byName['React'], 'Not in your skills yet · any level is enough');
    expect(byName['Cloud Computing'], 'Not in your skills yet · needs Level 4');
    expect(byName['Budgeting'], 'You: Beginner (Level 2) · needs Level 3');
  });

  test('summarizes matched skills with the required level', () {
    final byName = {
      for (final c in assessCompetencies(
        ['Collaboration Basic', 'Figma', 'Budgeting Level 3'],
        {
          'skills': ['Collaboration', 'Figma', 'Budgeting'],
          'skillLevels': {'Collaboration': 2, 'Figma': 8, 'Budgeting': 2},
        },
      ))
        c.skill: c.levelSummary,
    };
    expect(byName['Collaboration'], 'You: Beginner (Basic) · required Basic');
    expect(byName['Figma'], 'You: Advanced (8/10) · any level is enough');
    expect(byName['Budgeting'], 'You: Beginner (Level 2) · needs Level 3');
  });

  test('counts a skill listed twice once, at the stricter level', () {
    final result = assessCompetencies(
      [
        'agile software development',
        'Agile Software Development Level 4',
        'React',
      ],
      {
        'skills': ['Agile Software Development', 'React'],
        'skillLevels': {'Agile Software Development': 3, 'React': 5},
      },
    );
    expect(result, hasLength(2));
    final agile = result.firstWhere(
      (c) => c.skill == 'Agile Software Development',
    );
    expect(agile.required?.label, 'Level 4');
    expect(agile.status, CompetencyStatus.belowLevel);
  });
}
