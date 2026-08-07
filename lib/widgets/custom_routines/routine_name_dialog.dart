import 'package:flutter/material.dart';

/// A simple text-input dialog for naming a new custom routine or
/// renaming an existing one.
///
/// Returns the trimmed name the user entered via [Navigator.pop], or
/// `null` if the dialog is cancelled/dismissed. The confirm action is
/// disabled while the field is empty so an unnamed routine can't be
/// created, but trimming/blank-guarding happens again in
/// [CustomRoutinesService] as well, since this dialog isn't the only
/// caller of those methods long-term.
class RoutineNameDialog extends StatefulWidget {
  const RoutineNameDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialValue = '',
  });

  /// Heading shown at the top of the dialog, e.g. "New Routine" or
  /// "Rename Routine".
  final String title;

  /// Label for the confirm button, e.g. "Create" or "Save".
  final String confirmLabel;

  /// Pre-fills the text field, e.g. with the routine's current name
  /// when renaming.
  final String initialValue;

  /// Shows the dialog and returns the name the user entered, or
  /// `null` if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String initialValue = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => RoutineNameDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
      ),
    );
  }

  @override
  State<RoutineNameDialog> createState() => _RoutineNameDialogState();
}

class _RoutineNameDialogState extends State<RoutineNameDialog> {
  late final TextEditingController _controller;
  late bool _canConfirm;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _canConfirm = _controller.text.trim().isNotEmpty;
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged() {
    final canConfirm = _controller.text.trim().isNotEmpty;
    if (canConfirm != _canConfirm) {
      setState(() => _canConfirm = canConfirm);
    }
  }

  void _confirm() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        decoration: const InputDecoration(
          hintText: 'e.g. Morning Routine',
          counterText: '',
        ),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
