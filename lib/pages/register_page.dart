import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_api.dart';
import '../services/session_store.dart';
import '../widgets/app_password_field.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/centered_form_width.dart';
import '../widgets/otp_code_field.dart';
import '../widgets/resend_code_button.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'skill_onboarding_page.dart';
import 'sign_in_page.dart';

class _SignupDraft {
  const _SignupDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    required this.challengeId,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final String challengeId;
}

final _kNameRegex = RegExp(r"^[\p{L}][\p{L} .'-]*$", unicode: true);

/// Lets only letters (incl. accented, e.g. ñ), spaces, and . ' - be typed.
final _kNameInputFormatter = FilteringTextInputFormatter.allow(
  RegExp(r"[\p{L} .'-]", unicode: true),
);
final _kEmailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Leaves the sign-up flow for the Sign In page. The account already
/// exists at this point, so the user can sign in without the sign-up code.
void goToSignInAfterSignup(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SignInPage()),
    (route) => route.isFirst,
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreeToTerms = false;
  bool _submitting = false;

  /// Inline errors are shown once the user has tried to submit.
  bool _attempted = false;

  String? _nameError(String value, String label) {
    final v = value.trim();
    if (v.isEmpty) return 'Enter your ${label.toLowerCase()}.';
    if (v.length < 2) return '$label must be at least 2 characters.';
    if (v.length > 50) return '$label must be 50 characters or fewer.';
    if (!_kNameRegex.hasMatch(v)) {
      return "Use letters only (spaces, . - ' allowed).";
    }
    return null;
  }

  /// Field errors for the current input, keyed by field name.
  Map<String, String?> _fieldErrors() {
    final emailValue = _emailController.text.trim();
    final phoneValue = _phoneController.text.trim();
    final passwordValue = _passwordController.text;
    return {
      'firstName': _nameError(_firstNameController.text, 'First name'),
      'lastName': _nameError(_lastNameController.text, 'Last name'),
      'email': emailValue.isEmpty
          ? 'Enter your email.'
          : (!_kEmailRegex.hasMatch(emailValue)
                ? 'Enter a valid email (e.g. juan@gmail.com).'
                : null),
      'phone': phoneValue.isEmpty
          ? 'Enter your contact number.'
          : (!RegExp(r'^09\d{9}$').hasMatch(phoneValue)
                ? 'Must be 11 digits and start with 09 (e.g. 09171234567).'
                : null),
      'password': passwordValue.isEmpty
          ? 'Enter a password.'
          : _passwordStandardError(passwordValue),
      'confirmPassword': _confirmPasswordController.text != passwordValue
          ? 'Passwords do not match.'
          : null,
    };
  }

  String? _err(String field) => _attempted ? _fieldErrors()[field] : null;

  String? _passwordStandardError(String password) {
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

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onPasswordChanged);
    for (final c in [
      _firstNameController,
      _lastNameController,
      _emailController,
      _phoneController,
    ]) {
      c.addListener(_onPasswordChanged);
    }
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _confirmPasswordController.removeListener(_onPasswordChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms of Service.')),
      );
      return;
    }
    setState(() => _attempted = true);
    final errors = _fieldErrors();
    final firstError = errors.values.whereType<String>().firstOrNull;
    if (firstError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix the highlighted fields. $firstError'),
        ),
      );
      return;
    }
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    setState(() => _submitting = true);
    try {
      final challenge = await requestRegisterOtp(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      if (!mounted) return;
      final draft = _SignupDraft(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: password,
        challengeId: challenge.challengeId,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              _RegisterOtpPage(draft: draft, initialMessage: challenge.message),
        ),
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      if (e.accountCreated) goToSignInAfterSignup(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to connect to server. Please check your internet connection.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showTermsOfService() async {
    await _showLegalDialog(
      title: 'Terms of Service',
      sections: const [
        'By creating an account, you agree to use SkillMatch+ responsibly and only for lawful job-search and career-related activities.',
        'You are responsible for keeping your login credentials secure and for all activity under your account.',
        'Do not upload false, misleading, or harmful information in your profile, applications, or messages.',
        'SkillMatch+ may update features and policies over time. Continued use means you accept the latest terms.',
      ],
    );
  }

  Future<void> _showPrivacyPolicy() async {
    await _showLegalDialog(
      title: 'Privacy Policy',
      sections: const [
        'We collect basic account details (such as name, email, and profile information) to provide and improve the app.',
        'Your data is used to personalize recommendations, process applications, and support account security.',
        'We do not sell your personal information. Data may be shared only with service providers needed to operate the platform.',
        'You can request account updates or deletion by contacting support through the app settings or support channel.',
      ],
    );
  }

  Future<void> _showLegalDialog({
    required String title,
    required List<String> sections,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections
                  .map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '• $section',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDec(
    AppThemeExtension tokens,
    String hint, {
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      errorMaxLines: 3,
      hintStyle: TextStyle(color: tokens.textFaint),
      filled: true,
      fillColor: tokens.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.cardBorderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.cardBorderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: tokens.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;

    return AuthScaffold(
      title: 'Create an account',
      subtitle: 'Join SkillMatch+ and find jobs that fit your skills',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // First Name and Last Name
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'First name',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _firstNameController,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        _kNameInputFormatter,
                        LengthLimitingTextInputFormatter(50),
                      ],
                      decoration: _inputDec(
                        tokens,
                        'Juan',
                        errorText: _err('firstName'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last name',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _lastNameController,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        _kNameInputFormatter,
                        LengthLimitingTextInputFormatter(50),
                      ],
                      decoration: _inputDec(
                        tokens,
                        'Dela Cruz',
                        errorText: _err('lastName'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Email Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                decoration: _inputDec(
                  tokens,
                  'm@example.com',
                  errorText: _err('email'),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contact Number Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact number',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: _inputDec(
                  tokens,
                  '09XXXXXXXXX',
                  errorText: _err('phone'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Password Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              AppPasswordField(
                controller: _passwordController,
                errorText: _err('password'),
              ),
              const SizedBox(height: 6),
              Text(
                'Use 8+ characters with uppercase, lowercase, number, and symbol.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Confirm Password Field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm password',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              AppPasswordField(
                controller: _confirmPasswordController,
                hintText: 'Re-enter your password',
                errorText: _err('confirmPassword'),
                onSubmitted: (_) =>
                    (_submitting || !_agreeToTerms) ? null : _createAccount(),
              ),
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _passwordController.text.length >= 8
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: _passwordController.text.length >= 8
                          ? Colors.green
                          : tokens.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'At least 8 characters',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _passwordController.text.length >= 8
                            ? Colors.green
                            : tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (_confirmPasswordController.text.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _confirmPasswordController.text ==
                              _passwordController.text
                          ? Icons.check_circle_rounded
                          : Icons.cancel_outlined,
                      size: 16,
                      color:
                          _confirmPasswordController.text ==
                              _passwordController.text
                          ? Colors.green
                          : Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _confirmPasswordController.text ==
                              _passwordController.text
                          ? 'Passwords match'
                          : 'Passwords do not match',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            _confirmPasswordController.text ==
                                _passwordController.text
                            ? Colors.green
                            : Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Terms Agreement
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreeToTerms,
                  activeColor: tokens.primary,
                  checkColor: Colors.white,
                  onChanged: (value) {
                    final nextValue = value ?? false;
                    setState(() {
                      _agreeToTerms = nextValue;
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: BorderSide(color: tokens.cardBorder),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Wrap(
                      children: [
                        Text(
                          'I agree to the ',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                        InkWell(
                          onTap: _showTermsOfService,
                          child: Text(
                            'Terms of Service',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: tokens.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: tokens.primary,
                                ),
                          ),
                        ),
                        Text(
                          ' and ',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                        InkWell(
                          onTap: _showPrivacyPolicy,
                          child: Text(
                            'Privacy Policy',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: tokens.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: tokens.primary,
                                ),
                          ),
                        ),
                        Text(
                          '.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Create Account Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Prevent submitting before the checkbox state has updated.
              onPressed: (_submitting || !_agreeToTerms)
                  ? null
                  : _createAccount,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Sign In Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignInPage()),
                  );
                },
                child: Text(
                  'Sign in',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegisterOtpPage extends StatefulWidget {
  const _RegisterOtpPage({required this.draft, required this.initialMessage});

  final _SignupDraft draft;
  final String initialMessage;

  @override
  State<_RegisterOtpPage> createState() => _RegisterOtpPageState();
}

class _RegisterOtpPageState extends State<_RegisterOtpPage> {
  final _otpController = TextEditingController();
  bool _verifying = false;
  String? _infoMessage;
  late _SignupDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _infoMessage = widget.initialMessage;
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP code.')),
      );
      return;
    }

    setState(() => _verifying = true);
    try {
      final res = await verifyRegisterOtp(
        email: _draft.email,
        password: _draft.password,
        firstName: _draft.firstName,
        lastName: _draft.lastName,
        phone: _draft.phone,
        otp: otp,
        challengeId: _draft.challengeId,
      );
      await SessionStore.save(token: res.token, user: res.user);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignedInHome()),
        (route) => false,
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to connect to server. Please check your internet connection.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resendCode() async {
    try {
      final challenge = await requestRegisterOtp(email: _draft.email);
      if (!mounted) return;
      setState(() {
        _draft = _SignupDraft(
          firstName: _draft.firstName,
          lastName: _draft.lastName,
          email: _draft.email,
          phone: _draft.phone,
          password: _draft.password,
          challengeId: challenge.challengeId,
        );
        _infoMessage = challenge.message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(challenge.message)));
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to connect to server. Please check your internet connection.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    // The account already exists, so leaving this page goes to Sign In
    // instead of back to the sign-up form.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goToSignInAfterSignup(context);
      },
      child: Scaffold(
        backgroundColor: tokens.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: tokens.scaffoldBackground,
          elevation: 0,
          iconTheme: IconThemeData(color: tokens.textPrimary),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: CenteredFormWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: tokens.primarySoftBg,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.mark_email_read_rounded,
                        color: tokens.primary,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Verification',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                            fontSize: 26,
                          ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your account has been created. We sent a 6-digit code to ${_draft.email} to verify your email.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: tokens.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tokens.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification code',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 10),
                        OtpCodeField(
                          controller: _otpController,
                          autofocus: true,
                          onSubmitted: (_) => _verifying ? null : _verifyOtp(),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _infoMessage ??
                              'The code expires in 10 minutes. If it does not arrive, resend it.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens.textSecondary,
                                height: 1.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _verifying ? null : _verifyOtp,
                      child: _verifying
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify and Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(child: ResendCodeButton(onResend: _resendCode)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
