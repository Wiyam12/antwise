import 'package:antwise/data/datasources/table_schema_local_datasource.dart';
import 'package:antwise/data/mappers/table_schema_entity_from_hive.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:antwise/domain/entities/table_affecting_config.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_layout_type.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/entities/table_validation_rule.dart';
import 'package:antwise/domain/repositories/table_schema_repository.dart';

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
    return tableSchemaEntityFromHive(model);
  }

  TableSchemaHiveModel _toHive(TableSchemaEntity schema) {
    final List<Map<String, dynamic>> columns = schema.columns
        .map<Map<String, dynamic>>(
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
            'dateDefaultToday': c.dateDefaultToday,
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
          .map<Map<String, dynamic>>(
            (TableAffectingConfig config) => config.toJson(),
          )
          .toList(growable: false),
      validationRules: schema.validationRules
          .map<Map<String, dynamic>>(
            (TableValidationRule rule) => rule.toJson(),
          )
          .toList(growable: false),
      searchEnabled: schema.searchEnabled,
      dataLoadingMode: schema.dataLoadingMode.storageValue,
      pageSize: schema.pageSize,
      lazyInitialLoad: schema.lazyInitialLoad,
      columns: columns,
    );
  }
}
