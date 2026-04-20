import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';

/// Validates formula strings for the Create Table stepper (syntax, references,
/// and a minimal function allowlist).
class TableFormulaValidator {
  TableFormulaValidator._();

  static const String errRequired = 'Formula is required.';
  static const String errBadTable = 'Referenced table does not exist.';
  static const String errBadColumn = 'Referenced column does not exist.';
  static const String errSyntax = 'Invalid formula syntax.';
  static const String errUnsupportedFn = 'Unsupported formula function.';

  static const Set<String> _allowedFunctions = <String>{
    'SUM',
    'COUNT',
    'AVG',
    'IF',
    'LOOKUP',
  };

  static bool isAllowedFunctionName(String name) =>
      _allowedFunctions.contains(name);

  /// Detects literal division by zero (e.g. `/ 0`, `/0)`); does not prove runtime safety.
  static bool hasObviousDivisionByZero(String formula) {
    final String t = formula.trim();
    if (t.isEmpty) {
      return false;
    }
    return RegExp(r'/\s*0(?:\.0+)?(?![\d.])').hasMatch(t);
  }

  /// Returns an error message or `null` if valid.
  static String? validate({
    required String formula,
    required String currentColumnId,
    required List<ColumnNameDraft> siblingColumns,
    required List<TableSchemaEntity> existingTables,
  }) {
    final String trimmed = formula.trim();
    if (trimmed.isEmpty) {
      return errRequired;
    }

    List<_Token>? tokens;
    try {
      tokens = _Lexer(trimmed).tokenize();
    } catch (_) {
      return errSyntax;
    }

    if (_hasUnsupportedFunctionCall(tokens)) {
      return errUnsupportedFn;
    }

    try {
      final _Parser parser = _Parser(tokens);
      parser.parseExpression();
      parser.expectEnd();
    } catch (_) {
      return errSyntax;
    }

    try {
      _validateReferences(
        tokens,
        currentColumnId: currentColumnId,
        siblingColumns: siblingColumns,
        existingTables: existingTables,
      );
    } on _FormulaRefException catch (e) {
      return e.message;
    }

    return null;
  }

  static bool _hasUnsupportedFunctionCall(List<_Token> tokens) {
    for (int i = 0; i < tokens.length - 1; i++) {
      if (tokens[i].type == _Tk.ident && tokens[i + 1].type == _Tk.lpar) {
        if (!_allowedFunctions.contains(tokens[i].lexeme)) {
          return true;
        }
      }
    }
    return false;
  }

  static void _validateReferences(
    List<_Token> tokens, {
    required String currentColumnId,
    required List<ColumnNameDraft> siblingColumns,
    required List<TableSchemaEntity> existingTables,
  }) {
    final Map<String, String> nameById = <String, String>{
      for (final ColumnNameDraft c in siblingColumns)
        c.id: c.name.trim(),
    };
    final Set<String> siblingNames = <String>{
      for (final ColumnNameDraft c in siblingColumns)
        if (c.id != currentColumnId && c.name.trim().isNotEmpty) c.name.trim(),
    };

    int i = 0;
    while (i < tokens.length) {
      final _Token t = tokens[i];
      if (t.type == _Tk.ident &&
          _allowedFunctions.contains(t.lexeme) &&
          i + 1 < tokens.length &&
          tokens[i + 1].type == _Tk.lpar) {
        i = _skipBalancedParens(tokens, i + 1);
        continue;
      }
      if (t.type == _Tk.ident || t.type == _Tk.string) {
        final String part1 = t.lexeme;
        if (i + 2 < tokens.length &&
            tokens[i + 1].type == _Tk.dot &&
            (tokens[i + 2].type == _Tk.ident ||
                tokens[i + 2].type == _Tk.string)) {
          final String part2 = tokens[i + 2].lexeme;
          _validateQualified(
            part1,
            part2,
            existingTables: existingTables,
          );
          i += 3;
          continue;
        }
        _validateSingle(
          part1,
          currentColumnId: currentColumnId,
          siblingNames: siblingNames,
          nameById: nameById,
        );
        i += 1;
        continue;
      }
      i += 1;
    }
  }

  /// [lparIndex] points at `(` opening the call; returns index after matching `)`.
  static int _skipBalancedParens(List<_Token> tokens, int lparIndex) {
    int depth = 0;
    for (int j = lparIndex; j < tokens.length; j++) {
      if (tokens[j].type == _Tk.lpar) {
        depth++;
      } else if (tokens[j].type == _Tk.rpar) {
        depth--;
        if (depth == 0) {
          return j + 1;
        }
      }
    }
    return tokens.length;
  }

  static void _validateSingle(
    String columnLabel, {
    required String currentColumnId,
    required Set<String> siblingNames,
    required Map<String, String> nameById,
  }) {
    final String selfName = nameById[currentColumnId]?.trim() ?? '';
    if (selfName.isNotEmpty && columnLabel == selfName) {
      throw const _FormulaRefException(TableFormulaValidator.errBadColumn);
    }
    if (!siblingNames.contains(columnLabel)) {
      throw const _FormulaRefException(TableFormulaValidator.errBadColumn);
    }
  }

  static void _validateQualified(
    String tablePart,
    String columnPart, {
    required List<TableSchemaEntity> existingTables,
  }) {
    final String tableName = tablePart.trim();
    final String columnName = columnPart.trim();
    TableSchemaEntity? schema;
    for (final TableSchemaEntity s in existingTables) {
      if (s.name.trim() == tableName) {
        schema = s;
        break;
      }
    }
    if (schema == null) {
      throw const _FormulaRefException(TableFormulaValidator.errBadTable);
    }
    final bool colOk = schema.columns.any(
      (TableColumnEntity c) => c.name.trim() == columnName,
    );
    if (!colOk) {
      throw const _FormulaRefException(TableFormulaValidator.errBadColumn);
    }
  }
}

/// Column id + display name for validation (current table draft).
class ColumnNameDraft {
  const ColumnNameDraft({required this.id, required this.name});

  final String id;
  final String name;
}

class _FormulaRefException implements Exception {
  const _FormulaRefException(this.message);

  final String message;
}

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

  static bool _isIdentCont(int c) =>
      _isIdentStart(c) || _isDigit(c);
}

class _Parser {
  _Parser(this.tokens);

  final List<_Token> tokens;
  int _i = 0;

  void parseExpression() {
    parseAdditive();
    if (_match(_Tk.eq) ||
        _match(_Tk.ne) ||
        _match(_Tk.lt) ||
        _match(_Tk.gt) ||
        _match(_Tk.le) ||
        _match(_Tk.ge)) {
      parseAdditive();
    }
  }

  void parseAdditive() {
    parseMultiplicative();
    while (_match(_Tk.plus) || _match(_Tk.minus)) {
      parseMultiplicative();
    }
  }

  void parseMultiplicative() {
    parseUnary();
    while (_match(_Tk.mul) || _match(_Tk.div)) {
      parseUnary();
    }
  }

  void parseUnary() {
    if (_match(_Tk.minus)) {
      parseUnary();
      return;
    }
    parsePrimary();
  }

  void parsePrimary() {
    if (_match(_Tk.number)) {
      return;
    }
    if (_match(_Tk.lpar)) {
      parseExpression();
      if (!_match(_Tk.rpar)) {
        throw FormatException('expected )');
      }
      return;
    }
    if (_check(_Tk.ident)) {
      final String name = tokens[_i].lexeme;
      _advance();
      if (_match(_Tk.lpar)) {
        if (!TableFormulaValidator.isAllowedFunctionName(name)) {
          throw FormatException('unsupported fn');
        }
        parseArgumentList();
        if (!_match(_Tk.rpar)) {
          throw FormatException('expected )');
        }
        return;
      }
      if (_match(_Tk.dot)) {
        if (!(_check(_Tk.ident) || _check(_Tk.string))) {
          throw FormatException('expected ref');
        }
        _advance();
      }
      return;
    }
    if (_check(_Tk.string)) {
      _advance();
      if (_match(_Tk.dot)) {
        if (!(_check(_Tk.ident) || _check(_Tk.string))) {
          throw FormatException('expected ref');
        }
        _advance();
      }
      return;
    }
    throw FormatException('expected primary');
  }

  void parseArgumentList() {
    if (_check(_Tk.rpar)) {
      return;
    }
    parseExpression();
    while (_match(_Tk.comma)) {
      parseExpression();
    }
  }

  void expectEnd() {
    if (!_check(_Tk.end)) {
      throw FormatException('trailing');
    }
  }

  bool _match(_Tk t) {
    if (_check(t)) {
      _advance();
      return true;
    }
    return false;
  }

  bool _check(_Tk t) => tokens[_i].type == t;

  void _advance() {
    if (tokens[_i].type != _Tk.end) {
      _i++;
    }
  }
}
