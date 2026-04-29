import 'package:antwise/domain/entities/product_display_mode.dart';
import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_data_loading_mode.dart';
import 'package:antwise/domain/entities/table_affecting_config.dart';
import 'package:antwise/domain/entities/table_kind.dart';
import 'package:antwise/domain/entities/table_layout_type.dart';
import 'package:antwise/domain/entities/table_list_design_layout.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_inventory_deduction_config.dart';
import 'package:antwise/domain/entities/table_summary_config.dart';
import 'package:antwise/domain/entities/table_validation_rule.dart';

class TableSchemaEntity {
  const TableSchemaEntity({
    required this.id,
    required this.pageId,
    required this.name,
    required this.description,
    required this.mode,
    this.layoutType = TableLayoutType.vertical,
    this.listDesignLayout = TableListDesignLayout.standard,
    this.swipeToDelete = false,
    this.productDisplayMode = ProductDisplayMode.list,
    this.tableKind = TableKind.standard,
    this.summaryConfig,
    this.inventoryDeduction,
    this.affectingTables = const <TableAffectingConfig>[],
    this.validationRules = const <TableValidationRule>[],
    this.searchEnabled = false,
    this.dataLoadingMode = TableDataLoadingMode.lazy,
    this.pageSize = 10,
    this.lazyInitialLoad = 5,
    required this.columns,
  });

  final String id;
  final String pageId;
  final String name;
  final String description;
  final TableMode mode;

  /// Row delete UX: vertical (icon delete) vs swipe dismiss.
  final TableLayoutType layoutType;

  /// List/card design preset: contact, product, or free-form standard.
  final TableListDesignLayout listDesignLayout;
  final bool swipeToDelete;

  /// Only used when [listDesignLayout] is [TableListDesignLayout.product].
  final ProductDisplayMode productDisplayMode;

  /// Normal data table vs aggregated summary view.
  final TableKind tableKind;

  /// When [tableKind] is [TableKind.summary], defines source data and aggregation.
  final TableSummaryConfig? summaryConfig;

  /// Optional: after a **new** row is saved, decrement stock on [stockTableId].
  final TableInventoryDeductionConfig? inventoryDeduction;

  /// Optional CRUD side effects to apply on other tables by row matching.
  final List<TableAffectingConfig> affectingTables;

  /// Optional pre-save rules evaluated before creating/updating table rows.
  final List<TableValidationRule> validationRules;

  /// Optional search box visibility for runtime table view.
  final bool searchEnabled;

  /// Runtime data loading style: lazy-load or pagination.
  final TableDataLoadingMode dataLoadingMode;

  /// Page size used by pagination mode.
  final int pageSize;

  /// First batch size used by lazy mode.
  final int lazyInitialLoad;

  final List<TableColumnEntity> columns;
}
