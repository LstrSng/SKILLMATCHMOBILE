import 'package:flutter/material.dart';

import '../services/competency.dart';

/// Asks for the name of a skill that is not in the list. Returns the
/// cleaned name, or null if cancelled or left empty.
Future<String?> showAddOtherSkillDialog(
  BuildContext context, {
  Iterable<String> known = const [],
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AddOtherSkillDialog(known: known),
  );
}

class _AddOtherSkillDialog extends StatefulWidget {
  const _AddOtherSkillDialog({required this.known});

  final Iterable<String> known;

  @override
  State<_AddOtherSkillDialog> createState() => _AddOtherSkillDialogState();
}

class _AddOtherSkillDialogState extends State<_AddOtherSkillDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = normalizeSkillName(_controller.text, widget.known);
    Navigator.pop(context, name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add another skill'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add skill')),
      ],
    );
  }
}
