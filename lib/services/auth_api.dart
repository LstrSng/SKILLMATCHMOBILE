import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthApiException implements Exception {
  AuthApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthResult {
  const AuthResult({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

class OtpChallengeResult {
  const OtpChallengeResult({
    required this.challengeId,
    required this.message,
  });

  final String challengeId;
  final String message;
}

class PasswordResetConfirmResult {
  const PasswordResetConfirmResult({
    required this.resetToken,
    required this.message,
  });

  final String resetToken;
  final String message;
}

/// Paths after `kApiBaseUrl`. Defaults match `app.use('/api/users', authRoutes)` + `/register`.
/// If your Skillmatch server uses different URLs, set e.g.
/// `--dart-define=AUTH_REGISTER_PATH=/register`
Uri _authEndpointUri(String pathFromEnv) {
  final p = pathFromEnv.startsWith('/') ? pathFromEnv : '/$pathFromEnv';
  return Uri.parse('$kApiBaseUrl$p');
}

Uri _registerUri() {
  const p = String.fromEnvironment(
    'AUTH_REGISTER_PATH',
    defaultValue: '/api/users/register',
  );
  return _authEndpointUri(p);
}

Uri _registerOtpRequestUri() {
  const p = String.fromEnvironment(
    'AUTH_REGISTER_OTP_REQUEST_PATH',
    defaultValue: '/api/users/register/otp/request',
  );
  return _authEndpointUri(p);
}

Uri _registerOtpVerifyUri() {
  const p = String.fromEnvironment(
    'AUTH_REGISTER_OTP_VERIFY_PATH',
    defaultValue: '/api/users/register/otp/verify',
  );
  return _authEndpointUri(p);
}

Uri _loginUri() {
  const p = String.fromEnvironment(
    'AUTH_LOGIN_PATH',
    defaultValue: '/api/users/login',
  );
  return _authEndpointUri(p);
}

Uri _loginOtpVerifyUri() {
  const p = String.fromEnvironment(
    'AUTH_LOGIN_OTP_VERIFY_PATH',
    defaultValue: '/api/users/login/otp/verify',
  );
  return _authEndpointUri(p);
}

Uri _passwordResetOtpRequestUri() {
  const p = String.fromEnvironment(
    'AUTH_PASSWORD_RESET_OTP_REQUEST_PATH',
    defaultValue: '/api/users/password/reset/otp/request',
  );
  return _authEndpointUri(p);
}

Uri _passwordResetOtpConfirmUri() {
  const p = String.fromEnvironment(
    'AUTH_PASSWORD_RESET_OTP_CONFIRM_PATH',
    defaultValue: '/api/users/password/reset/otp/confirm',
  );
  return _authEndpointUri(p);
}

Uri _passwordResetCompleteUri() {
  const p = String.fromEnvironment(
    'AUTH_PASSWORD_RESET_COMPLETE_PATH',
    defaultValue: '/api/users/password/reset/complete',
  );
  return _authEndpointUri(p);
}

bool _looksLikeUserMap(Map<String, dynamic> m) {
  return m.containsKey('email') ||
      m.containsKey('_id') ||
      m.containsKey('id') ||
      m.containsKey('username') ||
      m.containsKey('companyName');
}

Map<String, dynamic>? _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return v.map((k, dynamic val) => MapEntry(k.toString(), val));
  }
  return null;
}

String? _pickToken(Map<String, dynamic> body) {
  const keys = ['token', 'accessToken', 'jwt', 'authToken', 'access_token'];
  for (final k in keys) {
    final v = body[k];
    if (v is String && v.isNotEmpty) return v;
  }
  for (final container in [body['data'], body['result'], body['payload']]) {
    final m = _asMap(container);
    if (m == null) continue;
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
  }
  return null;
}

Map<String, dynamic>? _pickUser(Map<String, dynamic> body) {
  for (final key in ['user', 'profile', 'account']) {
    final u = _asMap(body[key]);
    if (u != null && _looksLikeUserMap(u)) return u;
  }
  for (final containerName in ['data', 'result', 'payload']) {
    final container = _asMap(body[containerName]);
    if (container == null) continue;
    for (final key in ['user', 'profile']) {
      final u = _asMap(container[key]);
      if (u != null && _looksLikeUserMap(u)) return u;
    }
    if (_looksLikeUserMap(container)) return container;
  }
  return null;
}

/// Flat JSON: `{ _id, email, firstName, companyName, token, ... }`
Map<String, dynamic>? _userFromFlatAuthResponse(Map<String, dynamic> body) {
  if (_pickToken(body) == null) return null;
  final copy = Map<String, dynamic>.from(body);
  for (final k in ['token', 'accessToken', 'jwt', 'authToken', 'access_token']) {
    copy.remove(k);
  }
  if (copy.isEmpty) return null;
  if (_looksLikeUserMap(copy)) return copy;
  return null;
}

Map<String, String> _jsonHeaders() => {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

OtpChallengeResult _parseOtpChallengeResponse(
  http.Response res, {
  Uri? requestedUri,
}) {
  final raw = res.body;
  if (raw.trim().isEmpty) {
    throw AuthApiException(
      'Empty response from server (${res.statusCode}).',
      statusCode: res.statusCode,
    );
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    final where = requestedUri != null ? ' $requestedUri' : '';
    throw AuthApiException(
      'Server did not return valid JSON for OTP request ($where).',
      statusCode: res.statusCode,
    );
  }

  final body = _asMap(decoded);
  if (body == null) {
    throw AuthApiException(
      'Server response was not a JSON object.',
      statusCode: res.statusCode,
    );
  }

  if (res.statusCode >= 200 && res.statusCode < 300) {
    final challengeId = body['challengeId']?.toString().trim() ?? '';
    if (challengeId.isEmpty) {
      throw AuthApiException(
        'Invalid response from server (missing challengeId).',
        statusCode: res.statusCode,
      );
    }
    return OtpChallengeResult(
      challengeId: challengeId,
      message: (body['message'] as String?) ?? 'OTP sent.',
    );
  }

  final err = body['error'] as String? ??
      body['message'] as String? ??
      body['msg'] as String? ??
      'Request failed.';
  throw AuthApiException(err, statusCode: res.statusCode);
}

PasswordResetConfirmResult _parsePasswordResetConfirmResponse(
  http.Response res, {
  Uri? requestedUri,
}) {
  final raw = res.body;
  if (raw.trim().isEmpty) {
    throw AuthApiException(
      'Empty response from server (${res.statusCode}).',
      statusCode: res.statusCode,
    );
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    final where = requestedUri != null ? ' $requestedUri' : '';
    throw AuthApiException(
      'Server did not return valid JSON for password reset confirmation ($where).',
      statusCode: res.statusCode,
    );
  }

  final body = _asMap(decoded);
  if (body == null) {
    throw AuthApiException(
      'Server response was not a JSON object.',
      statusCode: res.statusCode,
    );
  }

  if (res.statusCode >= 200 && res.statusCode < 300) {
    final resetToken = body['resetToken']?.toString().trim() ?? '';
    if (resetToken.isEmpty) {
      throw AuthApiException(
        'Invalid response from server (missing resetToken).',
        statusCode: res.statusCode,
      );
    }
    return PasswordResetConfirmResult(
      resetToken: resetToken,
      message: (body['message'] as String?) ?? 'Code confirmed.',
    );
  }

  final err = body['error'] as String? ??
      body['message'] as String? ??
      body['msg'] as String? ??
      'Request failed.';
  throw AuthApiException(err, statusCode: res.statusCode);
}

AuthResult _parseAuthResponse(
  http.Response res, {
  String? knownEmail,
  Uri? requestedUri,
}) {
  final raw = res.body;
  if (raw.trim().isEmpty) {
    throw AuthApiException(
      'Empty response from server (${res.statusCode}).',
      statusCode: res.statusCode,
    );
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    final status = res.statusCode;
    final trimmed = raw.trimLeft().toLowerCase();
    final looksHtml =
        trimmed.startsWith('<!doctype') || trimmed.startsWith('<html');
    String msg;
    if (status == 404) {
      final where = requestedUri != null ? ' $requestedUri' : '';
      msg =
          '404$where. Your app is reaching a server, but the endpoint was not found. '
          'Make sure you are running the SKILLMATCHMOBILE backend and that API_BASE_URL / API_PORT matches it.';
    } else if (looksHtml) {
      msg =
          'Server sent a web page instead of JSON ($status). Wrong URL or the API crashed—check API_BASE_URL and that Node is running.';
    } else {
      msg =
          'Server did not return JSON ($status). Check logs on your API.';
    }
    throw AuthApiException(msg, statusCode: status);
  }
  if (decoded is! Map) {
    throw AuthApiException(
      'Server response was not a JSON object.',
      statusCode: res.statusCode,
    );
  }
  final body = _asMap(decoded);
  if (body == null) {
    throw AuthApiException(
      'Server response was not a JSON object.',
      statusCode: res.statusCode,
    );
  }

  if (res.statusCode >= 200 && res.statusCode < 300) {
    final token = _pickToken(body);
    var user = _pickUser(body) ?? _userFromFlatAuthResponse(body);
    if (token == null) {
      throw AuthApiException(
        'Invalid response from server (no token).',
        statusCode: res.statusCode,
      );
    }
    if (user == null && knownEmail != null) {
      user = {'email': knownEmail};
    }
    if (user == null) {
      throw AuthApiException(
        'Invalid response from server (no user object).',
        statusCode: res.statusCode,
      );
    }
    return AuthResult(token: token, user: user);
  }
  final err = body['error'] as String? ??
      body['message'] as String? ??
      body['msg'] as String? ??
      'Request failed.';
  throw AuthApiException(err, statusCode: res.statusCode);
}

Future<AuthResult> registerUser({
  required String email,
  required String password,
  required String firstName,
  required String lastName,
}) async {
  final uri = _registerUri();
  final res = await http.post(
    uri,
    headers: _jsonHeaders(),
    body: jsonEncode({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
    }),
  );
  return _parseAuthResponse(res, knownEmail: email, requestedUri: uri);
}

Future<OtpChallengeResult> requestRegisterOtp({
  required String email,
}) async {
  final uri = _registerOtpRequestUri();
  final res = await http.post(
    uri,
    headers: _jsonHeaders(),
    body: jsonEncode({'email': email}),
  );
  return _parseOtpChallengeResponse(res, requestedUri: uri);
}

Future<AuthResult> verifyRegisterOtp({
  required String email,
  required String password,
  required String firstName,
  required String lastName,
  required String otp,
  required String challengeId,
}) async {
  final uri = _registerOtpVerifyUri();
  final res = await http.post(
    uri,
    headers: _jsonHeaders(),
    body: jsonEncode({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'otp': otp,
      'challengeId': challengeId,
    }),
  );
  return _parseAuthResponse(res, knownEmail: email, requestedUri: uri);
}

Future<AuthResult> loginUser({
  required String email,
  required String password,
}) async {
  final uri = _loginUri();
  final res = await http.post(
    uri,
    headers: _jsonHeaders(),
    body: jsonEncode({'email': email, 'password': password}),
  );
  return _parseAuthResponse(res, knownEmail: email, requestedUri: uri);
}

Future<OtpChallengeResult> requestLoginOtp({
  required String email,
  required String password,
}) async {
  final uri = _loginUri();
  final res = await http.post(
    uri,
    headers: _jsonHeaders(),
    body: jsonEncode({'email': email, 'password': password}),
  );
  return _parseOtpChallengeResponse(res, requestedUri: uri);
}

Future<AuthResult> verifyLoginOtp({
  required String email,
  required String otp,
  required String challengeId,
}) async {
  final uri = _loginOtpVerifyUri();
  final res = await http.post(
    uri,
    headers: _jsonHeaders(),
    body: jsonEncode({
      'email': email,
      'otp': otp,
      'challengeId': challengeId,
    }),
  );
  return _parseAuthResponse(res, knownEmail: email, requestedUri: uri);
}

Future<OtpChallengeResult> requestPasswordResetOtp({
  required String email,
}) async {
  final uri = _passwordResetOtpRequestUri();
  final res = await http.post(
    uri,
    headers: _jsonHeaders(),
    body: jsonEncode({'email': email}),
  );
  return _parseOtpChallengeResponse(res, requestedUri: uri);
}

Future<PasswordResetConfirmResult> confirmPasswordResetOtp({
  required String email,
  required String otp,
  required String challengeId,
}) async {
  final uri = _passwordResetOtpConfirmUri();
  final res = await http.post(
    uri,
    headers: _jsonHeaders(),
    body: jsonEncode({
      'email': email,
      'otp': otp,
      'challengeId': challengeId,
    }),
  );
  return _parsePasswordResetConfirmResponse(res, requestedUri: uri);
}

Future<void> completePasswordReset({
  required String resetToken,
  required String newPassword,
}) async {
  final uri = _passwordResetCompleteUri();
  final res = await http.post(
    uri,
    headers: _jsonHeaders(),
    body: jsonEncode({
      'resetToken': resetToken,
      'newPassword': newPassword,
    }),
  );

  final raw = res.body;
  if (raw.trim().isEmpty) {
    throw AuthApiException(
      'Empty response from server (${res.statusCode}).',
      statusCode: res.statusCode,
    );
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    throw AuthApiException(
      'Server did not return valid JSON for password reset completion.',
      statusCode: res.statusCode,
    );
  }

  final body = _asMap(decoded);
  if (body == null) {
    throw AuthApiException(
      'Server response was not a JSON object.',
      statusCode: res.statusCode,
    );
  }

  if (res.statusCode >= 200 && res.statusCode < 300) {
    return;
  }

  final err = body['error'] as String? ??
      body['message'] as String? ??
      body['msg'] as String? ??
      'Request failed.';
  throw AuthApiException(err, statusCode: res.statusCode);
}
