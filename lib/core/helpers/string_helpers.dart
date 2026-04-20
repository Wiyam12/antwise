/// Small string utilities shared across features.
abstract final class StringHelpers {
  static bool isBlank(String? value) =>
      value == null || value.trim().isEmpty;
}
