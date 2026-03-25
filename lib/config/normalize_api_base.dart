/// Strips trailing slashes and a trailing `/api` so paths are not doubled
/// (`.../api` + `/api/users` would break).
String normalizeApiBaseUrl(String raw) {
  var s = raw.trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('/api')) {
    s = s.substring(0, s.length - 4);
  }
  return s;
}
