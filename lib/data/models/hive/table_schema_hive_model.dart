import 'package:hive/hive.dart';

class TableSchemaHiveModel {
  TableSchemaHiveModel({
    required this.id,
    required this.pageId,
    required this.name,
    this.description = '',
    this.mode = 'crud',
    this.layoutType = 'vertical',
    this.listDesignLayout = 'standard',
    this.swipeToDelete = false,
    this.productDisplayMode = 'list',
    this.tableKind = 'standard',
    this.summaryConfig,
    this.inventoryDeduction,
    this.searchEnabled = false,
    this.dataLoadingMode = 'lazy',
    this.pageSize = 10,
    this.lazyInitialLoad = 5,
    required this.columns,
  });

  final String id;
  final String pageId;
  final String name;
  final String description;
  final String mode;
  final String layoutType;
  final String listDesignLayout;
  final bool swipeToDelete;
  final String productDisplayMode;
  final String tableKind;
  final Map<String, dynamic>? summaryConfig;
  final Map<String, dynamic>? inventoryDeduction;
  final bool searchEnabled;
  final String dataLoadingMode;
  final int pageSize;
  final int lazyInitialLoad;
  final List<Map<String, dynamic>> columns;
}

class TableSchemaHiveModelAdapter extends TypeAdapter<TableSchemaHiveModel> {
  @override
  final int typeId = 4;

  @override
  TableSchemaHiveModel read(BinaryReader reader) {
    final int fieldCount = reader.readByte();
    final Map<int, dynamic> data = <int, dynamic>{};
    for (int i = 0; i < fieldCount; i++) {
      data[reader.readByte()] = reader.read();
    }
    final dynamic rawDescription = data[3];
    final String description = rawDescription is String ? rawDescription : '';

    final dynamic rawMode = data[4];
    final String mode = rawMode is String ? rawMode : 'crud';

    final dynamic rawLayoutType = data[5];
    final String layoutType =
        rawLayoutType is String ? rawLayoutType : 'vertical';

    final dynamic rawColumns = data[6];
    final List<Map<String, dynamic>> columns = <Map<String, dynamic>>[];
    if (rawColumns is List) {
      for (final dynamic item in rawColumns) {
        if (item is Map) {
          columns.add(item.cast<String, dynamic>());
        }
      }
    }

    String listDesignLayout = 'standard';
    if (data.containsKey(7) && data[7] is String) {
      listDesignLayout = data[7]! as String;
    }

    bool swipeToDelete = layoutType == 'swipe';
    if (data.containsKey(8)) {
      swipeToDelete = data[8] == true;
    }

    String productDisplayMode = 'list';
    if (data.containsKey(9) && data[9] is String) {
      productDisplayMode = data[9]! as String;
    }

    String tableKind = 'standard';
    if (data.containsKey(10) && data[10] is String) {
      tableKind = data[10]! as String;
    }

    Map<String, dynamic>? summaryConfig;
    if (data.containsKey(11) && data[11] is Map) {
      summaryConfig = (data[11]! as Map).cast<String, dynamic>();
    }

    Map<String, dynamic>? inventoryDeduction;
    if (data.containsKey(12) && data[12] is Map) {
      inventoryDeduction = (data[12]! as Map).cast<String, dynamic>();
    }

    final bool searchEnabled = data[13] == true;
    final String dataLoadingMode =
        (data[14] is String ? data[14] as String : 'lazy');
    final int pageSize = (data[15] as num?)?.toInt() ?? 10;
    final int lazyInitialLoad = (data[16] as num?)?.toInt() ?? 5;

    return TableSchemaHiveModel(
      id: (data[0] ?? '').toString(),
      pageId: (data[1] ?? '').toString(),
      name: (data[2] ?? '').toString(),
      description: description,
      mode: mode,
      layoutType: layoutType,
      listDesignLayout: listDesignLayout,
      swipeToDelete: swipeToDelete,
      productDisplayMode: productDisplayMode,
      tableKind: tableKind,
      summaryConfig: summaryConfig,
      inventoryDeduction: inventoryDeduction,
      searchEnabled: searchEnabled,
      dataLoadingMode: dataLoadingMode,
      pageSize: pageSize,
      lazyInitialLoad: lazyInitialLoad,
      columns: columns,
    );
  }

  @override
  void write(BinaryWriter writer, TableSchemaHiveModel obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.pageId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.mode)
      ..writeByte(5)
      ..write(obj.layoutType)
      ..writeByte(6)
      ..write(obj.columns)
      ..writeByte(7)
      ..write(obj.listDesignLayout)
      ..writeByte(8)
      ..write(obj.swipeToDelete)
      ..writeByte(9)
      ..write(obj.productDisplayMode)
      ..writeByte(10)
      ..write(obj.tableKind)
      ..writeByte(11)
      ..write(obj.summaryConfig ?? <String, dynamic>{})
      ..writeByte(12)
      ..write(obj.inventoryDeduction ?? <String, dynamic>{})
      ..writeByte(13)
      ..write(obj.searchEnabled)
      ..writeByte(14)
      ..write(obj.dataLoadingMode)
      ..writeByte(15)
      ..write(obj.pageSize)
      ..writeByte(16)
      ..write(obj.lazyInitialLoad);
  }
}
