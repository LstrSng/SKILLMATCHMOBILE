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
    final links = (map['links'] as List)
        .map(
          (l) {
            final linkMap = l as Map;
            final label = linkMap['label'] as String;
            final isFree = (linkMap['isFree'] as bool?) ??
                label.toLowerCase().contains('free');
            return TrainingResource(
              label: label,
              url: linkMap['url'] as String,
              isFree: isFree,
              provider: linkMap['provider'] as String?,
              type: linkMap['type'] as String?,
            );
          },
        )
        .toList();
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
  'senior', 'sr', 'junior', 'jr', 'lead', 'staff', 'principal',
  'associate', 'entry', 'level', 'i', 'ii', 'iii', 'iv', 'chief', 'new', 'grad',
};

/// Generic job-title "type" words that appear across dozens of unrelated
/// roles (e.g. "Marketing Manager" and "Software Development Manager"
/// both contain "manager"). Excluded only from the keyword-overlap
/// vocabulary so a shared generic word alone can't trigger a match —
/// the overlap has to be on an actually distinctive word.
const _kGenericRoleWords = {
  'engineer', 'engineers', 'developer', 'developers', 'manager', 'managers',
  'analyst', 'analysts', 'specialist', 'specialists', 'consultant',
  'consultants', 'architect', 'architects', 'administrator', 'administrators',
  'director', 'directors', 'officer', 'officers', 'coordinator',
  'coordinators', 'executive', 'executives', 'representative',
  'representatives', 'technician', 'technicians', 'designer', 'designers',
  'lead', 'leads', 'head', 'professional',
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

/// Resets the in-memory cached pathways so they can be reloaded.
void resetPathwayLinksCache() {
  _pathwaysByName = null;
  _roleToPathway = null;
  _loading = null;
}

/// All bundled training/certification pathways, sorted by name. Used by
/// the Pathway tab to let users browse certifications directly by skill
/// area instead of picking a job role.
Future<List<TrainingPathway>> allTrainingPathways({bool forceReload = false}) async {
  if (forceReload) {
    resetPathwayLinksCache();
  }
  await _ensureLoaded();
  final list = _pathwaysByName!.values.toList();
  list.sort((a, b) => a.name.compareTo(b.name));
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

  final byKeyword = _bestKeywordMatch(stripped.isNotEmpty ? stripped : normalized);
  if (byKeyword != null) return _pathwaysByName![byKeyword];

  return null;
}
