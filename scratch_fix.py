import re

with open('lib/services/auth_api.dart', 'r') as f:
    content = f.read()

if "import 'dart:async';" not in content:
    content = "import 'dart:async';\n" + content

if "_kAuthTimeout" not in content:
    content = content.replace(
        "import 'session_store.dart';", 
        "import 'session_store.dart';\n\nconst Duration _kAuthTimeout = Duration(seconds: 45);"
    )

def replace_func(match):
    inner = match.group(1)
    return f"""http.Response res;
  try {{
    res = await http.post({inner}).timeout(_kAuthTimeout);
  }} on TimeoutException {{
    throw AuthApiException('The server is taking longer than usual to respond (it may be waking up). Please try again.');
  }}"""

content = re.sub(r'final\s+res\s*=\s*await\s+http\.post\((.*?)\);', replace_func, content, flags=re.DOTALL)

with open('lib/services/auth_api.dart', 'w') as f:
    f.write(content)

