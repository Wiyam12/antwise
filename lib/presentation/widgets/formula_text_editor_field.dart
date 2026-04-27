import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:flutter/material.dart';

enum _SuggestKind { function, table, column }

class _Suggestion {
  const _Suggestion({
    required this.kind,
    required this.label,
    required this.insertText,
    required this.replaceStart,
    required this.replaceEnd,
  });

  final _SuggestKind kind;
  final String label;
  final String insertText;
  final int replaceStart;
  final int replaceEnd;
}

/// Multiline formula field with function / table / column suggestions (Create Table text mode).
class FormulaTextEditorField extends StatefulWidget {
  const FormulaTextEditorField({
    super.key,
    required this.controller,
    required this.schemas,
    this.currentColumnNames = const <String>[],
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final List<TableSchemaEntity> schemas;
  final List<String> currentColumnNames;
  final VoidCallback onChanged;
  final String? errorText;

  @override
  State<FormulaTextEditorField> createState() => _FormulaTextEditorFieldState();
}

class _FormulaTextEditorFieldState extends State<FormulaTextEditorField> {
  static const Map<String, String> _functionTemplates = <String, String>{
    'SUM': 'SUM(?)',
    'COUNT': 'COUNT(?)',
    'AVG': 'AVG(?)',
    'IF': 'IF(?, ?, ?)',
    'LOOKUP': 'LOOKUP(?, ?, ?)',
  };

  late final FocusNode _focus = FocusNode();
  List<_Suggestion> _suggestions = <_Suggestion>[];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onValueChanged);
    _refreshSuggestionList();
  }

  @override
  void didUpdateWidget(covariant FormulaTextEditorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onValueChanged);
      widget.controller.addListener(_onValueChanged);
    }
    if (oldWidget.schemas != widget.schemas ||
        oldWidget.currentColumnNames != widget.currentColumnNames) {
      _refreshSuggestionList();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValueChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onValueChanged() {
    _refreshSuggestionList();
    widget.onChanged();
  }

  void _refreshSuggestionList() {
    final String text = widget.controller.text;
    final int end = text.length;
    int rawOffset =
        widget.controller.selection.isValid
            ? widget.controller.selection.extentOffset
            : end;
    if (rawOffset < 0) {
      rawOffset = 0;
    } else if (rawOffset > end) {
      rawOffset = end;
    }
    final List<_Suggestion> next = _suggestionsFor(
      text: text,
      cursor: rawOffset,
      schemas: widget.schemas,
      currentColumnNames: widget.currentColumnNames,
    );
    bool same = next.length == _suggestions.length;
    if (same) {
      for (int i = 0; i < next.length; i++) {
        if (next[i].label != _suggestions[i].label) {
          same = false;
          break;
        }
      }
    }
    if (same) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _suggestions = next;
    });
  }

  static List<_Suggestion> _suggestionsFor({
    required String text,
    required int cursor,
    required List<TableSchemaEntity> schemas,
    required List<String> currentColumnNames,
  }) {
    if (cursor < 0) {
      return <_Suggestion>[];
    }
    final String before = text.substring(0, cursor);
    if (before.isEmpty) {
      return <_Suggestion>[];
    }

    // <TableName>.<partial column> — column name suggestions.
    // Supports both plain and quoted table names:
    //   Sales.amount
    //   "Sales Table".amount
    final RegExp tableColumn = RegExp(r'(?:([A-Za-z_][\w]*)|"([^"]*)")\.(\w*)$');
    final RegExpMatch? mCol = tableColumn.firstMatch(before);
    if (mCol != null) {
      final String tableName = (mCol.group(1) ?? mCol.group(2) ?? '').trim();
      final String fullTablePart = mCol.group(0)!.split('.').first;
      final int dotInMatch = mCol.start + fullTablePart.length;
      final int replaceStart = dotInMatch + 1;
      final int replaceEnd = cursor;
      final String colPrefix = mCol.group(3)!.toLowerCase();
      TableSchemaEntity? found;
      for (final TableSchemaEntity s in schemas) {
        if (s.name.trim() == tableName) {
          found = s;
          break;
        }
      }
      if (found == null) {
        return <_Suggestion>[];
      }
      final List<_Suggestion> out = <_Suggestion>[];
      for (final TableColumnEntity c in found.columns) {
        final String cn = c.name.trim();
        if (cn.isEmpty) {
          continue;
        }
        if (colPrefix.isEmpty || cn.toLowerCase().startsWith(colPrefix)) {
          out.add(
            _Suggestion(
              kind: _SuggestKind.column,
              label: cn,
              insertText: _referenceTokenForName(cn),
              replaceStart: replaceStart,
              replaceEnd: replaceEnd,
            ),
          );
        }
      }
      out.sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
      return out.length > 20 ? out.sublist(0, 20) : out;
    }

    // Trailing identifier fragment: functions + tables + current-row columns.
    int p = before.length - 1;
    while (p >= 0) {
      final int c = before.codeUnitAt(p);
      final bool isIdent =
          (c >= 48 && c <= 57) ||
          (c >= 65 && c <= 90) ||
          (c >= 97 && c <= 122) ||
          c == 95;
      if (isIdent) {
        p--;
        continue;
      }
      break;
    }
    final int fragStart = p + 1;
    final String frag = before.substring(fragStart);
    if (frag.isEmpty) {
      return <_Suggestion>[];
    }
    final String fragLower = frag.toLowerCase();
    final List<_Suggestion> out = <_Suggestion>[];
    for (final MapEntry<String, String> e in _functionTemplates.entries) {
      final String name = e.key;
      if (name.toLowerCase().startsWith(fragLower)) {
        out.add(
          _Suggestion(
            kind: _SuggestKind.function,
            label: '$name()',
            insertText: e.value,
            replaceStart: fragStart,
            replaceEnd: cursor,
          ),
        );
      }
    }
    for (final TableSchemaEntity s in schemas) {
      final String tn = s.name.trim();
      if (tn.isEmpty) {
        continue;
      }
      if (tn.toLowerCase().startsWith(fragLower)) {
        out.add(
          _Suggestion(
            kind: _SuggestKind.table,
            label: tn,
            insertText: _referenceTokenForName(tn),
            replaceStart: fragStart,
            replaceEnd: cursor,
          ),
        );
      }
    }
    final Set<String> seenColumnLabels = <String>{};
    for (final String raw in currentColumnNames) {
      final String col = raw.trim();
      if (col.isEmpty || !seenColumnLabels.add(col.toLowerCase())) {
        continue;
      }
      if (col.toLowerCase().startsWith(fragLower)) {
        out.add(
          _Suggestion(
            kind: _SuggestKind.column,
            label: col,
            insertText: _referenceTokenForName(col),
            replaceStart: fragStart,
            replaceEnd: cursor,
          ),
        );
      }
    }
    out.sort((a, b) {
      final int ka =
          a.kind == _SuggestKind.function
              ? 0
              : a.kind == _SuggestKind.table
              ? 1
              : 2;
      final int kb =
          b.kind == _SuggestKind.function
              ? 0
              : b.kind == _SuggestKind.table
              ? 1
              : 2;
      final int o = ka.compareTo(kb);
      if (o != 0) {
        return o;
      }
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return out.length > 24 ? out.sublist(0, 24) : out;
  }

  static String _referenceTokenForName(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final bool simpleIdent = RegExp(r'^[A-Za-z_]\w*$').hasMatch(trimmed);
    if (simpleIdent) {
      return trimmed;
    }
    final String escaped = trimmed.replaceAll('"', r'\"');
    return '"$escaped"';
  }

  List<InlineSpan> _buildColorPreviewSpans(ThemeData theme) {
    final String text = widget.controller.text;
    if (text.isEmpty) {
      return <InlineSpan>[
        TextSpan(
          text: 'Type a formula to preview token categories',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }
    final TextStyle base =
        theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace') ??
        const TextStyle(fontSize: 12);
    final Set<String> functionNames = _functionTemplates.keys.toSet();
    final Set<String> tableNames = widget.schemas
        .map((TableSchemaEntity s) => s.name.trim().toLowerCase())
        .where((String s) => s.isNotEmpty)
        .toSet();
    final Set<String> rowColumns = widget.currentColumnNames
        .map((String s) => s.trim().toLowerCase())
        .where((String s) => s.isNotEmpty)
        .toSet();
    final RegExp tokenRegex = RegExp(
      r'("([^"\\]|\\.)*"|[A-Za-z_]\w*|\d+(?:\.\d+)?|[()+\-*/<>=!,.]|\s+|.)',
    );
    final Iterable<Match> matches = tokenRegex.allMatches(text);
    final List<InlineSpan> spans = <InlineSpan>[];
    bool previousDot = false;
    for (final Match m in matches) {
      final String token = m.group(0) ?? '';
      TextStyle style = base;
      if (token.trim().isEmpty) {
        spans.add(TextSpan(text: token, style: style));
        continue;
      }
      final String upper = token.toUpperCase();
      final String lower = token.toLowerCase();
      if (token == '.') {
        style = style.copyWith(color: theme.colorScheme.outline);
        previousDot = true;
      } else if (RegExp(r'^[()+\-*/<>=!,]$').hasMatch(token)) {
        style = style.copyWith(color: theme.colorScheme.outline);
        previousDot = false;
      } else if (token.startsWith('"') && token.endsWith('"')) {
        style = style.copyWith(color: Colors.green.shade700);
        previousDot = false;
      } else if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(token)) {
        style = style.copyWith(color: Colors.blueGrey.shade700);
        previousDot = false;
      } else if (functionNames.contains(upper)) {
        style = style.copyWith(color: Colors.deepPurple.shade700);
        previousDot = false;
      } else if (previousDot || rowColumns.contains(lower)) {
        style = style.copyWith(color: Colors.orange.shade800);
        previousDot = false;
      } else if (tableNames.contains(lower)) {
        style = style.copyWith(color: Colors.teal.shade700);
        previousDot = false;
      } else {
        previousDot = false;
      }
      spans.add(TextSpan(text: token, style: style));
    }
    return spans;
  }

  void _applySuggestion(_Suggestion s) {
    final String t = widget.controller.text;
    int cursorOffset =
        widget.controller.selection.isValid
            ? widget.controller.selection.extentOffset
            : t.length;
    if (cursorOffset < 0) {
      cursorOffset = 0;
    } else if (cursorOffset > t.length) {
      cursorOffset = t.length;
    }

    int replaceStart = s.replaceStart;
    int replaceEnd = s.replaceEnd;

    // Recompute token range from the current caret position so stale suggestion
    // rows cannot leave trailing characters (e.g. `Transactionsa`).
    if (s.kind == _SuggestKind.column && s.insertText != s.label) {
      final String before = t.substring(0, cursorOffset);
      final RegExpMatch? m = RegExp(r'([A-Za-z_][\w]*)\.(\w*)$').firstMatch(
        before,
      );
      if (m != null) {
        final int dotInMatch = m.start + m.group(1)!.length;
        replaceStart = dotInMatch + 1;
        replaceEnd = cursorOffset;
      }
    } else {
      int p = cursorOffset - 1;
      while (p >= 0) {
        final int c = t.codeUnitAt(p);
        final bool isIdent =
            (c >= 48 && c <= 57) ||
            (c >= 65 && c <= 90) ||
            (c >= 97 && c <= 122) ||
            c == 95;
        if (!isIdent) {
          break;
        }
        p--;
      }
      replaceStart = p + 1;
      replaceEnd = cursorOffset;
    }

    if (replaceStart < 0 || replaceEnd < replaceStart || replaceStart > t.length) {
      return;
    }
    final int re = replaceEnd > t.length ? t.length : replaceEnd;
    final String newText = t.replaceRange(replaceStart, re, s.insertText);
    int cursor = replaceStart + s.insertText.length;
    if (s.kind == _SuggestKind.function) {
      final int firstQ = s.insertText.indexOf('?');
      if (firstQ >= 0) {
        cursor = replaceStart + firstQ;
      }
    }
    if (cursor < 0) {
      cursor = 0;
    } else if (cursor > newText.length) {
      cursor = newText.length;
    }
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          minLines: 2,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontFamily: 'monospace',
            fontFamilyFallback: const <String>['monospace'],
          ),
          decoration: InputDecoration(
            labelText: 'Formula',
            alignLabelWithHint: true,
            hintText: 'e.g. IF(SUM(SalesTable.amount) > 100, "Yes", "No")',
            errorText: widget.errorText,
            errorMaxLines: 4,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_suggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Suggestions',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int i) {
                  final _Suggestion s = _suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      s.kind == _SuggestKind.function
                          ? Icons.functions
                          : s.kind == _SuggestKind.table
                          ? Icons.table_chart_outlined
                          : Icons.view_column_outlined,
                      size: 20,
                    ),
                    title: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      _applySuggestion(s);
                      _focus.requestFocus();
                    },
                  );
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Color preview (function/table/column/static):',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.surfaceContainerLowest,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: RichText(
              text: TextSpan(children: _buildColorPreviewSpans(theme)),
            ),
          ),
        ),
      ],
    );
  }
}
