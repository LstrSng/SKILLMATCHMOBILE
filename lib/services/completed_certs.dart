import '../models/training_pathway.dart';
import 'profile_api.dart';
import 'session_store.dart';

/// Certifications the user marked as passed/completed in the Pathways tab,
/// stored on the profile as `profile.completedCertifications`.
List<Map<String, dynamic>> readCompletedCertifications([
  Map<String, dynamic>? user,
]) {
  final raw = (user ?? SessionStore.user)?['profile']?['completedCertifications'];
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
      .where((m) => (m['label'] ?? '').toString().trim().isNotEmpty)
      .toList();
}

/// Labels of completed certifications, lower-cased for lookups.
Set<String> completedCertificationKeys([Map<String, dynamic>? user]) =>
    readCompletedCertifications(user)
        .map((m) => m['label'].toString().trim().toLowerCase())
        .toSet();

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
  return completedCertificationKeys(user);
}
