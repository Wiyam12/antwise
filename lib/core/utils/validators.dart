/// General-purpose validation helpers for forms and inputs.
abstract final class Validators {
  static String? required(String? value, {String message = 'Required'}) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }
}
