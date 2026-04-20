import 'package:flutter/material.dart';

/// Text field with type-to-filter list for string options (e.g. table row modals).
class SearchableDropdownOptionsField extends StatefulWidget {
  const SearchableDropdownOptionsField({
    super.key,
    required this.label,
    required this.options,
    required this.controller,
    this.onChanged,
    this.emptyOptionsHint = 'No options available yet.',
  });

  final String label;
  final List<String> options;
  final TextEditingController controller;
  final VoidCallback? onChanged;
  final String emptyOptionsHint;

  @override
  State<SearchableDropdownOptionsField> createState() =>
      _SearchableDropdownOptionsFieldState();
}

class _SearchableDropdownOptionsFieldState
    extends State<SearchableDropdownOptionsField> {
  late final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.emptyOptionsHint,
        ),
        onChanged: (_) => widget.onChanged?.call(),
      );
    }
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      displayStringForOption: (String s) => s,
      optionsBuilder: (TextEditingValue value) {
        final String q = value.text.trim().toLowerCase();
        if (q.isEmpty) {
          return widget.options;
        }
        return widget.options
            .where((String o) => o.toLowerCase().contains(q))
            .toList(growable: false);
      },
      onSelected: (String selection) {
        widget.controller.text = selection;
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.controller.text.length,
        );
        widget.onChanged?.call();
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Search or pick an option…',
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          onChanged: (_) => widget.onChanged?.call(),
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<String> onSelected,
        Iterable<String> options,
      ) {
        final List<String> list = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 260),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (BuildContext context, int index) {
                  final String s = list[index];
                  return ListTile(
                    dense: true,
                    title: Text(s),
                    onTap: () => onSelected(s),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
