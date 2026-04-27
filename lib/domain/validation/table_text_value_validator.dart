import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_text_validation_kind.dart';

/// Runtime validation for text column values (create/edit table row modals).
abstract final class TableTextValueValidator {
  static const String _emailError = 'Please enter a valid email address.';

  /// Pragmatic email check (not exhaustive RFC).
  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static final RegExp _phonePattern = RegExp(
    r'^[+]?[0-9][\d\s\-().]{6,20}$',
  );

  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,32}$');

  static String? validate({
    required TableColumnEntity col,
    required String? raw,
  }) {
    if (col.type != TableColumnType.text) {
      return null;
    }
    final String t = raw?.trim() ?? '';
    if (col.isRequired && t.isEmpty) {
      return 'This field is required.';
    }
    if (t.isEmpty) {
      return null;
    }
    return switch (col.textValidationKind) {
      TableTextValidationKind.none => null,
      TableTextValidationKind.email =>
        _emailPattern.hasMatch(t) ? null : _emailError,
      TableTextValidationKind.phone =>
        _phonePattern.hasMatch(t)
            ? null
            : 'Please enter a valid phone number.',
      TableTextValidationKind.password => t.length >= 8
          ? null
          : 'Password must be at least 8 characters.',
      TableTextValidationKind.username => _usernamePattern.hasMatch(t)
          ? null
          : 'Use 3–32 letters, numbers, or underscores only.',
      TableTextValidationKind.custom => _custom(t, col.textCustomRegex),
    };
  }

  static String? _custom(String t, String? pattern) {
    final String p = pattern?.trim() ?? '';
    if (p.isEmpty) {
      return 'This field is not configured with a valid pattern.';
    }
    try {
      final RegExp re = RegExp(p);
      return re.hasMatch(t) ? null : 'Value does not match the required pattern.';
    } catch (_) {
      return 'Invalid column validation pattern.';
    }
  }
}
