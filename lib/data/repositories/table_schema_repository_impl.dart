import 'package:antwise/data/datasources/table_schema_local_datasource.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/entities/table_column_dropdown_source.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_text_validation_kind.dart';
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
import 'package:antwise/domain/repositories/table_schema_repository.dart';

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

class TableSchemaRepositoryImpl implements TableSchemaRepository {
  TableSchemaRepositoryImpl(this._local);

  final TableSchemaLocalDataSource _local;

  @override
  Future<List<TableSchemaEntity>> getAll() async {
    final List<TableSchemaHiveModel> all = await _local.readAll();
    return all.map(_toEntity).toList(growable: false);
  }

  @override
  Future<TableSchemaEntity?> getById(String tableId) async {
    final List<TableSchemaEntity> all = await getAll();
    for (final TableSchemaEntity schema in all) {
      if (schema.id == tableId) {
        return schema;
      }
    }
    return null;
  }

  @override
  Future<TableSchemaEntity?> getByPageId(String pageId) async {
    final List<TableSchemaEntity> all = await getAll();
    for (final TableSchemaEntity schema in all) {
      if (schema.pageId == pageId) {
        return schema;
      }
    }
    return null;
  }

  @override
  Future<void> save(TableSchemaEntity schema) async {
    await _local.write(_toHive(schema));
  }

  @override
  Future<void> delete(String tableId) async {
    await _local.delete(tableId);
  }

  TableSchemaEntity _toEntity(TableSchemaHiveModel model) {
    final List<TableColumnEntity> cols = model.columns
        .map((Map<String, dynamic> raw) {
          final List<String> dropdown = ((raw['dropdownOptions'] as List?) ??
                  const <dynamic>[])
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

    final TableLayoutType storedLayout = TableLayoutType.fromStorage(
      model.layoutType,
    );
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
              (Map<String, dynamic> raw) => TableAffectingConfig.tryFromJson(raw),
            )
            .whereType<TableAffectingConfig>()
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
      searchEnabled: model.searchEnabled,
      dataLoadingMode: TableDataLoadingMode.fromStorage(model.dataLoadingMode),
      pageSize: model.pageSize,
      lazyInitialLoad: model.lazyInitialLoad,
      columns: cols,
    );
  }

  TableSchemaHiveModel _toHive(TableSchemaEntity schema) {
    final List<Map<String, dynamic>> columns = schema.columns
        .map(
          (TableColumnEntity c) => <String, dynamic>{
            'id': c.id,
            'name': c.name,
            'type': c.type.storageValue,
            'includeInCreateForm': c.includeInCreateForm,
            'includeInEditForm': c.includeInEditForm,
            'isRequired': c.isRequired,
            'isUnique': c.isUnique,
            'pattern': c.pattern,
            'formula': c.formula,
            'formulaDefinition': c.formulaDefinition,
            'dropdownOptions': c.dropdownOptions,
            'dropdownSourceKind': c.dropdownSourceKind.storageValue,
            'dropdownSourceTableId': c.dropdownSourceTableId,
            'dropdownSourceColumnId': c.dropdownSourceColumnId,
            'textFieldHint': c.textFieldHint,
            'textPrefixIconKey': c.textPrefixIconKey,
            'textSuffixIconKey': c.textSuffixIconKey,
            'textValidationKind': c.textValidationKind.storageValue,
            'textCustomRegex': c.textCustomRegex,
            'numberFieldHint': c.numberFieldHint,
            'numberPrefixText': c.numberPrefixText,
            'numberSuffixText': c.numberSuffixText,
            'numberPrefixIconKey': c.numberPrefixIconKey,
            'numberSuffixIconKey': c.numberSuffixIconKey,
            'numberMinValue': c.numberMinValue,
            'numberMaxValue': c.numberMaxValue,
            'numberAllowDecimals': c.numberAllowDecimals,
            'numberIntegerOnly': c.numberIntegerOnly,
            'numberPositiveOnly': c.numberPositiveOnly,
            'numberShowStepper': c.numberShowStepper,
            'numberStepValue': c.numberStepValue,
          },
        )
        .toList(growable: false);
    final bool swipe =
        schema.swipeToDelete || schema.layoutType == TableLayoutType.swipe;
    return TableSchemaHiveModel(
      id: schema.id,
      pageId: schema.pageId,
      name: schema.name,
      description: schema.description,
      mode: schema.mode.storageValue,
      layoutType: swipe ? 'swipe' : 'vertical',
      listDesignLayout: schema.listDesignLayout.storageValue,
      swipeToDelete: swipe,
      productDisplayMode: schema.productDisplayMode.storageValue,
      tableKind: schema.tableKind.storageValue,
      summaryConfig: schema.summaryConfig?.toJson(),
      inventoryDeduction: schema.inventoryDeduction?.toJson(),
      affectingTables: schema.affectingTables
          .map((TableAffectingConfig config) => config.toJson())
          .toList(growable: false),
      searchEnabled: schema.searchEnabled,
      dataLoadingMode: schema.dataLoadingMode.storageValue,
      pageSize: schema.pageSize,
      lazyInitialLoad: schema.lazyInitialLoad,
      columns: columns,
    );
  }
}
