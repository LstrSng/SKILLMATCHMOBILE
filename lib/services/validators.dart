/// Returns why [password] is too weak, or null if it's OK. Sign-up,
/// password reset and password change all use this (the backend enforces
/// the same rule).
String? passwordStrengthError(String password) {
  if (password.length < 8) {
    return 'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.';
  }
  final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
  final hasLower = RegExp(r'[a-z]').hasMatch(password);
  final hasNumber = RegExp(r'\d').hasMatch(password);
  final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
  if (!hasUpper || !hasLower || !hasNumber || !hasSpecial) {
    return 'Password must include uppercase, lowercase, number, and special character.';
  }
  return null;
}
