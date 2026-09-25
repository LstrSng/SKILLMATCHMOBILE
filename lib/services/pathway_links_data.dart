import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/training_pathway.dart';

const String _assetPath = 'assets/data/career_pathway_links.json';

Map<String, TrainingPathway>? _pathwaysByName;
Map<String, String>? _roleToPathway;
Future<void>? _loading;

Future<void> _ensureLoaded() {
  if (_pathwaysByName != null) return Future.value();
  return _loading ??= _load();
}

Future<void> _load() async {
  final raw = await rootBundle.loadString(_assetPath);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;

  final pathwaysByName = <String, TrainingPathway>{};
  for (final p in (decoded['pathways'] as List)) {
    final map = p as Map<String, dynamic>;
    final name = map['name'] as String;
    final links = (map['links'] as List).map((l) {
      final linkMap = l as Map;
      final label = linkMap['label'] as String;
      final cost = switch (linkMap['cost']) {
        'free' => TrainingCost.free,
        'freeToLearn' => TrainingCost.freeToLearn,
        'paid' => TrainingCost.paid,
        _ =>
          (linkMap['isFree'] as bool? ?? false)
              ? TrainingCost.free
              : TrainingCost.paid,
      };
      return TrainingResource(
        label: label,
        url: linkMap['url'] as String,
        cost: cost,
        costNote: linkMap['costNote'] as String?,
        priceUsd: (linkMap['priceUsd'] as num?)?.toDouble(),
        priceUnit: linkMap['priceUnit'] as String?,
        provider: linkMap['provider'] as String?,
        type: linkMap['type'] as String?,
      );
    }).toList();
    pathwaysByName[name] = TrainingPathway(
      name: name,
      links: links,
      note: (map['note'] as String?) ?? '',
      field: map['field'] as String?,
    );
  }

  final roleToPathway = <String, String>{};
  (decoded['roleToPathway'] as Map<String, dynamic>).forEach((role, pathway) {
    roleToPathway[role] = pathway as String;
  });

  _pathwaysByName = pathwaysByName;
  _roleToPathway = roleToPathway;
}

const _kSeniorityWords = {
  'senior',
  'sr',
  'junior',
  'jr',
  'lead',
  'staff',
  'principal',
  'associate',
  'entry',
  'level',
  'i',
  'ii',
  'iii',
  'iv',
  'chief',
  'new',
  'grad',
};

/// Generic job-title "type" words that appear across dozens of unrelated
/// roles (e.g. "Marketing Manager" and "Software Development Manager"
/// both contain "manager"). Excluded only from the keyword-overlap
/// vocabulary so a shared generic word alone can't trigger a match —
/// the overlap has to be on an actually distinctive word.
const _kGenericRoleWords = {
  'engineer',
  'engineers',
  'developer',
  'developers',
  'manager',
  'managers',
  'analyst',
  'analysts',
  'specialist',
  'specialists',
  'consultant',
  'consultants',
  'architect',
  'architects',
  'administrator',
  'administrators',
  'director',
  'directors',
  'officer',
  'officers',
  'coordinator',
  'coordinators',
  'executive',
  'executives',
  'representative',
  'representatives',
  'technician',
  'technicians',
  'designer',
  'designers',
  'lead',
  'leads',
  'head',
  'professional',
};

String _normalizeSpacing(String s) {
  return s
      .replaceAll('front-end', 'front end')
      .replaceAll('frontend', 'front end')
      .replaceAll('back-end', 'back end')
      .replaceAll('backend', 'back end')
      .replaceAll('full-stack', 'full stack')
      .replaceAll('fullstack', 'full stack');
}

Set<String> _keywordVocab(String normalized) {
  return _normalizeSpacing(normalized)
      .split(RegExp(r'[\s/,-]+'))
      .where(
        (w) =>
            w.length > 2 &&
            !_kSeniorityWords.contains(w) &&
            !_kGenericRoleWords.contains(w),
      )
      .toSet();
}

String _stripSeniority(String normalized) {
  final words = normalized
      .split(RegExp(r'[\s/,-]+'))
      .where((w) => w.isNotEmpty && !_kSeniorityWords.contains(w));
  return words.join(' ').trim();
}

/// Best-effort keyword match: picks the pathway of a known role whose
/// *entire* distinctive vocabulary is contained in [roleTitle] (not just
/// a partial word overlap — a single shared generic-ish word like
/// "warehouse" in "Data Warehouse Manager" shouldn't match "Warehouse
/// Associate"). Used as a fallback for real job-posting titles that
/// don't exactly match the bundled dataset's canonical role names (e.g.
/// "Senior Frontend Engineer" vs. "Front End Developer"). Among roles
/// that qualify, prefers the one with the most matched words (the most
/// specific match). Returns null if nothing qualifies.
String? _bestKeywordMatch(String roleTitle) {
  final words = _keywordVocab(roleTitle);
  if (words.isEmpty) return null;

  String? bestPathway;
  var bestScore = 0;
  _roleToPathway!.forEach((role, pathway) {
    final roleWords = _keywordVocab(role);
    if (roleWords.isEmpty) return;
    final isFullyContained = roleWords.every(words.contains);
    if (isFullyContained && roleWords.length > bestScore) {
      bestScore = roleWords.length;
      bestPathway = pathway;
    }
  });
  return bestPathway;
}

List<TrainingPathway>? _cachedSortedPathways;

/// Resets the in-memory cached pathways so they can be reloaded.
void resetPathwayLinksCache() {
  _pathwaysByName = null;
  _roleToPathway = null;
  _loading = null;
  _cachedSortedPathways = null;
}

/// All bundled training/certification pathways, sorted by name. Used by
/// the Pathway tab to let users browse certifications directly by skill
/// area instead of picking a job role.
Future<List<TrainingPathway>> allTrainingPathways({
  bool forceReload = false,
}) async {
  if (forceReload) {
    resetPathwayLinksCache();
  }
  if (_cachedSortedPathways != null) return _cachedSortedPathways!;
  await _ensureLoaded();
  final list = _pathwaysByName!.values.toList();
  list.sort((a, b) => a.name.compareTo(b.name));
  _cachedSortedPathways = list;
  return list;
}

/// Looks up the verified training/certification pathway for a job role
/// title. Tries an exact (case-insensitive) match against the bundled
/// career-pathway dataset first, then a seniority-stripped match, then
/// falls back to keyword overlap for titles that don't exactly match
/// (real job postings rarely use the dataset's exact wording). Returns
/// null if nothing reasonable is found.
Future<TrainingPathway?> trainingPathwayForRole(String roleTitle) async {
  await _ensureLoaded();
  final normalized = roleTitle.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  final exact = _roleToPathway![normalized];
  if (exact != null) return _pathwaysByName![exact];

  final stripped = _stripSeniority(normalized);
  final strippedMatch = _roleToPathway![stripped];
  if (strippedMatch != null) return _pathwaysByName![strippedMatch];

  final byKeyword = _bestKeywordMatch(
    stripped.isNotEmpty ? stripped : normalized,
  );
  if (byKeyword != null) return _pathwaysByName![byKeyword];

  return null;
}

/// Topic rules mapping skill names (PSF-SDS competencies and common tech
/// skills) to the pathways whose certifications cover them. A skill gets
/// every pathway whose rule matches. Soft/enabling skills (Communication,
/// Teamwork…) intentionally have no rule — there are no certifications
/// for them in the pathways dataset.
final List<(RegExp, List<String>)> _kSkillPathwayRules = [
  for (final (pattern, names) in const [
    (
      r'forensic|penetration|vulnerab|security assessment|threat',
      ['Penetration Testing & Forensics', 'Cybersecurity Analysis'],
    ),
    (r'secur|cyber|infocomm|breach|surveillance', ['Cybersecurity Analysis']),
    (
      r'audit|complian|governance|regulat|legal|risk|data ethics|privacy|security (strategy|program|education|architecture)',
      ['Security Leadership & GRC'],
    ),
    (r'network', ['Networking']),
    (
      r'cloud',
      [
        'Cloud Architecture (AWS)',
        'Cloud Administration (Azure)',
        'Cloud Engineering (GCP)',
      ],
    ),
    (
      r'infrastructure (deployment|design|strategy)',
      ['Infrastructure as Code (HashiCorp)', 'Linux & Systems Administration'],
    ),
    (
      r'data cent|disaster|business continuity|infrastructure support|it asset|problem management|service level|applications support|incident',
      ['IT Service Management', 'IT Support & Help Desk'],
    ),
    (
      r'continuous integration|deploy|devops|release',
      ['CI/CD Pipeline Tooling', 'DevOps & Release Engineering'],
    ),
    (
      r'configuration|automation',
      ['Configuration Management', 'DevOps & Release Engineering'],
    ),
    (
      r'agile|scrum',
      ['Agile Tooling (Atlassian)', 'Project, Program & Product Management'],
    ),
    (
      r'project|portfolio|programme|program management|stakeholder|budget|vendor|contract|procurement|partnership|feasibility|change management|manpower|people and performance|training, coaching|product management',
      ['Project, Program & Product Management'],
    ),
    (
      r'business (needs|requirements|environment|performance|agility|risk|innovation)|requirement|process improvement|organi[sz]ational|demand analysis|customer (behavior|experience)|industry knowledge',
      ['Business & Systems Analysis'],
    ),
    (
      r'enterprise arch|it governance|it strategy|it standards|strategy|innovation|emerging technology|solution architecture|sustainability',
      ['Enterprise & Technology Leadership'],
    ),
    (
      r'data analy|visuali[sz]|quantitative|data strategy|data governance|power bi|tableau|excel',
      ['Data Analytics & BI'],
    ),
    (
      r'data engineer|data migration|data design|big data|spark|etl',
      ['Data Engineering & Big Data'],
    ),
    (
      r'artificial intelligence|machine learning|deep learning|\bai\b|tensorflow|pytorch',
      ['Data Science & Machine Learning'],
    ),
    (r'database|sql|mongo|postgres|oracle', ['Database Administration']),
    (
      r'user interface|user experience|\bui\b|\bux\b|interaction design|design thinking|visual design|aesthetic|prototyp|empathetic design|immersive|design concepts|design standards|design for|cultural sensitivity|behavioral economics|narrative design|product design|qualitative research|^research|figma|adobe',
      ['UX/UI Design'],
    ),
    (r'usability|user testing|accessib', ['UX/UI Design', 'Accessibility']),
    (r'test|quality|\bqa\b|selenium|cypress', ['QA & Test Automation']),
    (
      r'programming|coding|software (design|configuration)|applications? (development|integration)|systems design|systems? integration|customi[sz]ation|locali[sz]ation',
      ['Full-Stack & General Development', 'Back-End Development'],
    ),
    (r'embedded|control system|iot|robotic', ['Embedded, IoT & Robotics']),
    (
      r'business (development|negotiation|presentation)',
      ['Technology Sales & Accounts'],
    ),
    (
      r'continuous improvement|performance management',
      ['Project, Program & Product Management'],
    ),
    (
      r'content|seo|storytelling|crisis communication|market (research|trend)|digital marketing',
      ['SEO & Digital Marketing'],
    ),
    (
      r'firebase|flutter|react native|mobile',
      ['Mobile App Development (Cross-Platform)'],
    ),
    (r'android|kotlin', ['Android Development']),
    (r'\bios\b|swift', ['iOS Development']),
    (r'docker|kubernetes', ['Site Reliability & Kubernetes']),
    (r'\bgit\b|github|gitlab', ['Version Control & Git Platforms']),
    (r'linux|shell', ['Linux & Systems Administration']),
  ])
    (RegExp(pattern, caseSensitive: false), names),
];

bool _containsWord(String text, String word) => RegExp(
  r'(^|[^a-z0-9])' + RegExp.escape(word) + r'([^a-z0-9]|$)',
).hasMatch(text);

/// Pathways whose certifications cover [skill] — e.g. a skill a posted job
/// requires that the user lacks. Combines pathways that mention the skill
/// by name (Python, AWS…) with the topic rules above (PSF-SDS skills such
/// as "Threat Analysis and Defence").
List<TrainingPathway> pathwaysForSkill(
  List<TrainingPathway> pathways,
  String skill,
) {
  final phrase = skill.trim().toLowerCase();
  if (phrase.isEmpty) return const [];

  final names = <String>{
    for (final (rule, targets) in _kSkillPathwayRules)
      if (rule.hasMatch(phrase)) ...targets,
  };
  return pathways
      .where(
        (p) =>
            names.contains(p.name) ||
            _containsWord(p.name.toLowerCase(), phrase) ||
            p.links.any((l) => _containsWord(l.label.toLowerCase(), phrase)),
      )
      .toList();
}
