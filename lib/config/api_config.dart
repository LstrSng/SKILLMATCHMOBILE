/// Base URL for your SkillMatch **Express** API (same `PORT` as web `backend/.env`).
///
/// Default port is `api_defaults.dart` → `kDefaultApiPort` (5000 — match your web `PORT`).
/// Override port: `--dart-define=API_PORT=5000` or change `kDefaultApiPort`.
/// Override full URL: `--dart-define=API_BASE_URL=http://...`
///
/// **Physical device:** `--dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:PORT`
library;

export 'api_config_stub.dart'
    if (dart.library.io) 'api_config_io.dart';
