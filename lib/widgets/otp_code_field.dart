import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// The standard 6-digit OTP entry field used across the sign-up,
/// sign-in, and password-reset verification screens: renders 6 distinct
/// digit boxes while using a single continuous underlying [TextField].
///
/// Using a single [TextField] guarantees that the mobile soft keyboard stays
/// steady without dismissing and reopening between digits.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  static const _length = 6;

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onStateChanged);
    widget.controller.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(covariant OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStateChanged);
      widget.controller.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _focusNode.removeListener(_onStateChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onChanged(String value) {
    if (value.length == _length) {
      widget.onSubmitted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final isFocused = _focusNode.hasFocus;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Visual presentation: 6 distinct digit boxes matching original UI
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_length, (i) {
            final digit = i < text.length ? text[i] : '';
            final isCurrent =
                isFocused && (i == text.length.clamp(0, _length - 1));

            return Container(
              width: 44,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrent ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            );
          }),
        ),

        // Single underlying TextField capturing input without keyboard flickering
        Positioned.fill(
          child: Theme(
            data: Theme.of(context).copyWith(
              textSelectionTheme: const TextSelectionThemeData(
                selectionColor: Colors.transparent,
                cursorColor: Colors.transparent,
                selectionHandleColor: Colors.transparent,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: _length,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              showCursor: false,
              enableInteractiveSelection: true,
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 1,
                letterSpacing: 0,
              ),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () {
                widget.controller.selection = TextSelection.collapsed(
                  offset: widget.controller.text.length,
                );
              },
              onChanged: _onChanged,
              onSubmitted: (val) {
                if (val.length == _length) {
                  widget.onSubmitted?.call(val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
