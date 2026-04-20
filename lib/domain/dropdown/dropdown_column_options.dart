import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';

/// Resolves selectable values for a dropdown column (manual list vs distinct table column).
abstract final class DropdownColumnOptions {
  /// One non-empty trimmed line per option (create/edit forms use multiline input).
  static List<String> manualOptionsFromMultiline(String raw) {
    return raw
        .split(RegExp(r'\r?\n'))
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static String manualOptionsToMultiline(Iterable<String> options) =>
      options.join('\n');

  static List<String> resolve({
    required TableColumnEntity column,
    required Map<String, List<TableRowEntity>> rowsByTableId,
  }) {
    if (column.type != TableColumnType.dropdown) {
      return const <String>[];
    }
    if (column.dropdownSourceKind ==
            TableColumnDropdownSourceKind.table &&
        (column.dropdownSourceTableId ?? '').isNotEmpty &&
        (column.dropdownSourceColumnId ?? '').isNotEmpty) {
      final List<TableRowEntity> rows =
          rowsByTableId[column.dropdownSourceTableId!] ??
              const <TableRowEntity>[];
      final Set<String> seen = <String>{};
      final List<String> out = <String>[];
      for (final TableRowEntity r in rows) {
        final String v =
            r.values[column.dropdownSourceColumnId!]?.toString().trim() ?? '';
        if (v.isEmpty) {
          continue;
        }
        if (seen.add(v)) {
          out.add(v);
        }
      }
      out.sort(
        (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );
      return out;
    }
    return column.dropdownOptions;
  }
}
