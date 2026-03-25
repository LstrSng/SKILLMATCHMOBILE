import 'dart:io' show Platform;

import 'api_defaults.dart';
import 'normalize_api_base.dart';

/// Android emulator: `127.0.0.1` is the emulator itself, not your PC.
/// `10.0.2.2` is the host machine from the emulator.
///
/// Port: [kDefaultApiPort] or `--dart-define=API_PORT=...` (matches web `PORT`).
String get kApiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return normalizeApiBaseUrl(fromEnv);
  const portStr = String.fromEnvironment('API_PORT', defaultValue: '');
  final port = portStr.isEmpty
      ? kDefaultApiPort
      : (int.tryParse(portStr) ?? kDefaultApiPort);
  final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
  return 'http://$host:$port';
}
