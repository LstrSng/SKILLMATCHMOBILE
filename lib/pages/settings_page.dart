import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import '../services/notification_store.dart';
import '../services/session_store.dart';
import '../services/theme_store.dart';
import 'package:skillmatch/theme/app_colors.dart';
import 'sign_in_page.dart';
import '../widgets/app_card.dart';
import '../widgets/page_hero_header.dart';
import '../widgets/app_password_field.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/centered_form_width.dart';
import '../widgets/otp_code_field.dart';
import '../widgets/resend_code_button.dart';

class SettingsPage extends StatefulWidget {
  final int initialTab;
  const SettingsPage({super.key, this.initialTab = 0});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loadingPrefs = true;
  bool _jobMatches = true;
  bool _applicationUpdates = true;
  bool _weeklyDigest = false;
  bool _requestingPasswordChange = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final jobMatches = await NotificationStore.getPreference(
      NotificationStore.kPrefJobMatches,
      defaultValue: true,
    );
    final applicationUpdates = await NotificationStore.getPreference(
      NotificationStore.kPrefApplicationUpdates,
      defaultValue: true,
    );
    final weeklyDigest = await NotificationStore.getPreference(
      NotificationStore.kPrefWeeklyDigest,
      defaultValue: false,
    );
    if (!mounted) return;
    setState(() {
      _jobMatches = jobMatches;
      _applicationUpdates = applicationUpdates;
      _weeklyDigest = weeklyDigest;
      _loadingPrefs = false;
    });
  }

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

  Future<void> _logOut() async {
    await SessionStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SignInPage()),
      (route) => false,
    );
  }

  Future<void> _startChangePassword() async {
    final email = SessionStore.user?['email']?.toString().trim() ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not find your account email. Please sign in again.',
          ),
        ),
      );
      return;
    }

    setState(() => _requestingPasswordChange = true);
    try {
      final challenge = await requestPasswordResetOtp(email: email);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _ChangePasswordPage(
            draft: _PasswordResetDraft(
              email: email,
              challengeId: challenge.challengeId,
            ),
            initialMessage: challenge.message,
            passwordValidator: _passwordStandardError,
          ),
        ),
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
      if (mounted) setState(() => _requestingPasswordChange = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountEmail = SessionStore.user?['email']?.toString().trim() ?? '';
    final tokens = context.appColors;

    return Scaffold(
      appBar: const AppTopBar(showSettings: false),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 600 ? 32 : 16,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeroHeader(
              icon: Icons.tune_rounded,
              title: 'Settings',
              subtitle: 'Manage your appearance, notifications and account.',
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appearance',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose whether to match device system settings or pick a theme',
                    style: TextStyle(fontSize: 14, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, currentMode, _) {
                      return SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto, size: 18),
                              label: Text('System'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined, size: 18),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined, size: 18),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {currentMode},
                          onSelectionChanged: (newSelection) {
                            final selectedMode = newSelection.first;
                            themeNotifier.value = selectedMode;
                            ThemeStore.save(selectedMode);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Preferences',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage alerts for jobs and application activity',
                    style: TextStyle(fontSize: 14, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  _NotificationToggle(
                    title: 'Job Matches',
                    subtitle: 'New jobs matching your profile',
                    value: _jobMatches,
                    onChanged: _loadingPrefs
                        ? null
                        : (value) {
                            setState(() => _jobMatches = value);
                            NotificationStore.setPreference(
                              NotificationStore.kPrefJobMatches,
                              value,
                            );
                          },
                  ),
                  const SizedBox(height: 20),
                  Divider(color: tokens.cardBorderSoft),
                  const SizedBox(height: 20),
                  _NotificationToggle(
                    title: 'Application Updates',
                    subtitle: 'Status changes on applications',
                    value: _applicationUpdates,
                    onChanged: _loadingPrefs
                        ? null
                        : (value) {
                            setState(() => _applicationUpdates = value);
                            NotificationStore.setPreference(
                              NotificationStore.kPrefApplicationUpdates,
                              value,
                            );
                          },
                  ),
                  const SizedBox(height: 20),
                  Divider(color: tokens.cardBorderSoft),
                  const SizedBox(height: 20),
                  _NotificationToggle(
                    title: 'Weekly Digest',
                    subtitle: 'Weekly summary of activity',
                    value: _weeklyDigest,
                    onChanged: _loadingPrefs
                        ? null
                        : (value) {
                            setState(() => _weeklyDigest = value);
                            NotificationStore.setPreference(
                              NotificationStore.kPrefWeeklyDigest,
                              value,
                            );
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Security',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    accountEmail.isEmpty
                        ? 'Verify your identity with a one-time password before changing your password.'
                        : 'We will send a 6-digit OTP to $accountEmail before you can set a new password.',
                    style: TextStyle(fontSize: 14, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _requestingPasswordChange
                          ? null
                          : _startChangePassword,
                      icon: _requestingPasswordChange
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset_outlined),
                      label: Text(
                        _requestingPasswordChange
                            ? 'Sending OTP...'
                            : 'Change Password',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logOut,
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PasswordResetDraft {
  const _PasswordResetDraft({required this.email, required this.challengeId});

  final String email;
  final String challengeId;
}

class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage({
    required this.draft,
    required this.initialMessage,
    required this.passwordValidator,
  });

  final _PasswordResetDraft draft;
  final String initialMessage;
  final String? Function(String password) passwordValidator;

  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _verifying = false;
  String? _infoMessage;
  late _PasswordResetDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _infoMessage = widget.initialMessage;
  }

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitPasswordChange() async {
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP code.')),
      );
      return;
    }

    final passwordError = widget.passwordValidator(newPassword);
    if (passwordError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(passwordError)));
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password and confirmation do not match.'),
        ),
      );
      return;
    }

    setState(() => _verifying = true);
    try {
      final confirm = await confirmPasswordResetOtp(
        email: _draft.email,
        otp: otp,
        challengeId: _draft.challengeId,
      );
      await completePasswordReset(
        resetToken: confirm.resetToken,
        newPassword: newPassword,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
      Navigator.of(context).pop();
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
      final challenge = await requestPasswordResetOtp(email: _draft.email);
      if (!mounted) return;
      setState(() {
        _draft = _PasswordResetDraft(
          email: _draft.email,
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
    return Scaffold(
      backgroundColor: tokens.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: tokens.cardBackground,
        surfaceTintColor: tokens.cardBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: tokens.textPrimary),
        title: Text(
          'Change Password',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                      Icons.shield_outlined,
                      color: tokens.primary,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Confirm it\'s really you',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent a 6-digit OTP to ${_draft.email}. Enter the code and your new password below.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: tokens.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.cardBorderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verification code',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OtpCodeField(controller: _otpController),
                      const SizedBox(height: 10),
                      Text(
                        _infoMessage ??
                            'The code expires in 10 minutes. If it does not arrive, resend it.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'New password',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppPasswordField(
                        controller: _newPasswordController,
                        hintText: 'Enter new password',
                        borderRadius: 14,
                        fillColor: tokens.cardBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        iconSize: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use 8+ characters with uppercase, lowercase, number, and symbol.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Confirm new password',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppPasswordField(
                        controller: _confirmPasswordController,
                        hintText: 'Re-enter new password',
                        onSubmitted: (_) =>
                            _verifying ? null : _submitPasswordChange(),
                        borderRadius: 14,
                        fillColor: tokens.cardBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        iconSize: 24,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                    onPressed: _verifying ? null : _submitPasswordChange,
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
                            'Verify OTP and Change Password',
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
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _NotificationToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}
