import 'dart:io';

void main() {
  final file = File('lib/services/auth_api.dart');
  String content = file.readAsStringSync();
  
  // Add dart:async
  if (!content.contains("import 'dart:async';")) {
    content = "import 'dart:async';\n" + content;
  }
  
  // Add _kAuthTimeout
  if (!content.contains("_kAuthTimeout")) {
    content = content.replaceFirst(
      "import 'session_store.dart';", 
      "import 'session_store.dart';\n\nconst Duration _kAuthTimeout = Duration(seconds: 45);"
    );
  }

  // Replace `final res = await http.post(...);` with try catch timeout
  final reg = RegExp(r'final\s+res\s*=\s*await\s+http\.post\((.*?)\);', dotAll: true);
  content = content.replaceAllMapped(reg, (m) {
    final inner = m.group(1);
    return '''http.Response res;
  try {
    res = await http.post(${inner}).timeout(_kAuthTimeout);
  } on TimeoutException {
    throw AuthApiException('The server is taking longer than usual to respond (it may be waking up). Please try again.');
  }''';
  });

  file.writeAsStringSync(content);
}
