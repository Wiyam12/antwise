import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_affecting_config.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_layout_type.dart';
import 'package:antwise/domain/entities/table_list_design_layout.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_inventory_deduction_config.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';
import 'package:antwise/domain/entities/table_text_validation_kind.dart';
import 'package:antwise/domain/entities/table_validation_rule.dart';

Map<String, dynamic>? _readStringDynamicMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map(
      (dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v),
    );
  }
  return null;
}

TableSchemaEntity tableSchemaEntityFromHive(TableSchemaHiveModel model) {
  final List<TableColumnEntity> cols = model.columns
      .map((Map<String, dynamic> raw) {
        final List<String> dropdown =
            ((raw['dropdownOptions'] as List?) ?? const <dynamic>[])
                .map((dynamic e) => e.toString())
                .toList(growable: false);
        return TableColumnEntity(
          id: (raw['id'] ?? '').toString(),
          name: (raw['name'] ?? '').toString(),
          type: TableColumnType.fromStorage(
            (raw['type'] ?? 'text').toString(),
          ),
          includeInCreateForm: raw['includeInCreateForm'] as bool? ?? true,
          includeInEditForm: raw['includeInEditForm'] as bool? ?? true,
          isRequired: raw['isRequired'] as bool? ?? false,
          isUnique: raw['isUnique'] as bool? ?? false,
          pattern: raw['pattern'] as String?,
          formula: raw['formula'] as String?,
          formulaDefinition: _readStringDynamicMap(raw['formulaDefinition']),
          dropdownOptions: dropdown,
          dropdownSourceKind: TableColumnDropdownSourceKind.fromStorage(
            raw['dropdownSourceKind']?.toString(),
          ),
          dropdownSourceTableId: raw['dropdownSourceTableId']?.toString(),
          dropdownSourceColumnId: raw['dropdownSourceColumnId']?.toString(),
          textFieldHint: raw['textFieldHint']?.toString(),
          textPrefixIconKey: raw['textPrefixIconKey']?.toString(),
          textSuffixIconKey: raw['textSuffixIconKey']?.toString(),
          textValidationKind: TableTextValidationKind.fromStorage(
            raw['textValidationKind']?.toString(),
          ),
          textCustomRegex: raw['textCustomRegex']?.toString(),
          dateDefaultToday: raw['dateDefaultToday'] as bool? ?? false,
          numberFieldHint: raw['numberFieldHint']?.toString(),
          numberPrefixText: raw['numberPrefixText']?.toString(),
          numberSuffixText: raw['numberSuffixText']?.toString(),
          numberPrefixIconKey: raw['numberPrefixIconKey']?.toString(),
          numberSuffixIconKey: raw['numberSuffixIconKey']?.toString(),
          numberMinValue: (raw['numberMinValue'] as num?)?.toDouble(),
          numberMaxValue: (raw['numberMaxValue'] as num?)?.toDouble(),
          numberAllowDecimals: raw['numberAllowDecimals'] as bool? ?? true,
          numberIntegerOnly: raw['numberIntegerOnly'] as bool? ?? false,
          numberPositiveOnly: raw['numberPositiveOnly'] as bool? ?? false,
          numberShowStepper: raw['numberShowStepper'] as bool? ?? false,
          numberStepValue: (raw['numberStepValue'] as num?)?.toDouble() ?? 1,
        );
      })
      .toList(growable: false);

  final TableLayoutType storedLayout =
      TableLayoutType.fromStorage(model.layoutType);
  final bool swipe =
      model.swipeToDelete || storedLayout == TableLayoutType.swipe;
  final TableKind kind = TableKind.fromStorage(model.tableKind);
  final TableSummaryConfig? summary =
      model.summaryConfig == null || model.summaryConfig!.isEmpty
          ? null
          : TableSummaryConfig.tryFromJson(model.summaryConfig);
  final TableInventoryDeductionConfig? inventory =
      model.inventoryDeduction == null || model.inventoryDeduction!.isEmpty
          ? null
          : TableInventoryDeductionConfig.tryFromJson(
            model.inventoryDeduction,
          );
  final List<TableAffectingConfig> affectingTables =
      (model.affectingTables ?? const <Map<String, dynamic>>[])
          .map(
            (Map<String, dynamic> raw) =>
                TableAffectingConfig.tryFromJson(raw),
          )
          .whereType<TableAffectingConfig>()
          .toList(growable: false);
  final List<TableValidationRule> validationRules =
      (model.validationRules ?? const <Map<String, dynamic>>[])
          .map(
            (Map<String, dynamic> raw) => TableValidationRule.tryFromJson(raw),
          )
          .whereType<TableValidationRule>()
          .toList(growable: false);
  return TableSchemaEntity(
    id: model.id,
    pageId: model.pageId,
    name: model.name,
    description: model.description,
    mode: TableMode.fromStorage(model.mode),
    layoutType: swipe ? TableLayoutType.swipe : TableLayoutType.vertical,
    listDesignLayout: TableListDesignLayout.fromStorage(
      model.listDesignLayout,
    ),
    swipeToDelete: swipe,
    productDisplayMode: ProductDisplayMode.fromStorage(
      model.productDisplayMode,
    ),
    tableKind: kind,
    summaryConfig: summary,
    inventoryDeduction: inventory,
    affectingTables: affectingTables,
    validationRules: validationRules,
    searchEnabled: model.searchEnabled,
    dataLoadingMode: TableDataLoadingMode.fromStorage(model.dataLoadingMode),
    pageSize: model.pageSize,
    lazyInitialLoad: model.lazyInitialLoad,
    columns: cols,
  );
}
