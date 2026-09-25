import 'package:flutter/foundation.dart' show ValueNotifier;

import '../models/training_pathway.dart';

import 'profile_api.dart';
import 'session_store.dart';

/// Bumped after a certification or pathway is marked (not) completed, so
/// screens kept alive in the background (e.g. the Pathways tab) can update.
final completionsChanged = ValueNotifier<int>(0);

/// Certifications the user marked as passed/completed in the Pathways tab,
/// stored on the profile as `profile.completedCertifications`.
List<Map<String, dynamic>> readCompletedCertifications([
  Map<String, dynamic>? user,
]) {
  final raw =
      (user ?? SessionStore.user)?['profile']?['completedCertifications'];
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
      .where((m) => (m['label'] ?? '').toString().trim().isNotEmpty)
      .toList();
}

/// Labels of completed certifications, lower-cased for lookups.
Set<String> completedCertificationKeys([Map<String, dynamic>? user]) =>
    readCompletedCertifications(
      user,
    ).map((m) => m['label'].toString().trim().toLowerCase()).toSet();

bool isCertificationCompleted(TrainingResource link, Set<String> keys) =>
    keys.contains(link.label.trim().toLowerCase());

/// Marks [link] (from [pathwayName]) as completed or not and saves it to
/// the user's profile. Returns the updated set of completed keys.
Future<Set<String>> setCertificationCompleted({
  required TrainingResource link,
  required String pathwayName,
  required bool completed,
}) async {
  final key = link.label.trim().toLowerCase();
  final list = readCompletedCertifications()
    ..removeWhere((m) => m['label'].toString().trim().toLowerCase() == key);
  if (completed) {
    list.add({
      'label': link.label,
      'pathway': pathwayName,
      'provider': link.provider ?? '',
      'url': link.url,
      'completedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
  final user = await updateMyProfile({
    'profile': {'completedCertifications': list},
  });
  completionsChanged.value++;
  return completedCertificationKeys(user);
}

/// Names (lower-cased) of whole pathways the user marked as completed,
/// stored on the profile as `profile.completedPathways`.
Set<String> completedPathwayKeys([Map<String, dynamic>? user]) {
  final raw = (user ?? SessionStore.user)?['profile']?['completedPathways'];
  if (raw is! List) return {};
  return {
    for (final e in raw)
      if (e is Map && (e['name'] ?? '').toString().trim().isNotEmpty)
        e['name'].toString().trim().toLowerCase(),
  };
}

/// Marks the pathway [name] as completed or not and saves it to the
/// profile. Returns the updated set of completed pathway keys.
Future<Set<String>> setPathwayCompleted({
  required String name,
  required bool completed,
}) async {
  final key = name.trim().toLowerCase();
  final raw = SessionStore.user?['profile']?['completedPathways'];
  final list = [
    if (raw is List)
      for (final e in raw)
        if (e is Map && e['name'].toString().trim().toLowerCase() != key)
          e.map((k, v) => MapEntry(k.toString(), v)),
    if (completed)
      {'name': name, 'completedAt': DateTime.now().toUtc().toIso8601String()},
  ];
  final user = await updateMyProfile({
    'profile': {'completedPathways': list},
  });
  completionsChanged.value++;
  return completedPathwayKeys(user);
}
