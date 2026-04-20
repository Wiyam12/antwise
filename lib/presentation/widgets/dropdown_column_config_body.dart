import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Manual vs other-table configuration for a dropdown column (create/edit flows).
class DropdownColumnConfigBody extends StatelessWidget {
  const DropdownColumnConfigBody({
    super.key,
    required this.sourceKind,
    required this.sourceTableId,
    required this.sourceColumnId,
    required this.manualLinesController,
    required this.allSchemas,
    this.errorText,
    this.excludeTableId,
  });

  final Rx<TableColumnDropdownSourceKind> sourceKind;
  final RxnString sourceTableId;
  final RxnString sourceColumnId;
  final TextEditingController manualLinesController;
  final RxList<TableSchemaEntity> allSchemas;
  final String? errorText;
  final String? excludeTableId;

  List<TableSchemaEntity> get _tables {
    final List<TableSchemaEntity> list = allSchemas.toList(growable: false);
    if (excludeTableId == null || excludeTableId!.isEmpty) {
      return list;
    }
    return list
        .where((TableSchemaEntity s) => s.id != excludeTableId)
        .toList(growable: false);
  }

  TableSchemaEntity? _schemaById(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final TableSchemaEntity s in allSchemas) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Dropdown source', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Obx(() {
          return SegmentedButton<TableColumnDropdownSourceKind>(
            segments: const <ButtonSegment<TableColumnDropdownSourceKind>>[
              ButtonSegment<TableColumnDropdownSourceKind>(
                value: TableColumnDropdownSourceKind.manual,
                label: Text('Manual Input'),
              ),
              ButtonSegment<TableColumnDropdownSourceKind>(
                value: TableColumnDropdownSourceKind.table,
                label: Text('From Other Table'),
              ),
            ],
            selected: <TableColumnDropdownSourceKind>{sourceKind.value},
            onSelectionChanged:
                (Set<TableColumnDropdownSourceKind> selection) {
              if (selection.isEmpty) {
                return;
              }
              final TableColumnDropdownSourceKind next = selection.first;
              sourceKind.value = next;
              if (next == TableColumnDropdownSourceKind.manual) {
                sourceTableId.value = null;
                sourceColumnId.value = null;
              } else {
                manualLinesController.clear();
              }
            },
          );
        }),
        const SizedBox(height: 12),
        Obx(() {
          if (sourceKind.value == TableColumnDropdownSourceKind.manual) {
            return TextField(
              controller: manualLinesController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Options (one per line)',
                helperText: 'Each line becomes one selectable value.',
                alignLabelWithHint: true,
              ),
            );
          }
          return _TableSourceFields(
            theme: theme,
            tables: _tables,
            sourceTableId: sourceTableId,
            sourceColumnId: sourceColumnId,
            schemaById: _schemaById,
          );
        }),
        if (errorText != null && errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorText!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

class _TableSourceFields extends StatelessWidget {
  const _TableSourceFields({
    required this.theme,
    required this.tables,
    required this.sourceTableId,
    required this.sourceColumnId,
    required this.schemaById,
  });

  final ThemeData theme;
  final List<TableSchemaEntity> tables;
  final RxnString sourceTableId;
  final RxnString sourceColumnId;
  final TableSchemaEntity? Function(String? id) schemaById;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Source Table', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        _SearchableSchemaPicker(
          label: 'Search tables…',
          schemas: tables,
          selectedId: sourceTableId,
          clearRelatedColumnId: sourceColumnId,
          displayName: (TableSchemaEntity s) => s.name,
          idOf: (TableSchemaEntity s) => s.id,
        ),
        const SizedBox(height: 12),
        Text('Source Column', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Obx(() {
          final TableSchemaEntity? src = schemaById(sourceTableId.value);
          final List<TableColumnEntity> cols = src?.columns ?? const [];
          return _SearchableColumnPicker(
            label: 'Search columns…',
            columns: cols,
            selectedId: sourceColumnId,
            displayName: (TableColumnEntity c) => '${c.name} (${c.type.storageValue})',
            idOf: (TableColumnEntity c) => c.id,
          );
        }),
      ],
    );
  }
}

class _SearchableSchemaPicker extends StatefulWidget {
  const _SearchableSchemaPicker({
    required this.label,
    required this.schemas,
    required this.selectedId,
    required this.displayName,
    required this.idOf,
    this.clearRelatedColumnId,
  });

  final String label;
  final List<TableSchemaEntity> schemas;
  final RxnString selectedId;
  final RxnString? clearRelatedColumnId;
  final String Function(TableSchemaEntity) displayName;
  final String Function(TableSchemaEntity) idOf;

  @override
  State<_SearchableSchemaPicker> createState() =>
      _SearchableSchemaPickerState();
}

class _SearchableSchemaPickerState extends State<_SearchableSchemaPicker> {
  late final TextEditingController _text = TextEditingController();
  late final FocusNode _focus = FocusNode();
  Worker? _selectedWorker;

  @override
  void initState() {
    super.initState();
    _syncFromRx();
    _selectedWorker = ever(widget.selectedId, (_) => _syncFromRx());
  }

  void _syncFromRx() {
    final String? id = widget.selectedId.value;
    TableSchemaEntity? match;
    for (final TableSchemaEntity s in widget.schemas) {
      if (widget.idOf(s) == id) {
        match = s;
        break;
      }
    }
    final String next = match == null ? '' : widget.displayName(match);
    if (_text.text != next) {
      _text.text = next;
    }
  }

  @override
  void dispose() {
    _selectedWorker?.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (widget.schemas.isEmpty) {
      return Text(
        'No other tables available yet.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    return RawAutocomplete<TableSchemaEntity>(
      textEditingController: _text,
      focusNode: _focus,
      displayStringForOption: widget.displayName,
      optionsBuilder: (TextEditingValue value) {
        final String q = value.text.trim().toLowerCase();
        if (q.isEmpty) {
          return widget.schemas;
        }
        return widget.schemas
            .where(
              (TableSchemaEntity s) =>
                  widget.displayName(s).toLowerCase().contains(q),
            )
            .toList(growable: false);
      },
      onSelected: (TableSchemaEntity s) {
        widget.selectedId.value = widget.idOf(s);
        widget.clearRelatedColumnId?.value = null;
        _text.text = widget.displayName(s);
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
            labelText: 'Source table',
            hintText: widget.label,
            suffixIcon: const Icon(Icons.table_chart_outlined),
          ),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<TableSchemaEntity> onSelected,
        Iterable<TableSchemaEntity> options,
      ) {
        final List<TableSchemaEntity> list = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 260),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: list.length,
                itemBuilder: (BuildContext context, int index) {
                  final TableSchemaEntity s = list[index];
                  return ListTile(
                    dense: true,
                    title: Text(widget.displayName(s)),
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

class _SearchableColumnPicker extends StatefulWidget {
  const _SearchableColumnPicker({
    required this.label,
    required this.columns,
    required this.selectedId,
    required this.displayName,
    required this.idOf,
  });

  final String label;
  final List<TableColumnEntity> columns;
  final RxnString selectedId;
  final String Function(TableColumnEntity) displayName;
  final String Function(TableColumnEntity) idOf;

  @override
  State<_SearchableColumnPicker> createState() =>
      _SearchableColumnPickerState();
}

class _SearchableColumnPickerState extends State<_SearchableColumnPicker> {
  late final TextEditingController _text = TextEditingController();
  late final FocusNode _focus = FocusNode();
  Worker? _selectedWorker;

  @override
  void initState() {
    super.initState();
    _sync();
    _selectedWorker = ever(widget.selectedId, (_) => _sync());
  }

  @override
  void didUpdateWidget(covariant _SearchableColumnPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.columns.isEmpty) {
      widget.selectedId.value = null;
      if (_text.text.isNotEmpty) {
        _text.clear();
      }
      return;
    }
    final String? id = widget.selectedId.value;
    if (id != null &&
        !widget.columns.any((TableColumnEntity c) => widget.idOf(c) == id)) {
      widget.selectedId.value = null;
      _text.clear();
    }
    _sync();
  }

  void _sync() {
    final String? id = widget.selectedId.value;
    TableColumnEntity? match;
    for (final TableColumnEntity c in widget.columns) {
      if (widget.idOf(c) == id) {
        match = c;
        break;
      }
    }
    final String next = match == null ? '' : widget.displayName(match);
    if (_text.text != next) {
      _text.text = next;
    }
  }

  @override
  void dispose() {
    _selectedWorker?.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (widget.columns.isEmpty) {
      return Text(
        'Pick a source table first.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return RawAutocomplete<TableColumnEntity>(
      textEditingController: _text,
      focusNode: _focus,
      displayStringForOption: widget.displayName,
      optionsBuilder: (TextEditingValue value) {
        final String q = value.text.trim().toLowerCase();
        if (q.isEmpty) {
          return widget.columns;
        }
        return widget.columns
            .where(
              (TableColumnEntity c) =>
                  widget.displayName(c).toLowerCase().contains(q),
            )
            .toList(growable: false);
      },
      onSelected: (TableColumnEntity c) {
        widget.selectedId.value = widget.idOf(c);
        _text.text = widget.displayName(c);
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
            labelText: 'Source column',
            hintText: widget.label,
            suffixIcon: const Icon(Icons.view_column_outlined),
          ),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<TableColumnEntity> onSelected,
        Iterable<TableColumnEntity> options,
      ) {
        final List<TableColumnEntity> list = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 260),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: list.length,
                itemBuilder: (BuildContext context, int index) {
                  final TableColumnEntity c = list[index];
                  return ListTile(
                    dense: true,
                    title: Text(widget.displayName(c)),
                    onTap: () => onSelected(c),
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
