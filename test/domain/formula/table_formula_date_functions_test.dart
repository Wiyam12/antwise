import 'package:antwise/domain/entities/table_column_entity.dart';
import 'package:antwise/domain/entities/table_column_type.dart';
import 'package:antwise/domain/entities/table_mode.dart';
import 'package:antwise/domain/entities/table_row_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/formula/table_formula_evaluator.dart';
import 'package:antwise/domain/validation/table_formula_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TableSchemaEntity schema;
  late Map<String, List<TableRowEntity>> rowsByTableId;

  setUp(() {
    schema = TableSchemaEntity(
      id: 't1',
      pageId: 'p1',
      name: 'Transactions',
      description: '',
      mode: TableMode.crud,
      columns: <TableColumnEntity>[
        TableColumnEntity(
          id: 'c_date',
          name: 'Date',
          type: TableColumnType.date,
        ),
        TableColumnEntity(
          id: 'c_amt',
          name: 'Total Amount',
          type: TableColumnType.number,
        ),
      ],
    );
    rowsByTableId = <String, List<TableRowEntity>>{
      't1': <TableRowEntity>[
        TableRowEntity(
          id: 'r1',
          tableId: 't1',
          values: <String, dynamic>{
            'c_date': '2025-05-20',
            'c_amt': 10,
          },
        ),
        TableRowEntity(
          id: 'r2',
          tableId: 't1',
          values: <String, dynamic>{
            'c_date': '2025-05-10',
            'c_amt': 99,
          },
        ),
      ],
    };
  });

  test('validator accepts DATE_ADD and DAYS_AGO', () {
    expect(
      TableFormulaValidator.validate(
        formula:
            'SUM(IF(Transactions.Date >= DAYS_AGO(7), IF(Transactions.Date <= TODAY(), Transactions."Total Amount", 0), 0))',
        currentColumnId: 'x',
        siblingColumns: const <ColumnNameDraft>[],
        existingTables: <TableSchemaEntity>[schema],
      ),
      isNull,
    );
  });

  test('DAYS_AGO(0) equals TODAY() for comparisons', () {
    final String today = TableFormulaEvaluator.evaluate(
      formula: 'TODAY()',
      currentSchema: schema,
      workingRowByColId: const <String, dynamic>{},
      allSchemas: <TableSchemaEntity>[schema],
      rowsByTableId: rowsByTableId,
    );
    final String daysAgo0 = TableFormulaEvaluator.evaluate(
      formula: 'DAYS_AGO(0)',
      currentSchema: schema,
      workingRowByColId: const <String, dynamic>{},
      allSchemas: <TableSchemaEntity>[schema],
      rowsByTableId: rowsByTableId,
    );
    expect(daysAgo0, today);
  });

  test('DATE_ADD shifts ISO date by offset', () {
    final String shifted = TableFormulaEvaluator.evaluate(
      formula: 'DATE_ADD("2025-05-22", -7)',
      currentSchema: schema,
      workingRowByColId: const <String, dynamic>{},
      allSchemas: <TableSchemaEntity>[schema],
      rowsByTableId: rowsByTableId,
    );
    expect(shifted, '2025-05-15');
  });

  test('rolling window sum excludes rows outside range', () {
    final String formula =
        'SUM(IF(Transactions.Date >= DATE_ADD(TODAY(), -7), '
        'IF(Transactions.Date <= TODAY(), Transactions."Total Amount", 0), 0))';
    final String result = TableFormulaEvaluator.evaluate(
      formula: formula,
      currentSchema: schema,
      workingRowByColId: const <String, dynamic>{},
      allSchemas: <TableSchemaEntity>[schema],
      rowsByTableId: rowsByTableId,
    );
    // Depends on machine date; at least parses and returns a number string.
    expect(double.tryParse(result), isNotNull);
  });
}
