import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/presentation/models/guided_formula_host.dart';

/// Token tags for the guided arithmetic expression builder (`col:`, `num:`, `op:`, `lp`, `rp`).
abstract final class ArithmeticExpressionFormula {
  static const String prefixColumn = 'col:';
  static const String prefixTableColumn = 'tblcol:';
  static const String prefixNumber = 'num:';
  static const String prefixOperator = 'op:';
  static const String tagOpenParen = 'lp';
  static const String tagCloseParen = 'rp';

  static const List<String> binaryOperators = <String>['+', '-', '*', '/'];

  static String tagColumn(String columnId) => '$prefixColumn$columnId';

  static String tagTableColumn({
    required String tableId,
    required String columnName,
  }) {
    return '$prefixTableColumn$tableId::$columnName';
  }

  static String tagNumber(String raw) => '$prefixNumber${raw.trim()}';

  static String tagOperator(String op) {
    final String t = op.trim();
    if (!binaryOperators.contains(t)) {
      return '$prefixOperator+';
    }
    return '$prefixOperator$t';
  }

  static String displayLabel(
    String tag,
    List<GuidedFormulaColumnLike> siblings,
    List<TableSchemaEntity> schemas,
  ) {
    if (tag.startsWith(prefixColumn)) {
      final String id = tag.substring(prefixColumn.length);
      for (final GuidedFormulaColumnLike c in siblings) {
        if (c.id == id) {
          final String n = c.nameController.text.trim();
          return n.isEmpty ? '(column)' : n;
        }
      }
      return '?';
    }
    if (tag.startsWith(prefixTableColumn)) {
      final (String? tableId, String? columnName) = _decodeTableColumnTag(tag);
      if (tableId == null || columnName == null) {
        return '?';
      }
      String tableName = '';
      for (final TableSchemaEntity s in schemas) {
        if (s.id == tableId) {
          tableName = s.name.trim();
          break;
        }
      }
      if (tableName.isEmpty) {
        return '?';
      }
      return '$tableName.$columnName';
    }
    if (tag.startsWith(prefixNumber)) {
      return tag.substring(prefixNumber.length);
    }
    if (tag.startsWith(prefixOperator)) {
      return tag.substring(prefixOperator.length);
    }
    if (tag == tagOpenParen) {
      return '(';
    }
    if (tag == tagCloseParen) {
      return ')';
    }
    return tag;
  }

  /// Builds the persisted formula string (spaces between tokens).
  static String compose(
    List<String> tags,
    List<GuidedFormulaColumnLike> siblings,
    List<TableSchemaEntity> schemas,
  ) {
    final List<String> parts = <String>[];
    for (final String tag in tags) {
      if (tag.startsWith(prefixColumn)) {
        final String id = tag.substring(prefixColumn.length);
        String name = '';
        for (final GuidedFormulaColumnLike c in siblings) {
          if (c.id == id) {
            name = c.nameController.text.trim();
            break;
          }
        }
        parts.add(name.isEmpty ? '""' : _atomIdentOrQuoted(name));
      } else if (tag.startsWith(prefixTableColumn)) {
        final (String? tableId, String? columnName) = _decodeTableColumnTag(tag);
        if (tableId == null || columnName == null) {
          parts.add('""');
          continue;
        }
        TableSchemaEntity? table;
        for (final TableSchemaEntity s in schemas) {
          if (s.id == tableId) {
            table = s;
            break;
          }
        }
        if (table == null) {
          parts.add('""');
          continue;
        }
        parts.add(
          '${_atomIdentOrQuoted(table.name.trim())}.${_atomIdentOrQuoted(columnName)}',
        );
      } else if (tag.startsWith(prefixNumber)) {
        final String raw = tag.substring(prefixNumber.length).trim();
        if (raw.isEmpty) {
          parts.add('0');
        } else if (double.tryParse(raw) != null) {
          parts.add(raw);
        } else {
          parts.add(_atomIdentOrQuoted(raw));
        }
      } else if (tag.startsWith(prefixOperator)) {
        parts.add(tag.substring(prefixOperator.length));
      } else if (tag == tagOpenParen) {
        parts.add('(');
      } else if (tag == tagCloseParen) {
        parts.add(')');
      }
    }
    return parts.join(' ');
  }

  static int _parenBalance(Iterable<String> tags) {
    int depth = 0;
    for (final String t in tags) {
      if (t == tagOpenParen) {
        depth++;
      } else if (t == tagCloseParen) {
        depth--;
        if (depth < 0) {
          return -1;
        }
      }
    }
    return depth;
  }

  /// Lightweight structural checks before [TableFormulaValidator].
  static String? validateTagStructure(List<String> tags) {
    if (tags.isEmpty) {
      return 'Add tokens to build a formula.';
    }
    if (_parenBalance(tags) != 0) {
      return 'Parentheses are not balanced.';
    }
    return null;
  }

  static (String?, String?) _decodeTableColumnTag(String tag) {
    if (!tag.startsWith(prefixTableColumn)) {
      return (null, null);
    }
    final String payload = tag.substring(prefixTableColumn.length);
    final int sep = payload.indexOf('::');
    if (sep <= 0 || sep >= payload.length - 2) {
      return (null, null);
    }
    final String tableId = payload.substring(0, sep).trim();
    final String columnName = payload.substring(sep + 2).trim();
    if (tableId.isEmpty || columnName.isEmpty) {
      return (null, null);
    }
    return (tableId, columnName);
  }
}

bool _isSimpleIdent(String s) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(s);

String _atomIdentOrQuoted(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) {
    return '""';
  }
  if (_isSimpleIdent(t)) {
    return t;
  }
  return '"${t.replaceAll('"', r'\"')}"';
}
