import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:skillmatch/theme/app_colors.dart';

/// The standard 6-digit OTP entry field used across the sign-up,
/// sign-in, and password-reset verification screens: one box per digit,
/// auto-advancing as the user types and auto-focusing back on backspace.
/// The full code is kept in sync with [controller] (a single
/// `TextEditingController` holding the whole 6-digit string), so callers
/// keep reading `controller.text` exactly as before.
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

  late final List<TextEditingController> _boxControllers;
  late final List<FocusNode> _focusNodes;
  bool _syncingFromParent = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.controller.text;
    _boxControllers = List.generate(
      _length,
      (i) => TextEditingController(text: i < initial.length ? initial[i] : ''),
    );
    // Handle backspace-on-empty via the FocusNode's own key handler instead
    // of a separate KeyboardListener — sharing one FocusNode between a
    // KeyboardListener and a TextField breaks EditableText internally.
    _focusNodes = List.generate(
      _length,
      (i) => FocusNode(onKeyEvent: (node, event) => _onKeyEvent(i, event)),
    );
    widget.controller.addListener(_onParentChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onParentChanged);
    for (final c in _boxControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onParentChanged() {
    if (_syncingFromParent) return;
    final text = widget.controller.text;
    for (var i = 0; i < _length; i++) {
      final ch = i < text.length ? text[i] : '';
      if (_boxControllers[i].text != ch) {
        _boxControllers[i].text = ch;
      }
    }
  }

  void _pushToParent() {
    _syncingFromParent = true;
    widget.controller.text = _boxControllers.map((c) => c.text).join();
    _syncingFromParent = false;
    if (widget.controller.text.length == _length) {
      widget.onSubmitted?.call(widget.controller.text);
    }
  }

  void _onChanged(int index, String value) {
    if (value.length <= 1) {
      if (value.isNotEmpty && index < _length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
      _pushToParent();
      return;
    }

    // Handles pasting a full code into one box: spread the digits across
    // the remaining boxes starting here.
    final digits = value.replaceAll(RegExp(r'\D'), '');
    for (var i = 0; i < digits.length && index + i < _length; i++) {
      _boxControllers[index + i].text = digits[i];
    }
    final lastFilled = (index + digits.length - 1).clamp(0, _length - 1);
    _focusNodes[lastFilled].requestFocus();
    _pushToParent();
  }

  KeyEventResult _onKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_boxControllers[index].text.isNotEmpty || index == 0) {
      return KeyEventResult.ignored;
    }
    _focusNodes[index - 1].requestFocus();
    _boxControllers[index - 1].clear();
    _pushToParent();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_length, (i) {
        return SizedBox(
          width: 44,
          height: 52,
          child: TextField(
            controller: _boxControllers[i],
            focusNode: _focusNodes[i],
            autofocus: widget.autofocus && i == 0,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppColors.border,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
            onChanged: (v) => _onChanged(i, v),
          ),
        );
      }),
    );
  }
}
