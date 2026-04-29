import 'package:flutter/material.dart';

/// Generic searchable dropdown based on [RawAutocomplete].
class SearchableDropdownField<T extends Object> extends StatefulWidget {
  const SearchableDropdownField({
    super.key,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.value,
    this.label,
    this.hintText,
  });

  final List<T> options;
  final T? value;
  final String Function(T option) optionLabel;
  final ValueChanged<T> onChanged;
  final String? label;
  final String? hintText;

  @override
  State<SearchableDropdownField<T>> createState() =>
      _SearchableDropdownFieldState<T>();
}

class _SearchableDropdownFieldState<T extends Object>
    extends State<SearchableDropdownField<T>> {
  late final TextEditingController _text = TextEditingController();
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _syncText();
  }

  @override
  void didUpdateWidget(covariant SearchableDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.options != widget.options) {
      _syncText();
    }
  }

  void _syncText() {
    if (widget.value == null) {
      _text.text = '';
      return;
    }
    _text.text = widget.optionLabel(widget.value as T);
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<T>(
      textEditingController: _text,
      focusNode: _focus,
      displayStringForOption: widget.optionLabel,
      optionsBuilder: (TextEditingValue value) {
        final String q = value.text.trim().toLowerCase();
        if (q.isEmpty) {
          return widget.options;
        }
        final List<T> matches = <T>[];
        final List<T> nonMatches = <T>[];
        for (final T t in widget.options) {
          final String label = widget.optionLabel(t).toLowerCase();
          if (label.contains(q)) {
            matches.add(t);
          } else {
            nonMatches.add(t);
          }
        }
        return <T>[...matches, ...nonMatches];
      },
      onSelected: (T selected) {
        widget.onChanged(selected);
        _text.text = widget.optionLabel(selected);
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
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
            hintText: widget.hintText,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<T> onSelected,
        Iterable<T> options,
      ) {
        final List<T> list = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, minWidth: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (BuildContext context, int index) {
                  final T item = list[index];
                  final String label = widget.optionLabel(item);
                  final String query = _text.text.trim();
                  final int matchStart =
                      query.isEmpty
                          ? -1
                          : label.toLowerCase().indexOf(query.toLowerCase());
                  final TextStyle baseStyle =
                      Theme.of(context).textTheme.bodyMedium ??
                      const TextStyle();
                  return ListTile(
                    dense: true,
                    title:
                        matchStart < 0
                            ? Text(label, style: baseStyle)
                            : RichText(
                              text: TextSpan(
                                style: baseStyle,
                                children: <InlineSpan>[
                                  TextSpan(
                                    text: label.substring(0, matchStart),
                                  ),
                                  TextSpan(
                                    text: label.substring(
                                      matchStart,
                                      matchStart + query.length,
                                    ),
                                    style: baseStyle.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: label.substring(
                                      matchStart + query.length,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    onTap: () => onSelected(item),
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
