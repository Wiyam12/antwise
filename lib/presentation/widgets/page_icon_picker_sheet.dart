import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:flutter/material.dart';

/// Bottom sheet: search + grid of icons, save persisted key via [onSave].
class PageIconPickerSheet extends StatefulWidget {
  const PageIconPickerSheet({
    super.key,
    required this.initialKey,
    required this.initialName,
    required this.onSave,
  });

  final String initialKey;
  final String initialName;
  final Future<void> Function(String iconKey, String pageName) onSave;

  static Future<void> show(
    BuildContext context, {
    required String initialKey,
    required String initialName,
    required Future<void> Function(String iconKey, String pageName) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return PageIconPickerSheet(
          initialKey: initialKey,
          initialName: initialName,
          onSave: onSave,
        );
      },
    );
  }

  @override
  State<PageIconPickerSheet> createState() => _PageIconPickerSheetState();
}

class _PageIconPickerSheetState extends State<PageIconPickerSheet> {
  late String _selectedKey;
  late final TextEditingController _search;
  late final TextEditingController _name;
  String? _nameError;
  List<AppIconOption> _filtered = AppIconRegistry.options;

  @override
  void initState() {
    super.initState();
    _selectedKey = widget.initialKey;
    _search = TextEditingController();
    _name = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
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
    final double sheetHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Choose icon', style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: 'Page name',
                hintText: 'Enter page name',
                errorText: _nameError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search icons…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: _applyFilter,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _filtered.length,
              itemBuilder: (BuildContext context, int index) {
                final AppIconOption o = _filtered[index];
                final bool selected = o.key == _selectedKey;
                return Material(
                  color:
                      selected
                          ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.65,
                          )
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => setState(() => _selectedKey = o.key),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          o.icon,
                          size: 28,
                          color:
                              selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            o.key.replaceAll('_', ' '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              onPressed: () async {
                final String nextName = _name.text.trim();
                if (nextName.isEmpty) {
                  setState(() => _nameError = 'Page name is required');
                  return;
                }
                await widget.onSave(_selectedKey, nextName);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}
