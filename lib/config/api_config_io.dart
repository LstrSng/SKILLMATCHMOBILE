import 'normalize_api_base.dart';

const String _kDefaultRemoteApiBaseUrl = 'https://skillmatchmobile.onrender.com';

/// Override with `--dart-define=API_BASE_URL=http://...` when needed.
String get kApiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return normalizeApiBaseUrl(fromEnv);

  // Default to the deployed backend so physical devices work without extra flags.
  return normalizeApiBaseUrl(_kDefaultRemoteApiBaseUrl);
}
