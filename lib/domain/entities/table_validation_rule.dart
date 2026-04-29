class TableValidationRule {
  const TableValidationRule({
    required this.id,
    required this.name,
    required this.conditionFormula,
    required this.errorMessage,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String conditionFormula;
  final String errorMessage;
  final bool enabled;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'conditionFormula': conditionFormula,
      'errorMessage': errorMessage,
      'enabled': enabled,
    };
  }

  static TableValidationRule? tryFromJson(Map<String, dynamic>? raw) {
    if (raw == null) {
      return null;
    }
    final String id = (raw['id'] ?? '').toString().trim();
    final String name = (raw['name'] ?? '').toString().trim();
    final String conditionFormula =
        (raw['conditionFormula'] ?? '').toString().trim();
    final String errorMessage = (raw['errorMessage'] ?? '').toString().trim();
    final bool enabled = raw['enabled'] != false;
    if (id.isEmpty || conditionFormula.isEmpty || errorMessage.isEmpty) {
      return null;
    }
    return TableValidationRule(
      id: id,
      name: name,
      conditionFormula: conditionFormula,
      errorMessage: errorMessage,
      enabled: enabled,
    );
  }
}
