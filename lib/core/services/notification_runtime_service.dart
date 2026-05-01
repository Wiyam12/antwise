import 'dart:async';
import 'dart:convert';

import 'package:antwise/core/services/notification_dispatcher_service.dart';
import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/models/hive/app_settings_hive_model.dart';
import 'package:antwise/data/models/hive/table_row_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const String _kNotificationCheckTask = 'antwise.notification.check';

@pragma('vm:entry-point')
void notificationBackgroundDispatcher() {
  Workmanager().executeTask((
    String task,
    Map<String, dynamic>? inputData,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    final HiveService hiveService = HiveService();
    await hiveService.init();
    await NotificationRuntimeService.ensureInitialized();
    await NotificationRuntimeService.evaluateRulesAndNotify();
    return Future<bool>.value(true);
  });
}

class NotificationRuntimeService {
  NotificationRuntimeService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const String _settingsKey = 'app_settings';
  static const String _channelId = 'workspace_alerts';
  static const String _channelName = 'Workspace Alerts';
  static const String _channelDescription =
      'Rule based workspace notifications';
  static final RegExp _placeholderPattern = RegExp(r'<([^<>]+)>');

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );
    await _plugin.initialize(settings);
    final AndroidFlutterLocalNotificationsPlugin? androidPlatform =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlatform?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    _initialized = true;
  }

  /// Strict gating: only call this when user explicitly tries
  /// to create notification rules.
  static Future<bool> ensurePermissionGranted() async {
    await ensureInitialized();

    final AndroidFlutterLocalNotificationsPlugin? androidPlatform =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlatform != null) {
      final bool enabled =
          await androidPlatform.areNotificationsEnabled() ?? false;
      if (enabled) {
        return true;
      }
      final bool granted =
          await androidPlatform.requestNotificationsPermission() ?? false;
      return granted;
    }

    final IOSFlutterLocalNotificationsPlugin? iosPlatform =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    if (iosPlatform != null) {
      final bool granted =
          await iosPlatform.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }

    return false;
  }

  static Future<void> setupBackgroundChecks() async {
    await Workmanager().initialize(notificationBackgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      'antwise-notification-check',
      _kNotificationCheckTask,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 1),
    );
  }

  static Future<int> evaluateRulesForRowChange({
    required String tableId,
    required String rowId,
  }) async {
    await ensureInitialized();
    return evaluateRulesAndNotify(changedTableId: tableId, changedRowId: rowId);
  }

  static Future<int> evaluateRulesAndNotify({
    String? changedTableId,
    String? changedRowId,
    String? targetRuleId,
  }) async {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return 0;
    }
    final Box<AppSettingsHiveModel> settingsBox =
        Hive.box<AppSettingsHiveModel>(HiveBoxes.settingsBox);
    final AppSettingsHiveModel? settings = settingsBox.get(_settingsKey);
    if (settings == null) {
      return 0;
    }
    final String activeAccount = settings.activeAccountName.trim();
    if (activeAccount.isEmpty) {
      return 0;
    }
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      settings.accountWorkspaces,
    );
    final Map<String, dynamic> workspace = _asStringDynamicMap(
      workspaces[activeAccount],
    );
    final List<Map<String, dynamic>> rules = _asMapList(
      workspace['notifications'],
    );
    print(
      '[NotificationRuntime] evaluate start account=$activeAccount '
      'rules=${rules.length} changedTableId=${changedTableId ?? '-'} '
      'changedRowId=${changedRowId ?? '-'} targetRuleId=${targetRuleId ?? '-'}',
    );
    if (rules.isEmpty) {
      print('[NotificationRuntime] skip: no notification rules configured');
      return 0;
    }

    final Box<TableSchemaHiveModel> tableBox = Hive.box<TableSchemaHiveModel>(
      HiveBoxes.tablesBox,
    );
    final Box<TableRowHiveModel> rowBox = Hive.box<TableRowHiveModel>(
      HiveBoxes.rowsBox,
    );
    final Map<String, TableSchemaHiveModel> tableById =
        <String, TableSchemaHiveModel>{
          for (final TableSchemaHiveModel schema in tableBox.values)
            schema.id: schema,
        };
    final Map<String, TableSchemaHiveModel> tableByName =
        <String, TableSchemaHiveModel>{
          for (final TableSchemaHiveModel schema in tableBox.values)
            schema.name.trim().toLowerCase(): schema,
        };
    final Map<String, List<TableRowHiveModel>> rowsByTableId =
        <String, List<TableRowHiveModel>>{};
    for (final TableRowHiveModel row in rowBox.values) {
      rowsByTableId
          .putIfAbsent(row.tableId, () => <TableRowHiveModel>[])
          .add(row);
    }
    final DateTime now = DateTime.now();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String triggerStateKey = 'notification_trigger_state_$activeAccount';
    final Map<String, Map<String, dynamic>> triggerState = _readTriggerState(
      prefs.getString(triggerStateKey),
    );
    int triggeredCount = 0;

    for (int index = 0; index < rules.length; index++) {
      final Map<String, dynamic> rule = rules[index];
      final String ruleId =
          (rule['ruleId'] ?? '').toString().trim().isEmpty
              ? 'rule_index_$index'
              : (rule['ruleId'] ?? '').toString().trim();
      print('[NotificationRuntime] evaluating ruleId=$ruleId index=$index');
      if (targetRuleId != null &&
          targetRuleId.isNotEmpty &&
          targetRuleId != ruleId) {
        print(
          '[NotificationRuntime] skip ruleId=$ruleId reason=target_rule_filter',
        );
        continue;
      }
      if (rule['enabled'] != true) {
        print('[NotificationRuntime] skip ruleId=$ruleId reason=disabled');
        continue;
      }
      final String tableId = (rule['tableId'] ?? '').toString();
      final String columnId = (rule['columnId'] ?? '').toString();
      if (tableId.isEmpty || columnId.isEmpty) {
        print(
          '[NotificationRuntime] skip ruleId=$ruleId reason=missing_table_or_column',
        );
        continue;
      }
      if (changedTableId != null &&
          changedTableId.isNotEmpty &&
          tableId != changedTableId) {
        print(
          '[NotificationRuntime] skip ruleId=$ruleId reason=changed_table_filter',
        );
        continue;
      }
      final TableSchemaHiveModel? schema = tableById[tableId];
      if (schema == null) {
        print(
          '[NotificationRuntime] skip ruleId=$ruleId reason=schema_not_found',
        );
        continue;
      }
      final List<TableRowHiveModel> rows =
          rowsByTableId[tableId] ?? <TableRowHiveModel>[];
      if (rows.isEmpty) {
        print('[NotificationRuntime] skip ruleId=$ruleId reason=no_rows');
        continue;
      }
      final String title =
          (rule['title'] ?? '').toString().trim().isEmpty
              ? 'Workspace Notification'
              : (rule['title'] ?? '').toString().trim();
      final String configuredMessage =
          (rule['message'] ?? '').toString().trim();
      final String severity = (rule['severity'] ?? 'info').toString();
      final String conditionFamily =
          (rule['conditionFamily'] ?? 'date').toString();

      if (conditionFamily == 'date') {
        final String dateCondition =
            (rule['dateCondition'] ?? 'today').toString();
        final int withinValue =
            (rule['withinValue'] as num?)?.toInt() ??
            int.tryParse((rule['withinValue'] ?? '0').toString()) ??
            0;
        final String withinUnit = (rule['withinUnit'] ?? 'weeks').toString();
        final List<
          ({
            TableRowHiveModel row,
            String triggerIdentity,
            String currentTriggerKey,
            String body,
          })
        >
        pendingDateTriggers =
            <
              ({
                TableRowHiveModel row,
                String triggerIdentity,
                String currentTriggerKey,
                String body,
              })
            >[];
        for (final TableRowHiveModel row in rows) {
          if (changedRowId != null &&
              changedRowId.isNotEmpty &&
              row.id != changedRowId) {
            print(
              '[NotificationRuntime] skip ruleId=$ruleId row=${row.id} '
              'reason=changed_row_filter',
            );
            continue;
          }
          final DateTime? rowDate = DateTime.tryParse(
            (row.values[columnId] ?? '').toString().trim(),
          );
          if (rowDate == null) {
            print(
              '[NotificationRuntime] skip ruleId=$ruleId row=${row.id} '
              'reason=invalid_date',
            );
            continue;
          }
          final bool matched = _matchesDateCondition(
            now: now,
            rowDate: rowDate,
            condition: dateCondition,
            withinValue: withinValue,
            withinUnit: withinUnit,
          );
          if (!matched) {
            print(
              '[NotificationRuntime] skip ruleId=$ruleId row=${row.id} '
              'reason=condition_not_matched',
            );
            continue;
          }
          final String rowDateFingerprint =
              '${rowDate.year}-${rowDate.month}-${rowDate.day}';
          final String triggerIdentity = 'rule:$ruleId|row:${row.id}';
          final String currentTriggerKey =
              '$triggerIdentity|condition:$dateCondition|value:$rowDateFingerprint|within:$withinValue|unit:$withinUnit';
          final Map<String, dynamic>? lastState = triggerState[triggerIdentity];
          if ((lastState?['lastTriggeredKey'] ?? '').toString() ==
              currentTriggerKey) {
            print(
              '[NotificationRuntime] skip ruleId=$ruleId row=${row.id} '
              'reason=duplicate_trigger_key',
            );
            continue;
          }
          final String body =
              configuredMessage.isEmpty
                  ? 'Date condition met for ${schema.name}.'
                  : _resolveRuntimeMessage(
                    messageTemplate: configuredMessage,
                    fallbackSchema: schema,
                    fallbackRow: row,
                    tableByName: tableByName,
                    rowsByTableId: rowsByTableId,
                  );
          pendingDateTriggers.add((
            row: row,
            triggerIdentity: triggerIdentity,
            currentTriggerKey: currentTriggerKey,
            body: body,
          ));
        }
        if (pendingDateTriggers.isEmpty) {
          continue;
        }
        const int maxIndividualNotifications = 3;
        final int individualCount =
            pendingDateTriggers.length > maxIndividualNotifications
                ? maxIndividualNotifications
                : pendingDateTriggers.length;
        for (int i = 0; i < individualCount; i++) {
          final ({
            TableRowHiveModel row,
            String triggerIdentity,
            String currentTriggerKey,
            String body,
          })
          item = pendingDateTriggers[i];
          await _showNotification(
            id: item.currentTriggerKey.hashCode,
            title: title,
            body: item.body,
            severity: severity,
          );
          print(
            '[NotificationRuntime] trigger ruleId=$ruleId row=${item.row.id} '
            'type=date key=${item.currentTriggerKey}',
          );
          triggeredCount++;
          triggerState[item.triggerIdentity] = <String, dynamic>{
            'lastTriggeredKey': item.currentTriggerKey,
            'lastTriggeredAt': now.toIso8601String(),
          };
        }
        for (int i = individualCount; i < pendingDateTriggers.length; i++) {
          final ({
            TableRowHiveModel row,
            String triggerIdentity,
            String currentTriggerKey,
            String body,
          })
          item = pendingDateTriggers[i];
          triggerState[item.triggerIdentity] = <String, dynamic>{
            'lastTriggeredKey': item.currentTriggerKey,
            'lastTriggeredAt': now.toIso8601String(),
          };
        }
        final int remainingCount = pendingDateTriggers.length - individualCount;
        if (remainingCount > 0) {
          final String summaryIdentity =
              'rule:$ruleId|table:$tableId|summary:date';
          final String summaryDay = '${now.year}-${now.month}-${now.day}';
          final String summaryTriggerKey =
              '$summaryIdentity|condition:$dateCondition|within:$withinValue|unit:$withinUnit|remaining:$remainingCount|day:$summaryDay';
          final Map<String, dynamic>? lastSummaryState =
              triggerState[summaryIdentity];
          if ((lastSummaryState?['lastTriggeredKey'] ?? '').toString() !=
              summaryTriggerKey) {
            final String summaryBody = switch (dateCondition) {
              'today' =>
                '$remainingCount more ${schema.name} item(s) are due today.',
              'within' =>
                '$remainingCount more ${schema.name} item(s) are within $withinValue $withinUnit.',
              'before' =>
                '$remainingCount more ${schema.name} item(s) are before today.',
              'after' =>
                '$remainingCount more ${schema.name} item(s) are after today.',
              _ =>
                '$remainingCount more ${schema.name} item(s) matched this notification.',
            };
            await _showNotification(
              id: summaryTriggerKey.hashCode,
              title: '$title (Summary)',
              body: summaryBody,
              severity: severity,
            );
            print(
              '[NotificationRuntime] trigger ruleId=$ruleId type=date-summary '
              'key=$summaryTriggerKey',
            );
            triggeredCount++;
            triggerState[summaryIdentity] = <String, dynamic>{
              'lastTriggeredKey': summaryTriggerKey,
              'lastTriggeredAt': now.toIso8601String(),
            };
          }
        }
        continue;
      }

      final String scope = (rule['scope'] ?? 'daily').toString();
      final String numericCondition =
          (rule['numericCondition'] ?? 'gt').toString();
      final double threshold =
          double.tryParse((rule['threshold'] ?? '').toString().trim()) ?? 0;
      final String? dateColumnId = _firstDateColumnId(schema.columns);
      double aggregate = 0;
      int matchedRows = 0;
      for (final TableRowHiveModel row in rows) {
        if (dateColumnId != null) {
          final DateTime? rowDate = DateTime.tryParse(
            (row.values[dateColumnId] ?? '').toString().trim(),
          );
          if (rowDate == null ||
              !_dateIsInScope(now: now, rowDate: rowDate, scope: scope)) {
            continue;
          }
        }
        final double? value = double.tryParse(
          (row.values[columnId] ?? '').toString().trim(),
        );
        if (value == null) {
          continue;
        }
        aggregate += value;
        matchedRows++;
      }
      if (matchedRows == 0) {
        print(
          '[NotificationRuntime] skip ruleId=$ruleId reason=no_numeric_rows',
        );
        continue;
      }
      final bool matched = switch (numericCondition) {
        'lt' => aggregate < threshold,
        'eq' => aggregate == threshold,
        'quota' => aggregate >= threshold,
        _ => aggregate > threshold,
      };
      if (!matched) {
        print(
          '[NotificationRuntime] skip ruleId=$ruleId reason=numeric_not_matched '
          'aggregate=$aggregate threshold=$threshold condition=$numericCondition',
        );
        continue;
      }
      final String scopeBucket = _scopeBucket(now, scope);
      final String triggerIdentity =
          'rule:$ruleId|table:$tableId|scope:$scope|bucket:$scopeBucket';
      final String currentTriggerKey =
          '$triggerIdentity|condition:$numericCondition|threshold:$threshold|aggregate:${aggregate.toStringAsFixed(4)}|rows:$matchedRows';
      final Map<String, dynamic>? lastState = triggerState[triggerIdentity];
      if ((lastState?['lastTriggeredKey'] ?? '').toString() ==
          currentTriggerKey) {
        print(
          '[NotificationRuntime] skip ruleId=$ruleId reason=duplicate_trigger_key',
        );
        continue;
      }
      final String body =
          configuredMessage.isEmpty
              ? '${schema.name} aggregate reached ${aggregate.toStringAsFixed(2)}.'
              : _resolveRuntimeMessage(
                messageTemplate: configuredMessage,
                fallbackSchema: schema,
                fallbackRow: rows.isEmpty ? null : rows.first,
                tableByName: tableByName,
                rowsByTableId: rowsByTableId,
              );
      await _showNotification(
        id: currentTriggerKey.hashCode,
        title: title,
        body: body,
        severity: severity,
      );
      print(
        '[NotificationRuntime] trigger ruleId=$ruleId type=numeric '
        'key=$currentTriggerKey aggregate=$aggregate matchedRows=$matchedRows',
      );
      triggeredCount++;
      triggerState[triggerIdentity] = <String, dynamic>{
        'lastTriggeredKey': currentTriggerKey,
        'lastTriggeredAt': now.toIso8601String(),
      };
    }
    await prefs.setString(
      triggerStateKey,
      jsonEncode(_boundedTriggerState(triggerState, maxEntries: 1500)),
    );
    print(
      '[NotificationRuntime] evaluate done account=$activeAccount triggered=$triggeredCount',
    );
    return triggeredCount;
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String severity,
  }) async {
    final NotificationDisplayData data = NotificationDisplayData(
      id: id,
      title: title,
      body: body,
      severity: severity,
    );
    await NotificationDispatcherService.instance.dispatch(
      data: data,
      showSystemNotification: _showSystemNotification,
    );
  }

  static Future<void> _showSystemNotification(
    NotificationDisplayData data,
  ) async {
    final Importance importance = switch (data.severity) {
      'danger' => Importance.max,
      'warning' => Importance.high,
      _ => Importance.high,
    };
    final Priority priority = switch (data.severity) {
      'danger' => Priority.high,
      'warning' => Priority.high,
      _ => Priority.high,
    };
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: importance,
        priority: priority,
      ),
      iOS: const DarwinNotificationDetails(
        presentBanner: true,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    print(
      '[NotificationRuntime] show request id=${data.id} severity=${data.severity} '
      'importance=$importance priority=$priority title="${data.title}"',
    );
    try {
      await _plugin.show(data.id, data.title, data.body, details);
      print('[NotificationRuntime] show success id=${data.id}');
    } catch (e, st) {
      print('[NotificationRuntime] show failed id=${data.id} error=$e');
      print(st);
    }
  }

  static String _resolveRuntimeMessage({
    required String messageTemplate,
    required TableSchemaHiveModel fallbackSchema,
    required TableRowHiveModel? fallbackRow,
    required Map<String, TableSchemaHiveModel> tableByName,
    required Map<String, List<TableRowHiveModel>> rowsByTableId,
  }) {
    if (messageTemplate.isEmpty) {
      return messageTemplate;
    }
    return messageTemplate.replaceAllMapped(_placeholderPattern, (Match match) {
      final String inside = (match.group(1) ?? '').trim();
      if (inside.isEmpty) {
        return '[N/A]';
      }
      String? tableName;
      String columnName = inside;
      final int dotIndex = inside.indexOf('.');
      if (dotIndex > 0 && dotIndex < inside.length - 1) {
        tableName = inside.substring(0, dotIndex).trim();
        columnName = inside.substring(dotIndex + 1).trim();
      }
      if (columnName.isEmpty) {
        return '[N/A]';
      }
      final TableSchemaHiveModel? schema =
          tableName == null || tableName.isEmpty
              ? fallbackSchema
              : tableByName[tableName.toLowerCase()];
      if (schema == null) {
        return '[N/A]';
      }
      String? columnId;
      for (final Map<String, dynamic> column in schema.columns) {
        final String name =
            (column['name'] ?? '').toString().trim().toLowerCase();
        if (name == columnName.toLowerCase()) {
          columnId = (column['id'] ?? '').toString();
          break;
        }
      }
      if (columnId == null || columnId.isEmpty) {
        return '[N/A]';
      }
      final TableRowHiveModel? row =
          schema.id == fallbackSchema.id
              ? fallbackRow
              : (() {
                final List<TableRowHiveModel> candidates =
                    rowsByTableId[schema.id] ?? const <TableRowHiveModel>[];
                return candidates.isEmpty ? null : candidates.first;
              })();
      if (row == null) {
        return '[N/A]';
      }
      final String value = (row.values[columnId] ?? '').toString().trim();
      return value.isEmpty ? '[N/A]' : value;
    });
  }

  static Map<String, Map<String, dynamic>> _readTriggerState(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, dynamic>>{};
    }
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, Map<String, dynamic>>{};
    }
    final Map<String, Map<String, dynamic>> out =
        <String, Map<String, dynamic>>{};
    for (final MapEntry<dynamic, dynamic> entry in decoded.entries) {
      final String key = entry.key.toString();
      if (key.isEmpty) {
        continue;
      }
      final Map<String, dynamic> value = _asStringDynamicMap(entry.value);
      out[key] = value;
    }
    return out;
  }

  static Map<String, dynamic> _boundedTriggerState(
    Map<String, Map<String, dynamic>> triggerState, {
    required int maxEntries,
  }) {
    if (triggerState.length <= maxEntries) {
      return <String, dynamic>{
        for (final MapEntry<String, Map<String, dynamic>> entry
            in triggerState.entries)
          entry.key: entry.value,
      };
    }
    final List<MapEntry<String, Map<String, dynamic>>> entries = triggerState
        .entries
        .toList(growable: false);
    entries.sort((
      MapEntry<String, Map<String, dynamic>> a,
      MapEntry<String, Map<String, dynamic>> b,
    ) {
      final String aTs = (a.value['lastTriggeredAt'] ?? '').toString();
      final String bTs = (b.value['lastTriggeredAt'] ?? '').toString();
      return aTs.compareTo(bTs);
    });
    final int dropCount = entries.length - maxEntries;
    final Iterable<MapEntry<String, Map<String, dynamic>>> kept = entries.skip(
      dropCount,
    );
    return <String, dynamic>{
      for (final MapEntry<String, Map<String, dynamic>> entry in kept)
        entry.key: entry.value,
    };
  }
}

bool _matchesDateCondition({
  required DateTime now,
  required DateTime rowDate,
  required String condition,
  required int withinValue,
  required String withinUnit,
}) {
  final DateTime nowOnly = DateTime(now.year, now.month, now.day);
  final DateTime rowOnly = DateTime(rowDate.year, rowDate.month, rowDate.day);
  switch (condition) {
    case 'within':
      final int span = withinValue <= 0 ? 0 : withinValue;
      final Duration unit =
          withinUnit == 'days'
              ? Duration(days: span)
              : Duration(days: span * 7);
      final DateTime maxDate = nowOnly.add(unit);
      return (rowOnly.isAfter(nowOnly) || rowOnly == nowOnly) &&
          (rowOnly.isBefore(maxDate) || rowOnly == maxDate);
    case 'before':
      return rowOnly.isBefore(nowOnly);
    case 'after':
      return rowOnly.isAfter(nowOnly);
    case 'today':
    default:
      return rowOnly == nowOnly;
  }
}

bool _dateIsInScope({
  required DateTime now,
  required DateTime rowDate,
  required String scope,
}) {
  final DateTime n = DateTime(now.year, now.month, now.day);
  final DateTime r = DateTime(rowDate.year, rowDate.month, rowDate.day);
  switch (scope) {
    case 'weekly':
      final int nowWeekday = n.weekday;
      final DateTime startOfWeek = n.subtract(Duration(days: nowWeekday - 1));
      final DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
      return (r.isAfter(startOfWeek) || r == startOfWeek) &&
          (r.isBefore(endOfWeek) || r == endOfWeek);
    case 'monthly':
      return r.year == n.year && r.month == n.month;
    case 'daily':
    default:
      return r == n;
  }
}

String _scopeBucket(DateTime now, String scope) {
  switch (scope) {
    case 'weekly':
      final int week = ((now.day - 1) ~/ 7) + 1;
      return '${now.year}-${now.month}-w$week';
    case 'monthly':
      return '${now.year}-${now.month}';
    case 'daily':
    default:
      return '${now.year}-${now.month}-${now.day}';
  }
}

String? _firstDateColumnId(List<Map<String, dynamic>> columns) {
  for (final Map<String, dynamic> col in columns) {
    if ((col['type'] ?? '').toString() == 'date') {
      final String id = (col['id'] ?? '').toString();
      if (id.isNotEmpty) {
        return id;
      }
    }
  }
  return null;
}

Map<String, dynamic> _asStringDynamicMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map<String, dynamic>(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic raw) {
  if (raw is! List) {
    return const <Map<String, dynamic>>[];
  }
  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
  for (final dynamic item in raw) {
    if (item is Map<String, dynamic>) {
      out.add(item);
    } else if (item is Map) {
      out.add(
        item.map<String, dynamic>(
          (dynamic key, dynamic value) =>
              MapEntry<String, dynamic>(key.toString(), value),
        ),
      );
    }
  }
  return out;
}
