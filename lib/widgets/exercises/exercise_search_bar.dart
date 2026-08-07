import 'package:flutter/material.dart';

/// A themed search field for filtering the exercise catalog.
///
/// Purely presentational and controller-driven: [controller] owns the
/// text, and [onChanged] fires on every keystroke so the caller can
/// filter its list in real time. Styling matches [ExerciseCard] (a
/// filled, borderless, fully-rounded surface) so it reads as part of
/// the same design system rather than a generic Material text field.
///
/// A clear ("x") button fades in only once there's text to clear, and
/// is driven by [controller] directly (not [setState]) so clearing the
/// field never rebuilds anything beyond this widget.
class ExerciseSearchBar extends StatefulWidget {
  const ExerciseSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search exercises…',
  });

  /// Owns the current search text. Callers create and dispose this.
  final TextEditingController controller;

  /// Called with the latest text on every change.
  final ValueChanged<String> onChanged;

  /// Placeholder text shown when the field is empty.
  final String hintText;

  @override
  State<ExerciseSearchBar> createState() => _ExerciseSearchBarState();
}

class _ExerciseSearchBarState extends State<ExerciseSearchBar> {
  @override
  void initState() {
    super.initState();
    // Repaints just this widget when text becomes empty/non-empty, so
    // the clear button can fade in/out without the parent screen (and
    // therefore the whole exercise list) rebuilding on every keystroke.
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasText = widget.controller.text.isNotEmpty;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: colorScheme.onSurfaceVariant,
          ),
          suffixIcon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: hasText
                ? IconButton(
                    key: const ValueKey('clear'),
                    icon: const Icon(Icons.close),
                    color: colorScheme.onSurfaceVariant,
                    tooltip: 'Clear search',
                    onPressed: _clear,
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
