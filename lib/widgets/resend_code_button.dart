import 'dart:async';

import 'package:flutter/material.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// A "Resend code" button that disables itself behind a countdown after
/// each send, so the user can't hammer the OTP-request endpoint. Shown as
/// "Resend code (30s)" while cooling down, "Resend code" once available.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    super.key,
    required this.onResend,
    this.cooldownSeconds = 30,
  });

  /// Called when the user taps resend. The button manages its own
  /// sending/cooldown state — this just needs to do the actual OTP
  /// request (and any of the caller's own state updates, like storing a
  /// new challengeId or info message).
  final Future<void> Function() onResend;
  final int cooldownSeconds;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  bool _sending = false;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = widget.cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft -= 1;
        if (_secondsLeft <= 0) timer.cancel();
      });
    });
  }

  Future<void> _handleTap() async {
    if (_sending || _secondsLeft > 0) return;
    setState(() => _sending = true);
    try {
      await widget.onResend();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _startCooldown();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = !_sending && _secondsLeft <= 0;
    return TextButton(
      onPressed: canResend ? _handleTap : null,
      child: _sending
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              _secondsLeft > 0
                  ? 'Resend code (${_secondsLeft}s)'
                  : 'Resend code',
              style: TextStyle(
                color: canResend ? AppColors.primary : AppColors.textFaint,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
