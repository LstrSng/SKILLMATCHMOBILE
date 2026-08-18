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
