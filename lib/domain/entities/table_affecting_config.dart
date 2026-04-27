class TableRowMatchConfig {
  const TableRowMatchConfig({
    required this.targetColumnId,
    required this.sourceColumnId,
  });

  final String targetColumnId;
  final String sourceColumnId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'targetColumnId': targetColumnId,
    'sourceColumnId': sourceColumnId,
  };

  static TableRowMatchConfig? tryFromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> map = raw.cast<String, dynamic>();
    final String? targetColumnId = map['targetColumnId']?.toString();
    final String? sourceColumnId = map['sourceColumnId']?.toString();
    if (targetColumnId == null ||
        targetColumnId.isEmpty ||
        sourceColumnId == null ||
        sourceColumnId.isEmpty) {
      return null;
    }
    return TableRowMatchConfig(
      targetColumnId: targetColumnId,
      sourceColumnId: sourceColumnId,
    );
  }
}

class TableAffectedColumnRule {
  const TableAffectedColumnRule({
    required this.targetColumnId,
    required this.formula,
  });

  final String targetColumnId;
  final String formula;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'targetColumnId': targetColumnId,
    'formula': formula,
  };

  static TableAffectedColumnRule? tryFromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> map = raw.cast<String, dynamic>();
    final String? targetColumnId = map['targetColumnId']?.toString();
    final String? formula = map['formula']?.toString();
    if (targetColumnId == null ||
        targetColumnId.isEmpty ||
        formula == null ||
        formula.trim().isEmpty) {
      return null;
    }
    return TableAffectedColumnRule(
      targetColumnId: targetColumnId,
      formula: formula.trim(),
    );
  }
}

class TableAffectingConfig {
  const TableAffectingConfig({
    required this.targetTableId,
    required this.match,
    required this.rules,
  });

  final String targetTableId;
  final TableRowMatchConfig match;
  final List<TableAffectedColumnRule> rules;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'targetTableId': targetTableId,
    'match': match.toJson(),
    'rules': rules.map((TableAffectedColumnRule rule) => rule.toJson()).toList(
      growable: false,
    ),
  };

  static TableAffectingConfig? tryFromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> map = raw.cast<String, dynamic>();
    final String? targetTableId = map['targetTableId']?.toString();
    final TableRowMatchConfig? match = TableRowMatchConfig.tryFromJson(
      map['match'],
    );
    final List<TableAffectedColumnRule> rules = ((map['rules'] as List?) ??
            const <dynamic>[])
        .map((dynamic item) => TableAffectedColumnRule.tryFromJson(item))
        .whereType<TableAffectedColumnRule>()
        .toList(growable: false);
    if (targetTableId == null ||
        targetTableId.isEmpty ||
        match == null ||
        rules.isEmpty) {
      return null;
    }
    return TableAffectingConfig(
      targetTableId: targetTableId,
      match: match,
      rules: rules,
    );
  }
}
