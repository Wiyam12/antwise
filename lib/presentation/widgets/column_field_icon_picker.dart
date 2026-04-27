import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:flutter/material.dart';

/// Compact icon grid to pick a field decoration icon key. Returns [null] if cleared.
Future<String?> showColumnFieldIconPicker(
  BuildContext context, {
  String? currentKey,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return _ColumnFieldIconPickerContent(initialKey: currentKey);
    },
  );
}

class _ColumnFieldIconPickerContent extends StatefulWidget {
  const _ColumnFieldIconPickerContent({this.initialKey});

  final String? initialKey;

  @override
  State<_ColumnFieldIconPickerContent> createState() =>
      _ColumnFieldIconPickerContentState();
}

class _ColumnFieldIconPickerContentState
    extends State<_ColumnFieldIconPickerContent> {
  late final TextEditingController _search;
  List<AppIconOption> _filtered = AppIconRegistry.options;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applyFilter(String q) {
    setState(() {
      _filtered = AppIconRegistry.filter(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Choose icon', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search icons…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: _applyFilter,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop<String?>(null),
                child: const Text('No icon'),
              ),
            ),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No icons match your search',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (BuildContext context, int i) {
                        final AppIconOption o = _filtered[i];
                        final bool selected = o.key == widget.initialKey;
                        return Material(
                          color:
                              selected
                                  ? theme.colorScheme.primaryContainer
                                      .withValues(
                                        alpha: 0.6,
                                      )
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(
                                        alpha: 0.4,
                                      ),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.of(context).pop<String?>(
                              o.key,
                            ),
                            child: Center(
                              child: Icon(
                                o.icon,
                                size: 26,
                                color:
                                    selected
                                        ? theme.colorScheme.primary
                                        : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
