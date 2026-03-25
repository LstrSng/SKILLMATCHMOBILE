import 'api_defaults.dart';
import 'normalize_api_base.dart';

/// Web / non-IO: no [Platform]; default to loopback.
String get kApiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return normalizeApiBaseUrl(fromEnv);
  const portStr = String.fromEnvironment('API_PORT', defaultValue: '');
  final port = portStr.isEmpty
      ? kDefaultApiPort
      : (int.tryParse(portStr) ?? kDefaultApiPort);
  return 'http://127.0.0.1:$port';
}
