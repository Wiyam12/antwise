import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:hive/hive.dart';

/// Builds a compact table/column outline for on-device AI support prompts.
abstract final class AiSupportTableSnapshot {
  static const int _maxTables = 12;
  static const int _maxColsPerTable = 14;
  static const int _maxOutlineChars = 1600;

  /// Empty string if Hive is unavailable or there are no tables.
  static String tryBuild() {
    try {
      if (!Hive.isBoxOpen(HiveBoxes.tablesBox)) {
        return '';
      }
      final Iterable<TableSchemaHiveModel> values =
          Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox).values;
      final List<TableSchemaHiveModel> tables = values.toList(growable: false)
        ..sort(
          (TableSchemaHiveModel a, TableSchemaHiveModel b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      if (tables.isEmpty) {
        return '';
      }
      final StringBuffer out = StringBuffer();
      final int limit = tables.length > _maxTables ? _maxTables : tables.length;
      for (int i = 0; i < limit; i++) {
        final TableSchemaHiveModel t = tables[i];
        final String name = t.name.trim();
        if (name.isEmpty) {
          continue;
        }
        out.write('- ');
        out.write(name);
        out.write(': ');
        final List<String> colParts = <String>[];
        int colCount = 0;
        for (final Map<String, dynamic> raw in t.columns) {
          if (colCount >= _maxColsPerTable) {
            colParts.add('…');
            break;
          }
          final String cn = (raw['name'] ?? '').toString().trim();
          if (cn.isEmpty) {
            continue;
          }
          final String ty = (raw['type'] ?? 'text').toString().trim();
          colParts.add(ty.isEmpty ? cn : '$cn ($ty)');
          colCount++;
        }
        out.writeln(colParts.isEmpty ? '(no columns)' : colParts.join(', '));
        if (out.length >= _maxOutlineChars) {
          out.writeln('… (outline truncated)');
          break;
        }
      }
      if (tables.length > _maxTables) {
        out.writeln('… and ${tables.length - _maxTables} more table(s)');
      }
      return out.toString().trimRight();
    } catch (_) {
      return '';
    }
  }
}
