import 'dart:convert';

/// What kind of mutation an [AiBuildAction] performs. Drives UI color
/// (green / amber / red) and the verb prefix in checklist labels.
enum AiBuildActionIntent {
  create,
  update,
  delete,
}

/// Status of a Build-mode proposal in the chat.
enum AiBuildActionStatus {
  pending,
  applied,
  discarded,
  failed;

  static AiBuildActionStatus fromStorage(String? raw) {
    switch (raw) {
      case 'applied':
        return AiBuildActionStatus.applied;
      case 'discarded':
        return AiBuildActionStatus.discarded;
      case 'failed':
        return AiBuildActionStatus.failed;
      case 'pending':
      default:
        return AiBuildActionStatus.pending;
    }
  }

  String get storageValue => switch (this) {
        AiBuildActionStatus.pending => 'pending',
        AiBuildActionStatus.applied => 'applied',
        AiBuildActionStatus.discarded => 'discarded',
        AiBuildActionStatus.failed => 'failed',
      };
}

/// One AI-proposed Build action.
sealed class AiBuildAction {
  const AiBuildAction({
    this.ref,
    this.status = AiBuildActionStatus.pending,
    this.failureReason,
  });

  /// Symbolic id used by sibling actions in the same response (e.g. a card
  /// pointing at a table that's also being created in this batch).
  final String? ref;

  final AiBuildActionStatus status;
  final String? failureReason;

  String get kind;

  /// Mutation classification — drives UI color and checklist verbs.
  AiBuildActionIntent get intent {
    if (kind.startsWith('create_')) {
      return AiBuildActionIntent.create;
    }
    if (kind.startsWith('update_')) {
      return AiBuildActionIntent.update;
    }
    if (kind.startsWith('delete_')) {
      return AiBuildActionIntent.delete;
    }
    return AiBuildActionIntent.create;
  }

  /// Short human title for the preview card heading.
  String get displayTitle;

  /// One-line subtitle (entity name).
  String get displaySubtitle;

  /// Single-line checklist label (verb + noun + kind), e.g.
  /// "Create Dashboard page", "Add Summary card".
  String get checklistLabel;

  /// Returns a copy with [status] (and optionally an updated user-visible
  /// name/title and a [failureReason]). [resolvedName] is set by the executor
  /// after auto-resolving naming collisions, e.g. "Reports 2".
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  });

  Map<String, dynamic> toJson();

  static AiBuildAction? fromJson(Map<String, dynamic> json) {
    final String? type = json['type'] as String?;
    final AiBuildActionStatus status = AiBuildActionStatus.fromStorage(
      json['status'] as String?,
    );
    final String? failureReason = json['failureReason'] as String?;
    final String? ref = json['ref'] as String?;
    switch (type) {
      case 'create_page':
        return CreatePageAction(
          ref: ref,
          name: (json['name'] as String?)?.trim() ?? '',
          icon: (json['icon'] as String?)?.trim() ?? 'article_outlined',
          navigation: AiBuildPageNavigation.fromStorage(
            json['navigation'] as String?,
          ),
          status: status,
          failureReason: failureReason,
        );
      case 'create_table':
        final List<dynamic> rawColumns =
            (json['columns'] as List<dynamic>?) ?? const <dynamic>[];
        final List<AiBuildColumnSpec> columns = rawColumns
            .whereType<Map<String, dynamic>>()
            .map(AiBuildColumnSpec.fromJson)
            .whereType<AiBuildColumnSpec>()
            .toList(growable: false);
        final AiBuildTableKind kind =
            AiBuildTableKind.fromStorage(json['kind'] as String?);
        final AiBuildSummarySpec? summary = json['summary'] is Map<String, dynamic>
            ? AiBuildSummarySpec.fromJson(
                json['summary'] as Map<String, dynamic>,
              )
            : null;
        return CreateTableAction(
          ref: ref,
          pageRef: (json['pageRef'] as String?)?.trim() ?? '',
          name: (json['name'] as String?)?.trim() ?? '',
          columns: columns,
          tableKind: kind,
          summary: summary,
          status: status,
          failureReason: failureReason,
        );
      case 'create_card_widget':
        return CreateCardWidgetAction(
          ref: ref,
          pageRef: (json['pageRef'] as String?)?.trim() ?? '',
          tableRef: (json['tableRef'] as String?)?.trim() ?? '',
          title: (json['title'] as String?)?.trim() ?? '',
          columnName: (json['columnName'] as String?)?.trim() ?? '',
          formula: (json['formula'] as String?)?.trim() ?? '',
          status: status,
          failureReason: failureReason,
        );
      case 'create_chart_widget':
        return CreateChartWidgetAction(
          ref: ref,
          pageRef: (json['pageRef'] as String?)?.trim() ?? '',
          tableRef: (json['tableRef'] as String?)?.trim() ?? '',
          title: (json['title'] as String?)?.trim() ?? '',
          chartType: AiBuildChartType.fromStorage(
            json['chartType'] as String?,
          ),
          xColumn: (json['xColumn'] as String?)?.trim() ?? '',
          yColumn: (json['yColumn'] as String?)?.trim() ?? '',
          status: status,
          failureReason: failureReason,
        );
      case 'update_page':
        final String? navRaw = json['navigation'] as String?;
        return UpdatePageAction(
          ref: ref,
          name: (json['name'] as String?)?.trim() ?? '',
          newName: (json['newName'] as String?)?.trim(),
          icon: (json['icon'] as String?)?.trim(),
          navigation: navRaw == null
              ? null
              : AiBuildPageNavigation.fromStorage(navRaw),
          status: status,
          failureReason: failureReason,
        );
      case 'update_table':
        final List<dynamic> rawColumns =
            (json['columns'] as List<dynamic>?) ?? const <dynamic>[];
        final List<AiBuildColumnSpec> columns = rawColumns
            .whereType<Map<String, dynamic>>()
            .map(AiBuildColumnSpec.fromJson)
            .whereType<AiBuildColumnSpec>()
            .toList(growable: false);
        final AiBuildTableKind kind =
            AiBuildTableKind.fromStorage(json['kind'] as String?);
        final AiBuildSummarySpec? summary = json['summary'] is Map<String, dynamic>
            ? AiBuildSummarySpec.fromJson(
                json['summary'] as Map<String, dynamic>,
              )
            : null;
        return UpdateTableAction(
          ref: ref,
          name: (json['name'] as String?)?.trim() ?? '',
          newName: (json['newName'] as String?)?.trim(),
          columns: columns,
          tableKind: kind,
          summary: summary,
          status: status,
          failureReason: failureReason,
        );
      case 'update_widget':
        final String? chartTypeRaw = json['chartType'] as String?;
        return UpdateWidgetAction(
          ref: ref,
          pageRef: (json['pageRef'] as String?)?.trim() ?? '',
          title: (json['title'] as String?)?.trim() ?? '',
          newTitle: (json['newTitle'] as String?)?.trim(),
          tableRef: (json['tableRef'] as String?)?.trim(),
          columnName: (json['columnName'] as String?)?.trim(),
          formula: (json['formula'] as String?)?.trim(),
          chartType: chartTypeRaw == null
              ? null
              : AiBuildChartType.fromStorage(chartTypeRaw),
          xColumn: (json['xColumn'] as String?)?.trim(),
          yColumn: (json['yColumn'] as String?)?.trim(),
          status: status,
          failureReason: failureReason,
        );
      case 'delete_page':
        return DeletePageAction(
          ref: ref,
          name: (json['name'] as String?)?.trim() ?? '',
          status: status,
          failureReason: failureReason,
        );
      case 'delete_table':
        return DeleteTableAction(
          ref: ref,
          name: (json['name'] as String?)?.trim() ?? '',
          status: status,
          failureReason: failureReason,
        );
      case 'delete_widget':
        return DeleteWidgetAction(
          ref: ref,
          pageRef: (json['pageRef'] as String?)?.trim() ?? '',
          title: (json['title'] as String?)?.trim() ?? '',
          status: status,
          failureReason: failureReason,
        );
      default:
        return null;
    }
  }
}

/// Bottom nav / drawer placement requested for a new page.
enum AiBuildPageNavigation {
  bottom,
  drawer,
  both,
  none;

  static AiBuildPageNavigation fromStorage(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'drawer':
        return AiBuildPageNavigation.drawer;
      case 'both':
        return AiBuildPageNavigation.both;
      case 'none':
        return AiBuildPageNavigation.none;
      case 'bottom':
      default:
        return AiBuildPageNavigation.bottom;
    }
  }

  String get storageValue => switch (this) {
        AiBuildPageNavigation.bottom => 'bottom',
        AiBuildPageNavigation.drawer => 'drawer',
        AiBuildPageNavigation.both => 'both',
        AiBuildPageNavigation.none => 'none',
      };

  bool get showInBottomNav =>
      this == AiBuildPageNavigation.bottom || this == AiBuildPageNavigation.both;
  bool get showInDrawer =>
      this == AiBuildPageNavigation.drawer || this == AiBuildPageNavigation.both;
}

enum AiBuildChartType {
  bar,
  line,
  pie;

  static AiBuildChartType fromStorage(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'line':
        return AiBuildChartType.line;
      case 'pie':
        return AiBuildChartType.pie;
      case 'bar':
      default:
        return AiBuildChartType.bar;
    }
  }

  String get storageValue => switch (this) {
        AiBuildChartType.bar => 'bar',
        AiBuildChartType.line => 'line',
        AiBuildChartType.pie => 'pie',
      };
}

/// Standard table (regular CRUD) vs aggregated summary table.
enum AiBuildTableKind {
  standard,
  summary;

  static AiBuildTableKind fromStorage(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'summary':
        return AiBuildTableKind.summary;
      case 'standard':
      default:
        return AiBuildTableKind.standard;
    }
  }

  String get storageValue => switch (this) {
        AiBuildTableKind.standard => 'standard',
        AiBuildTableKind.summary => 'summary',
      };
}

/// Aggregation operator on a summary table column.
enum AiBuildSummaryOperation {
  sum,
  count,
  avg,
  min,
  max;

  static AiBuildSummaryOperation fromStorage(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'count':
        return AiBuildSummaryOperation.count;
      case 'avg':
      case 'average':
      case 'mean':
        return AiBuildSummaryOperation.avg;
      case 'min':
        return AiBuildSummaryOperation.min;
      case 'max':
        return AiBuildSummaryOperation.max;
      case 'sum':
      case 'total':
      default:
        return AiBuildSummaryOperation.sum;
    }
  }

  String get storageValue => switch (this) {
        AiBuildSummaryOperation.sum => 'sum',
        AiBuildSummaryOperation.count => 'count',
        AiBuildSummaryOperation.avg => 'avg',
        AiBuildSummaryOperation.min => 'min',
        AiBuildSummaryOperation.max => 'max',
      };
}

/// Minimal blueprint for a summary table the AI is asked to build.
///
/// All entity references are by **name** so the executor can resolve them
/// against the current workspace (including ones created earlier in the same
/// batch). The executor materializes a full
/// [TableSummaryConfig] + derived schema columns from this spec.
class AiBuildSummarySpec {
  const AiBuildSummarySpec({
    required this.sourceTable,
    required this.groupBy,
    required this.aggregate,
    this.operation = AiBuildSummaryOperation.sum,
  });

  /// Existing table the summary aggregates over (e.g. `"Transactions"`).
  final String sourceTable;

  /// Column name on [sourceTable] to group rows by (e.g. `"Product"`).
  final String groupBy;

  /// Column name on [sourceTable] to aggregate (e.g. `"Total Amount"`).
  final String aggregate;

  /// Aggregation operator applied to [aggregate]. Defaults to `sum`.
  final AiBuildSummaryOperation operation;

  static AiBuildSummarySpec? fromJson(Map<String, dynamic> json) {
    final String source = (json['sourceTable'] as String?)?.trim() ?? '';
    final String groupBy = (json['groupBy'] as String?)?.trim() ?? '';
    final String aggregate = (json['aggregate'] as String?)?.trim() ?? '';
    if (source.isEmpty || groupBy.isEmpty || aggregate.isEmpty) {
      return null;
    }
    return AiBuildSummarySpec(
      sourceTable: source,
      groupBy: groupBy,
      aggregate: aggregate,
      operation: AiBuildSummaryOperation.fromStorage(
        json['operation'] as String?,
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sourceTable': sourceTable,
        'groupBy': groupBy,
        'aggregate': aggregate,
        'operation': operation.storageValue,
      };
}

/// One column inside a `create_table` proposal.
class AiBuildColumnSpec {
  const AiBuildColumnSpec({
    required this.name,
    required this.type,
    this.required = false,
    this.unique = false,
  });

  final String name;
  final String type;
  final bool required;
  final bool unique;

  static const Set<String> _allowedTypes = <String>{
    'text',
    'number',
    'date',
    'boolean',
    'dropdown',
  };

  static AiBuildColumnSpec? fromJson(Map<String, dynamic> json) {
    final String name = (json['name'] as String?)?.trim() ?? '';
    final String type = (json['type'] as String?)?.trim().toLowerCase() ?? '';
    if (name.isEmpty || !_allowedTypes.contains(type)) {
      return null;
    }
    return AiBuildColumnSpec(
      name: name,
      type: type,
      required: json['required'] == true,
      unique: json['unique'] == true,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'type': type,
        if (required) 'required': true,
        if (unique) 'unique': true,
      };
}

class CreatePageAction extends AiBuildAction {
  const CreatePageAction({
    super.ref,
    required this.name,
    this.icon = 'article_outlined',
    this.navigation = AiBuildPageNavigation.bottom,
    super.status,
    super.failureReason,
  });

  final String name;
  final String icon;
  final AiBuildPageNavigation navigation;

  @override
  String get kind => 'create_page';

  @override
  String get displayTitle => 'Create page';

  @override
  String get displaySubtitle => name;

  @override
  String get checklistLabel =>
      name.trim().isEmpty ? 'Create page' : 'Create $name page';

  @override
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  }) {
    return CreatePageAction(
      ref: ref,
      name: resolvedName ?? name,
      icon: icon,
      navigation: navigation,
      status: status,
      failureReason: failureReason,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': kind,
        if (ref != null) 'ref': ref,
        'name': name,
        'icon': icon,
        'navigation': navigation.storageValue,
        'status': status.storageValue,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

class CreateTableAction extends AiBuildAction {
  const CreateTableAction({
    super.ref,
    required this.pageRef,
    required this.name,
    required this.columns,
    this.tableKind = AiBuildTableKind.standard,
    this.summary,
    super.status,
    super.failureReason,
  });

  final String pageRef;
  final String name;
  final List<AiBuildColumnSpec> columns;

  /// Standard table (default) or aggregated summary.
  final AiBuildTableKind tableKind;

  /// Required when [tableKind] is [AiBuildTableKind.summary]; ignored otherwise.
  final AiBuildSummarySpec? summary;

  @override
  String get kind => 'create_table';

  @override
  String get displayTitle =>
      tableKind == AiBuildTableKind.summary ? 'Create summary table' : 'Create table';

  @override
  String get displaySubtitle => name;

  @override
  String get checklistLabel {
    if (name.trim().isEmpty) {
      return tableKind == AiBuildTableKind.summary
          ? 'Create summary table'
          : 'Create table';
    }
    return tableKind == AiBuildTableKind.summary
        ? 'Create $name summary table'
        : 'Create $name table';
  }

  @override
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  }) {
    return CreateTableAction(
      ref: ref,
      pageRef: pageRef,
      name: resolvedName ?? name,
      columns: columns,
      tableKind: tableKind,
      summary: summary,
      status: status,
      failureReason: failureReason,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': kind,
        if (ref != null) 'ref': ref,
        'pageRef': pageRef,
        'name': name,
        'columns': columns.map((AiBuildColumnSpec c) => c.toJson()).toList(),
        if (tableKind != AiBuildTableKind.standard) 'kind': tableKind.storageValue,
        if (summary != null) 'summary': summary!.toJson(),
        'status': status.storageValue,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

class CreateCardWidgetAction extends AiBuildAction {
  const CreateCardWidgetAction({
    super.ref,
    required this.pageRef,
    required this.tableRef,
    required this.title,
    this.columnName = '',
    this.formula = '',
    super.status,
    super.failureReason,
  });

  final String pageRef;
  final String tableRef;
  final String title;
  final String columnName;
  final String formula;

  @override
  String get kind => 'create_card_widget';

  @override
  String get displayTitle => 'Create card widget';

  @override
  String get displaySubtitle => title.isEmpty ? '(untitled card)' : title;

  @override
  String get checklistLabel =>
      title.trim().isEmpty ? 'Add card widget' : 'Add $title card';

  @override
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  }) {
    return CreateCardWidgetAction(
      ref: ref,
      pageRef: pageRef,
      tableRef: tableRef,
      title: resolvedName ?? title,
      columnName: columnName,
      formula: formula,
      status: status,
      failureReason: failureReason,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': kind,
        if (ref != null) 'ref': ref,
        'pageRef': pageRef,
        'tableRef': tableRef,
        'title': title,
        if (columnName.isNotEmpty) 'columnName': columnName,
        if (formula.isNotEmpty) 'formula': formula,
        'status': status.storageValue,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

class CreateChartWidgetAction extends AiBuildAction {
  const CreateChartWidgetAction({
    super.ref,
    required this.pageRef,
    required this.tableRef,
    required this.title,
    this.chartType = AiBuildChartType.bar,
    required this.xColumn,
    required this.yColumn,
    super.status,
    super.failureReason,
  });

  final String pageRef;
  final String tableRef;
  final String title;
  final AiBuildChartType chartType;
  final String xColumn;
  final String yColumn;

  @override
  String get kind => 'create_chart_widget';

  @override
  String get displayTitle => 'Create chart widget';

  @override
  String get displaySubtitle => title.isEmpty ? '(untitled chart)' : title;

  @override
  String get checklistLabel =>
      title.trim().isEmpty ? 'Add chart widget' : 'Add $title chart';

  @override
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  }) {
    return CreateChartWidgetAction(
      ref: ref,
      pageRef: pageRef,
      tableRef: tableRef,
      title: resolvedName ?? title,
      chartType: chartType,
      xColumn: xColumn,
      yColumn: yColumn,
      status: status,
      failureReason: failureReason,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': kind,
        if (ref != null) 'ref': ref,
        'pageRef': pageRef,
        'tableRef': tableRef,
        'title': title,
        'chartType': chartType.storageValue,
        'xColumn': xColumn,
        'yColumn': yColumn,
        'status': status.storageValue,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

/// Rename / re-icon / re-place an existing page. Fields that are null are
/// left untouched.
class UpdatePageAction extends AiBuildAction {
  const UpdatePageAction({
    super.ref,
    required this.name,
    this.newName,
    this.icon,
    this.navigation,
    super.status,
    super.failureReason,
  });

  /// Existing page name (used to look the page up).
  final String name;
  final String? newName;
  final String? icon;
  final AiBuildPageNavigation? navigation;

  @override
  String get kind => 'update_page';

  @override
  String get displayTitle => 'Update page';

  @override
  String get displaySubtitle => newName == null || newName!.isEmpty
      ? name
      : '$name → $newName';

  @override
  String get checklistLabel {
    if (newName != null && newName!.isNotEmpty && newName != name) {
      return 'Rename $name page to $newName';
    }
    return 'Update $name page';
  }

  @override
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  }) {
    return UpdatePageAction(
      ref: ref,
      name: resolvedName ?? name,
      newName: newName,
      icon: icon,
      navigation: navigation,
      status: status,
      failureReason: failureReason,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': kind,
        if (ref != null) 'ref': ref,
        'name': name,
        if (newName != null) 'newName': newName,
        if (icon != null) 'icon': icon,
        if (navigation != null) 'navigation': navigation!.storageValue,
        'status': status.storageValue,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

/// Replace the columns (and optionally rename) of an existing table. The
/// executor preserves column IDs by name where possible so existing row data
/// stays linked to renamed-but-conceptually-same columns.
///
/// When [tableKind] is [AiBuildTableKind.summary], the action acts as a
/// **conversion**: the existing table's schema is replaced with summary-derived
/// columns and a [TableSummaryConfig] is built from [summary]. Existing rows
/// on the table are dropped because the column schema changes completely.
class UpdateTableAction extends AiBuildAction {
  const UpdateTableAction({
    super.ref,
    required this.name,
    required this.columns,
    this.newName,
    this.tableKind = AiBuildTableKind.standard,
    this.summary,
    super.status,
    super.failureReason,
  });

  final String name;
  final String? newName;
  final List<AiBuildColumnSpec> columns;

  /// Pass [AiBuildTableKind.summary] together with [summary] to convert a
  /// standard table into a summary table (or replace an existing summary).
  final AiBuildTableKind tableKind;
  final AiBuildSummarySpec? summary;

  @override
  String get kind => 'update_table';

  @override
  String get displayTitle =>
      tableKind == AiBuildTableKind.summary ? 'Convert to summary' : 'Update table';

  @override
  String get displaySubtitle => newName == null || newName!.isEmpty
      ? name
      : '$name → $newName';

  @override
  String get checklistLabel {
    if (tableKind == AiBuildTableKind.summary) {
      if (newName != null && newName!.isNotEmpty && newName != name) {
        return 'Convert $name into $newName summary table';
      }
      return 'Convert $name into a summary table';
    }
    if (newName != null && newName!.isNotEmpty && newName != name) {
      return 'Replace $name table (rename to $newName)';
    }
    return 'Replace $name table schema';
  }

  @override
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  }) {
    return UpdateTableAction(
      ref: ref,
      name: resolvedName ?? name,
      newName: newName,
      columns: columns,
      tableKind: tableKind,
      summary: summary,
      status: status,
      failureReason: failureReason,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': kind,
        if (ref != null) 'ref': ref,
        'name': name,
        if (newName != null) 'newName': newName,
        'columns': columns.map((AiBuildColumnSpec c) => c.toJson()).toList(),
        if (tableKind != AiBuildTableKind.standard) 'kind': tableKind.storageValue,
        if (summary != null) 'summary': summary!.toJson(),
        'status': status.storageValue,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

/// Update an existing card / chart widget on a page. Only non-null fields are
/// applied to the existing widget config.
class UpdateWidgetAction extends AiBuildAction {
  const UpdateWidgetAction({
    super.ref,
    required this.pageRef,
    required this.title,
    this.newTitle,
    this.tableRef,
    this.columnName,
    this.formula,
    this.chartType,
    this.xColumn,
    this.yColumn,
    super.status,
    super.failureReason,
  });

  final String pageRef;
  final String title;
  final String? newTitle;
  final String? tableRef;
  final String? columnName;
  final String? formula;
  final AiBuildChartType? chartType;
  final String? xColumn;
  final String? yColumn;

  @override
  String get kind => 'update_widget';

  @override
  String get displayTitle => 'Update widget';

  @override
  String get displaySubtitle =>
      newTitle == null || newTitle!.isEmpty ? title : '$title → $newTitle';

  @override
  String get checklistLabel {
    if (newTitle != null && newTitle!.isNotEmpty && newTitle != title) {
      return 'Rename $title widget to $newTitle';
    }
    return 'Update $title widget';
  }

  @override
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  }) {
    return UpdateWidgetAction(
      ref: ref,
      pageRef: pageRef,
      title: resolvedName ?? title,
      newTitle: newTitle,
      tableRef: tableRef,
      columnName: columnName,
      formula: formula,
      chartType: chartType,
      xColumn: xColumn,
      yColumn: yColumn,
      status: status,
      failureReason: failureReason,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': kind,
        if (ref != null) 'ref': ref,
        'pageRef': pageRef,
        'title': title,
        if (newTitle != null) 'newTitle': newTitle,
        if (tableRef != null) 'tableRef': tableRef,
        if (columnName != null) 'columnName': columnName,
        if (formula != null) 'formula': formula,
        if (chartType != null) 'chartType': chartType!.storageValue,
        if (xColumn != null) 'xColumn': xColumn,
        if (yColumn != null) 'yColumn': yColumn,
        'status': status.storageValue,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

/// Soft-delete an entire page. The executor cascades: it deletes child
/// widgets, deletes tables that live on the page (including their rows), and
/// strips the page id from the navigation config.
class DeletePageAction extends AiBuildAction {
  const DeletePageAction({
    super.ref,
    required this.name,
    super.status,
    super.failureReason,
  });

  final String name;

  @override
  String get kind => 'delete_page';

  @override
  String get displayTitle => 'Delete page';

  @override
  String get displaySubtitle => name;

  @override
  String get checklistLabel => 'Remove $name page';

  @override
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  }) {
    return DeletePageAction(
      ref: ref,
      name: resolvedName ?? name,
      status: status,
      failureReason: failureReason,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': kind,
        if (ref != null) 'ref': ref,
        'name': name,
        'status': status.storageValue,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

/// Delete a table schema, its rows, every widget referencing it, and the
/// `table:<id>` entry from its host page's layout.
class DeleteTableAction extends AiBuildAction {
  const DeleteTableAction({
    super.ref,
    required this.name,
    super.status,
    super.failureReason,
  });

  final String name;

  @override
  String get kind => 'delete_table';

  @override
  String get displayTitle => 'Delete table';

  @override
  String get displaySubtitle => name;

  @override
  String get checklistLabel => 'Remove $name table';

  @override
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  }) {
    return DeleteTableAction(
      ref: ref,
      name: resolvedName ?? name,
      status: status,
      failureReason: failureReason,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': kind,
        if (ref != null) 'ref': ref,
        'name': name,
        'status': status.storageValue,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

/// Delete a card / chart widget by title on a specific page; also removes it
/// from the host page's layoutOrder and widgetOrder.
class DeleteWidgetAction extends AiBuildAction {
  const DeleteWidgetAction({
    super.ref,
    required this.pageRef,
    required this.title,
    super.status,
    super.failureReason,
  });

  final String pageRef;
  final String title;

  @override
  String get kind => 'delete_widget';

  @override
  String get displayTitle => 'Delete widget';

  @override
  String get displaySubtitle => title;

  @override
  String get checklistLabel => 'Remove $title widget';

  @override
  AiBuildAction copyWithStatus(
    AiBuildActionStatus status, {
    String? failureReason,
    String? resolvedName,
  }) {
    return DeleteWidgetAction(
      ref: ref,
      pageRef: pageRef,
      title: resolvedName ?? title,
      status: status,
      failureReason: failureReason,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': kind,
        if (ref != null) 'ref': ref,
        'pageRef': pageRef,
        'title': title,
        'status': status.storageValue,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

/// Wrapper persisted as `ChatMessage.metadataJson` for Build-mode replies.
class AiBuildMessageMetadata {
  const AiBuildMessageMetadata({
    required this.actions,
    this.warnings = const <String>[],
  });

  final List<AiBuildAction> actions;
  final List<String> warnings;

  bool get hasActions => actions.isNotEmpty;

  String encode() {
    final Map<String, dynamic> payload = <String, dynamic>{
      'mode': 'build',
      'actions': actions.map((AiBuildAction a) => a.toJson()).toList(),
      if (warnings.isNotEmpty) 'warnings': warnings,
    };
    return jsonEncode(payload);
  }

  /// Returns null when [raw] does not contain a build-mode payload.
  static AiBuildMessageMetadata? tryDecode(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      if (decoded['mode'] != 'build') {
        return null;
      }
      final List<dynamic> rawActions =
          (decoded['actions'] as List<dynamic>?) ?? const <dynamic>[];
      final List<AiBuildAction> actions = rawActions
          .whereType<Map<String, dynamic>>()
          .map(AiBuildAction.fromJson)
          .whereType<AiBuildAction>()
          .toList(growable: false);
      final List<dynamic> rawWarnings =
          (decoded['warnings'] as List<dynamic>?) ?? const <dynamic>[];
      final List<String> warnings = rawWarnings
          .whereType<String>()
          .toList(growable: false);
      return AiBuildMessageMetadata(actions: actions, warnings: warnings);
    } catch (_) {
      return null;
    }
  }

  AiBuildMessageMetadata copyWithUpdatedAction(
    int index,
    AiBuildAction next,
  ) {
    final List<AiBuildAction> copy = List<AiBuildAction>.from(actions);
    if (index < 0 || index >= copy.length) {
      return this;
    }
    copy[index] = next;
    return AiBuildMessageMetadata(actions: copy, warnings: warnings);
  }
}
