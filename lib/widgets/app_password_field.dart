import 'package:flutter/material.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// A password field with an obscure/reveal toggle, styled to match
/// SkillMatch's standard text inputs. This exact controller+toggle+
/// decoration setup was previously duplicated on the sign-in, sign-up,
/// and password-reset/change screens.
///
/// [borderRadius], [fillColor], and [contentPadding] are overridable
/// because password fields inside the "verification code" cards use a
/// white fill and a larger radius/padding than standalone form fields
/// on a plain page background — both are intentional, existing looks.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.controller,
    this.hintText = '••••••••',
    this.onSubmitted,
    this.borderRadius = 8,
    this.fillColor,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
    this.iconSize = 20,
    this.errorText,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final double borderRadius;
  final Color? fillColor;
  final EdgeInsetsGeometry contentPadding;
  final double iconSize;

  /// Inline validation message shown under the field, if any.
  final String? errorText;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      borderSide: BorderSide(color: tokens.cardBorderSoft),
    );
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      onSubmitted: widget.onSubmitted,
      style: TextStyle(color: tokens.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: widget.hintText,
        errorText: widget.errorText,
        errorMaxLines: 3,
        hintStyle: TextStyle(color: tokens.textFaint),
        filled: true,
        fillColor: widget.fillColor ?? tokens.surfaceMuted,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: widget.contentPadding,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            color: tokens.textSecondary,
            size: widget.iconSize,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
