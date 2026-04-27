/// Validation behavior for [TableColumnType.text] form fields.
enum TableTextValidationKind {
  none,
  email,
  phone,
  password,
  username,
  custom;

  static TableTextValidationKind fromStorage(String? value) {
    switch (value?.trim().toLowerCase() ?? '') {
      case 'email':
        return email;
      case 'phone':
        return phone;
      case 'password':
        return password;
      case 'username':
        return username;
      case 'custom':
        return custom;
      case '':
      case 'none':
        return none;
      default:
        return none;
    }
  }

  String get storageValue => switch (this) {
    TableTextValidationKind.none => 'none',
    TableTextValidationKind.email => 'email',
    TableTextValidationKind.phone => 'phone',
    TableTextValidationKind.password => 'password',
    TableTextValidationKind.username => 'username',
    TableTextValidationKind.custom => 'custom',
  };
}
