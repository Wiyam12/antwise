import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';

/// Evaluates stored formula strings for [TableColumnType.formula] columns at
/// display time (values are not persisted on rows).
class TableFormulaEvaluator {
  TableFormulaEvaluator._();

  static Map<String, dynamic> resolveRowValues({
    required TableSchemaEntity schema,
    required TableRowEntity row,
    required List<TableSchemaEntity> allSchemas,
    required Map<String, List<TableRowEntity>> rowsByTableId,
    int remainingDepth = 24,
  }) {
    if (remainingDepth <= 0) {
      return Map<String, dynamic>.from(row.values);
    }
    final int childDepth = remainingDepth - 1;
    final Map<String, dynamic> working =
        Map<String, dynamic>.from(row.values);
    final List<TableColumnEntity> formulaCols = schema.columns
        .where((TableColumnEntity c) => c.type == TableColumnType.formula)
        .toList(growable: false);
    if (formulaCols.isEmpty) {
      return working;
    }
    final int maxPasses = formulaCols.length + 2;
    for (int pass = 0; pass < maxPasses; pass++) {
      bool changed = false;
      for (final TableColumnEntity col in formulaCols) {
        final String? f = col.formula?.trim();
        if (f == null || f.isEmpty) {
          continue;
        }
        final String computed = evaluate(
          formula: f,
          currentSchema: schema,
          workingRowByColId: working,
          allSchemas: allSchemas,
          rowsByTableId: rowsByTableId,
          forColumnId: col.id,
          remainingDepth: childDepth,
        );
        final String old = working[col.id]?.toString() ?? '';
        if (old != computed) {
          working[col.id] = computed;
          changed = true;
        }
      }
      if (!changed) {
        break;
      }
    }
    return working;
  }

  static String evaluate({
    required String formula,
    required TableSchemaEntity currentSchema,
    required Map<String, dynamic> workingRowByColId,
    required List<TableSchemaEntity> allSchemas,
    required Map<String, List<TableRowEntity>> rowsByTableId,
    String? forColumnId,
    int remainingDepth = 24,
  }) {
    try {
      final List<_Token> tokens = _Lexer(formula.trim()).tokenize();
      final _EvalParser p = _EvalParser(
        tokens: tokens,
        currentSchema: currentSchema,
        workingRowByColId: workingRowByColId,
        allSchemas: allSchemas,
        rowsByTableId: rowsByTableId,
        evaluatingColumnId: forColumnId,
        remainingDepth: remainingDepth,
      );
      final dynamic v = p.parseExpression();
      p.expectEnd();
      return _stringify(v);
    } catch (_) {
      return '';
    }
  }

  static String _stringify(dynamic v) {
    if (v == null) {
      return '';
    }
    if (v is num) {
      if (v == v.roundToDouble()) {
        return v.round().toString();
      }
      return v.toString();
    }
    return v.toString();
  }
}

// —— Lexer (aligned with [TableFormulaValidator]) ——————————————————————

enum _Tk {
  number,
  ident,
  string,
  plus,
  minus,
  mul,
  div,
  comma,
  eq,
  ne,
  lt,
  gt,
  le,
  ge,
  lpar,
  rpar,
  dot,
  end,
}

class _Token {
  const _Token(this.type, this.lexeme);

  final _Tk type;
  final String lexeme;
}

class _Lexer {
  _Lexer(this.input);

  final String input;
  int _i = 0;

  List<_Token> tokenize() {
    final List<_Token> out = <_Token>[];
    while (_i < input.length) {
      final int c = input.codeUnitAt(_i);
      if (c == 32 || c == 9 || c == 10 || c == 13) {
        _i++;
        continue;
      }
      if (c == 33 &&
          _i + 1 < input.length &&
          input.codeUnitAt(_i + 1) == 61) {
        out.add(const _Token(_Tk.ne, '!='));
        _i += 2;
      } else if (c == 60) {
        if (_i + 1 < input.length && input.codeUnitAt(_i + 1) == 61) {
          out.add(const _Token(_Tk.le, '<='));
          _i += 2;
        } else {
          out.add(const _Token(_Tk.lt, '<'));
          _i++;
        }
      } else if (c == 62) {
        if (_i + 1 < input.length && input.codeUnitAt(_i + 1) == 61) {
          out.add(const _Token(_Tk.ge, '>='));
          _i += 2;
        } else {
          out.add(const _Token(_Tk.gt, '>'));
          _i++;
        }
      } else if (c == 61) {
        if (_i + 1 < input.length && input.codeUnitAt(_i + 1) == 61) {
          out.add(const _Token(_Tk.eq, '=='));
          _i += 2;
        } else {
          out.add(const _Token(_Tk.eq, '='));
          _i++;
        }
      } else if (c == 43) {
        out.add(const _Token(_Tk.plus, '+'));
        _i++;
      } else if (c == 45) {
        out.add(const _Token(_Tk.minus, '-'));
        _i++;
      } else if (c == 42) {
        out.add(const _Token(_Tk.mul, '*'));
        _i++;
      } else if (c == 47) {
        out.add(const _Token(_Tk.div, '/'));
        _i++;
      } else if (c == 40) {
        out.add(const _Token(_Tk.lpar, '('));
        _i++;
      } else if (c == 41) {
        out.add(const _Token(_Tk.rpar, ')'));
        _i++;
      } else if (c == 46) {
        out.add(const _Token(_Tk.dot, '.'));
        _i++;
      } else if (c == 44) {
        out.add(const _Token(_Tk.comma, ','));
        _i++;
      } else if (c == 34) {
        out.add(_Token(_Tk.string, _readString()));
      } else if (_isDigit(c) || (c == 46 && _peekDigit())) {
        out.add(_Token(_Tk.number, _readNumber()));
      } else if (_isIdentStart(c)) {
        out.add(_Token(_Tk.ident, _readIdent()));
      } else {
        throw FormatException('bad char');
      }
    }
    out.add(const _Token(_Tk.end, ''));
    return out;
  }

  bool _peekDigit() =>
      _i + 1 < input.length && _isDigit(input.codeUnitAt(_i + 1));

  String _readString() {
    _i++;
    final StringBuffer b = StringBuffer();
    while (_i < input.length) {
      final int c = input.codeUnitAt(_i);
      if (c == 34) {
        _i++;
        return b.toString();
      }
      b.writeCharCode(c);
      _i++;
    }
    throw FormatException('unterminated string');
  }

  String _readNumber() {
    final int start = _i;
    while (_i < input.length && _isDigit(input.codeUnitAt(_i))) {
      _i++;
    }
    if (_i < input.length && input.codeUnitAt(_i) == 46) {
      _i++;
      while (_i < input.length && _isDigit(input.codeUnitAt(_i))) {
        _i++;
      }
    }
    return input.substring(start, _i);
  }

  String _readIdent() {
    final int start = _i;
    _i++;
    while (_i < input.length && _isIdentCont(input.codeUnitAt(_i))) {
      _i++;
    }
    return input.substring(start, _i);
  }

  static bool _isDigit(int c) => c >= 48 && c <= 57;

  static bool _isIdentStart(int c) =>
      (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;

  static bool _isIdentCont(int c) => _isIdentStart(c) || _isDigit(c);
}

class _EvalParser {
  _EvalParser({
    required this.tokens,
    required this.currentSchema,
    required this.workingRowByColId,
    required this.allSchemas,
    required this.rowsByTableId,
    required this.evaluatingColumnId,
    required this.remainingDepth,
  });

  final List<_Token> tokens;
  final TableSchemaEntity currentSchema;
  final Map<String, dynamic> workingRowByColId;
  final List<TableSchemaEntity> allSchemas;
  final Map<String, List<TableRowEntity>> rowsByTableId;
  final String? evaluatingColumnId;
  final int remainingDepth;
  int _i = 0;

  void expectEnd() {
    if (!_check(_Tk.end)) {
      throw FormatException('trailing');
    }
  }

  dynamic parseExpression() {
    dynamic left = parseAdditive();
    if (_matchRel()) {
      final String op = _relLexeme;
      final dynamic right = parseAdditive();
      return _compare(left, op, right);
    }
    return left;
  }

  String _relLexeme = '';

  bool _matchRel() {
    if (_check(_Tk.eq) ||
        _check(_Tk.ne) ||
        _check(_Tk.lt) ||
        _check(_Tk.gt) ||
        _check(_Tk.le) ||
        _check(_Tk.ge)) {
      _relLexeme = tokens[_i].lexeme;
      _advance();
      return true;
    }
    return false;
  }

  dynamic parseAdditive() {
    dynamic left = parseMultiplicative();
    while (true) {
      if (_match(_Tk.plus)) {
        left = _numBin(left, parseMultiplicative(), (num a, num b) => a + b);
      } else if (_match(_Tk.minus)) {
        left = _numBin(left, parseMultiplicative(), (num a, num b) => a - b);
      } else {
        break;
      }
    }
    return left;
  }

  dynamic parseMultiplicative() {
    dynamic left = parseUnary();
    while (true) {
      if (_match(_Tk.mul)) {
        left = _numBin(left, parseUnary(), (num a, num b) => a * b);
      } else if (_match(_Tk.div)) {
        left = _numBin(left, parseUnary(), (num a, num b) => a / b);
      } else {
        break;
      }
    }
    return left;
  }

  dynamic parseUnary() {
    if (_match(_Tk.minus)) {
      return -_toNum(parseUnary());
    }
    return parsePrimary();
  }

  dynamic parsePrimary() {
    if (_match(_Tk.number)) {
      return double.parse(tokens[_i - 1].lexeme);
    }
    if (_check(_Tk.string)) {
      final String s = tokens[_i].lexeme;
      _advance();
      final String? cell = _cellByColumnName(s);
      if (cell != null) {
        return cell;
      }
      return s;
    }
    if (_match(_Tk.lpar)) {
      final dynamic inner = parseExpression();
      if (!_match(_Tk.rpar)) {
        throw FormatException('expected )');
      }
      return inner;
    }
    if (_check(_Tk.ident)) {
      final String name = tokens[_i].lexeme;
      _advance();
      if (_match(_Tk.lpar)) {
        return _dispatchFunction(name);
      }
      if (_match(_Tk.dot)) {
        if (!(_check(_Tk.ident) || _check(_Tk.string))) {
          throw FormatException('expected ref');
        }
        final String colPart = tokens[_i].lexeme;
        _advance();
        return _qualifiedScalar(name, colPart);
      }
      return _bareIdent(name);
    }
    throw FormatException('expected primary');
  }

  dynamic _dispatchFunction(String name) {
    switch (name) {
      case 'LOOKUP':
        return _parseLookupArgs();
      case 'IF':
        return _parseIfArgs();
      case 'SUM':
        return _parseAggregate(_Agg.sum);
      case 'COUNT':
        return _parseAggregate(_Agg.count);
      case 'AVG':
        return _parseAggregate(_Agg.avg);
      default:
        throw FormatException('fn');
    }
  }

  dynamic _parseLookupArgs() {
    final dynamic keyVal = parseExpression();
    if (!_match(_Tk.comma)) {
      throw FormatException(',');
    }
    final String table = _readNameToken();
    if (!_match(_Tk.comma)) {
      throw FormatException(',');
    }
    final String lookupCol = _readNameToken();
    if (!_match(_Tk.comma)) {
      throw FormatException(',');
    }
    final String returnCol = _readNameToken();
    if (!_match(_Tk.rpar)) {
      throw FormatException(')');
    }
    return _runLookup(
      keyVal,
      table,
      lookupCol,
      returnCol,
    );
  }

  String _readNameToken() {
    if (_check(_Tk.ident)) {
      final String s = tokens[_i].lexeme;
      _advance();
      return s;
    }
    if (_check(_Tk.string)) {
      final String s = tokens[_i].lexeme;
      _advance();
      return s;
    }
    throw FormatException('name');
  }

  dynamic _parseIfArgs() {
    final dynamic cond = parseExpression();
    if (!_match(_Tk.comma)) {
      throw FormatException(',');
    }
    final dynamic t = parseExpression();
    if (!_match(_Tk.comma)) {
      throw FormatException(',');
    }
    final dynamic f = parseExpression();
    if (!_match(_Tk.rpar)) {
      throw FormatException(')');
    }
    return _truthy(cond) ? t : f;
  }

  dynamic _parseAggregate(_Agg kind) {
    if (!_check(_Tk.ident) && !_check(_Tk.string)) {
      throw FormatException('table');
    }
    final String tablePart = tokens[_i].lexeme;
    _advance();
    if (!_match(_Tk.dot)) {
      throw FormatException('.');
    }
    final String colPart = _readNameToken();
    if (!_match(_Tk.rpar)) {
      throw FormatException(')');
    }
    return _runAggregate(kind, tablePart, colPart);
  }

  dynamic _runLookup(
    dynamic keyVal,
    String tableName,
    String lookupColumnName,
    String returnColumnName,
  ) {
    final String needle = TableFormulaEvaluator._stringify(keyVal);
    final TableSchemaEntity? target = _schemaByTableName(tableName);
    if (target == null) {
      return '';
    }
    final String? lookupId = _columnIdByName(target, lookupColumnName);
    final String? returnId = _columnIdByName(target, returnColumnName);
    if (lookupId == null || returnId == null) {
      return '';
    }
    final List<TableRowEntity> rows =
        rowsByTableId[target.id] ?? <TableRowEntity>[];
    for (final TableRowEntity r in rows) {
      final Map<String, dynamic> resolved =
          TableFormulaEvaluator.resolveRowValues(
        schema: target,
        row: r,
        allSchemas: allSchemas,
        rowsByTableId: rowsByTableId,
        remainingDepth: remainingDepth - 1,
      );
      final String cell = resolved[lookupId]?.toString() ?? '';
      if (cell == needle) {
        return resolved[returnId]?.toString() ?? '';
      }
    }
    return '';
  }

  dynamic _runAggregate(_Agg kind, String tablePart, String colPart) {
    final TableSchemaEntity? target = _schemaByTableName(tablePart);
    if (target == null) {
      return kind == _Agg.count ? 0 : 0.0;
    }
    final String? colId = _columnIdByName(target, colPart);
    if (colId == null) {
      return kind == _Agg.count ? 0 : 0.0;
    }
    final List<TableRowEntity> rows =
        rowsByTableId[target.id] ?? <TableRowEntity>[];
    if (kind == _Agg.count) {
      int n = 0;
      for (final TableRowEntity r in rows) {
        final Map<String, dynamic> resolved =
            TableFormulaEvaluator.resolveRowValues(
          schema: target,
          row: r,
          allSchemas: allSchemas,
          rowsByTableId: rowsByTableId,
          remainingDepth: remainingDepth - 1,
        );
        final String s = resolved[colId]?.toString().trim() ?? '';
        if (s.isNotEmpty) {
          n++;
        }
      }
      return n;
    }
    final List<double> nums = <double>[];
    for (final TableRowEntity r in rows) {
      final Map<String, dynamic> resolved =
          TableFormulaEvaluator.resolveRowValues(
        schema: target,
        row: r,
        allSchemas: allSchemas,
        rowsByTableId: rowsByTableId,
        remainingDepth: remainingDepth - 1,
      );
      final String s = resolved[colId]?.toString().trim() ?? '';
      if (s.isEmpty) {
        continue;
      }
      final double? v = double.tryParse(s);
      if (v != null) {
        nums.add(v);
      }
    }
    if (nums.isEmpty) {
      return 0.0;
    }
    if (kind == _Agg.sum) {
      return nums.reduce((double a, double b) => a + b);
    }
    return nums.reduce((double a, double b) => a + b) / nums.length;
  }

  TableSchemaEntity? _schemaByTableName(String raw) {
    final String t = raw.trim();
    for (final TableSchemaEntity s in allSchemas) {
      if (s.name.trim() == t) {
        return s;
      }
    }
    return null;
  }

  String? _columnIdByName(TableSchemaEntity schema, String raw) {
    final String t = raw.trim();
    for (final TableColumnEntity c in schema.columns) {
      if (c.name.trim() == t) {
        return c.id;
      }
    }
    return null;
  }

  dynamic _qualifiedScalar(String tablePart, String colPart) {
    final TableSchemaEntity? target = _schemaByTableName(tablePart);
    if (target == null) {
      return '';
    }
    final String? colId = _columnIdByName(target, colPart);
    if (colId == null) {
      return '';
    }
    final List<TableRowEntity> rows =
        rowsByTableId[target.id] ?? <TableRowEntity>[];
    if (rows.isEmpty) {
      return '';
    }
    final Map<String, dynamic> resolved = TableFormulaEvaluator.resolveRowValues(
      schema: target,
      row: rows.first,
      allSchemas: allSchemas,
      rowsByTableId: rowsByTableId,
      remainingDepth: remainingDepth - 1,
    );
    return resolved[colId]?.toString() ?? '';
  }

  dynamic _bareIdent(String name) {
    final String? cell = _cellByColumnName(name);
    if (cell != null) {
      return cell;
    }
    final double? n = double.tryParse(name);
    if (n != null) {
      return n;
    }
    return '';
  }

  String? _cellByColumnName(String name) {
    final String t = name.trim();
    for (final TableColumnEntity c in currentSchema.columns) {
      if (c.name.trim() != t) {
        continue;
      }
      if (c.id == evaluatingColumnId) {
        return null;
      }
      return workingRowByColId[c.id]?.toString();
    }
    return null;
  }

  bool _check(_Tk t) => tokens[_i].type == t;

  void _advance() {
    if (tokens[_i].type != _Tk.end) {
      _i++;
    }
  }

  bool _match(_Tk t) {
    if (_check(t)) {
      _advance();
      return true;
    }
    return false;
  }
}

enum _Agg { sum, count, avg }

bool _truthy(dynamic v) {
  if (v == null) {
    return false;
  }
  if (v is bool) {
    return v;
  }
  if (v is num) {
    return v != 0;
  }
  final String s = v.toString().trim().toLowerCase();
  if (s == 'false' || s == '0' || s.isEmpty) {
    return false;
  }
  return true;
}

bool _compare(dynamic left, String op, dynamic right) {
  final String ls = TableFormulaEvaluator._stringify(left);
  final String rs = TableFormulaEvaluator._stringify(right);
  final num? ln = num.tryParse(ls);
  final num? rn = num.tryParse(rs);
  if (ln != null && rn != null) {
    return switch (op) {
      '=' || '==' => ln == rn,
      '!=' => ln != rn,
      '<' => ln < rn,
      '>' => ln > rn,
      '<=' => ln <= rn,
      '>=' => ln >= rn,
      _ => false,
    };
  }
  return switch (op) {
    '=' || '==' => ls == rs,
    '!=' => ls != rs,
    '<' => ls.compareTo(rs) < 0,
    '>' => ls.compareTo(rs) > 0,
    '<=' => ls.compareTo(rs) <= 0,
    '>=' => ls.compareTo(rs) >= 0,
    _ => false,
  };
}

dynamic _numBin(
  dynamic left,
  dynamic right,
  num Function(num a, num b) fn,
) {
  return fn(_toNum(left), _toNum(right));
}

num _toNum(dynamic v) {
  if (v is num) {
    return v;
  }
  final String s = TableFormulaEvaluator._stringify(v).trim();
  if (s.isEmpty) {
    return 0;
  }
  return double.tryParse(s) ?? 0;
}
