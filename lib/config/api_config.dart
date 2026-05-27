/// Base URL for your SkillMatch Express API (same `PORT` as `backend/.env`).
///
/// Default port is `api_defaults.dart` -> `kDefaultApiPort` (currently `5002`).
/// Override port: `--dart-define=API_PORT=5002` or change `kDefaultApiPort`.
/// Override full URL: `--dart-define=API_BASE_URL=http://...`
///
/// Physical device: `--dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:PORT`
library;

export 'api_config_stub.dart' if (dart.library.io) 'api_config_io.dart';
