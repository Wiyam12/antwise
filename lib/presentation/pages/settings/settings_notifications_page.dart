import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/core/services/notification_runtime_service.dart';
import 'package:antwise/data/models/hive/table_row_hive_model.dart';
import 'package:antwise/data/models/hive/app_settings_hive_model.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class SettingsNotificationsPage extends StatefulWidget {
  const SettingsNotificationsPage({super.key});

  @override
  State<SettingsNotificationsPage> createState() =>
      _SettingsNotificationsPageState();
}

class _SettingsNotificationsPageState extends State<SettingsNotificationsPage> {
  static const String _settingsKey = 'app_settings';

  String _activeAccountName = '';
  List<Map<String, dynamic>> _rules = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? settings = box.get(_settingsKey);
    final String active = settings?.activeAccountName.trim() ?? '';
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      settings?.accountWorkspaces,
    );
    final Map<String, dynamic> workspace = _asStringDynamicMap(
      workspaces[active],
    );
    final List<Map<String, dynamic>> rules = _asMapList(
      workspace['notifications'],
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _activeAccountName = active;
      _rules = rules;
    });
  }

  Future<void> _openRuleBuilder({int? editingIndex}) async {
    if (editingIndex == null) {
      final bool granted =
          await NotificationRuntimeService.ensurePermissionGranted();
      if (!granted) {
        Get.snackbar(
          'Notifications',
          'Notification permission is required to create notifications.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          borderRadius: 12,
          duration: const Duration(seconds: 3),
        );
        return;
      }
    }
    final Map<String, dynamic>? initialRule =
        editingIndex == null ? null : _rules[editingIndex];
    await Get.toNamed<void>(
      AppRoutes.settingsNotificationRule,
      arguments: <String, dynamic>{
        'activeAccountName': _activeAccountName,
        'initialRule': initialRule,
        'editingIndex': editingIndex,
      },
    );
    _loadRules();
  }

  Future<void> _deleteRuleAt(int index) async {
    if (index < 0 || index >= _rules.length) {
      return;
    }
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Delete notification?'),
              content: const Text(
                'This will permanently remove the notification rule.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ==
        true;
    if (!confirmed) {
      return;
    }
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? old = box.get(_settingsKey);
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      old?.accountWorkspaces,
    );
    final Map<String, dynamic> workspace = _asStringDynamicMap(
      workspaces[_activeAccountName],
    );
    final List<Map<String, dynamic>> notifications = _asMapList(
          workspace['notifications'],
        )
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: true);
    if (index >= 0 && index < notifications.length) {
      notifications.removeAt(index);
    }
    workspace['notifications'] = notifications;
    workspaces[_activeAccountName] = workspace;
    await box.put(
      _settingsKey,
      AppSettingsHiveModel(
        resourcesDownloaded: old?.resourcesDownloaded ?? false,
        themeMode: old?.themeMode ?? 'system',
        firstInstallCompleted: old?.firstInstallCompleted ?? false,
        themePresetName: old?.themePresetName ?? 'Ocean Blue',
        accountNames: old?.accountNames ?? const <String>[],
        activeAccountName: old?.activeAccountName ?? _activeAccountName,
        accountWorkspaces: workspaces,
      ),
    );
    _loadRules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rules.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, int index) {
          if (index == 0) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.add_alert_outlined),
                title: const Text('Create New Notification'),
                subtitle: const Text('Add a new rule-based notification'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openRuleBuilder(),
              ),
            );
          }
          final Map<String, dynamic> rule = _rules[index - 1];
          final String title = (rule['title'] ?? '').toString().trim();
          final String message = (rule['message'] ?? '').toString().trim();
          final String severity = (rule['severity'] ?? 'info').toString();
          final bool enabled = rule['enabled'] == true;
          final IconData severityIcon = switch (severity) {
            'danger' => Icons.warning_amber_rounded,
            'warning' => Icons.schedule_rounded,
            _ => Icons.info_outline_rounded,
          };
          final Color severityColor = switch (severity) {
            'danger' => Colors.red,
            'warning' => Colors.orange,
            _ => Colors.blue,
          };
          final int ruleIndex = index - 1;
          return Dismissible(
            key: ValueKey<String>('notification_rule_$ruleIndex'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              await _deleteRuleAt(ruleIndex);
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            child: Card(
              child: ListTile(
                leading: Icon(severityIcon, color: severityColor),
                title: Text(title.isEmpty ? 'Untitled notification' : title),
                subtitle: Text(
                  message.isEmpty ? 'No message configured' : message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      enabled ? Icons.toggle_on : Icons.toggle_off_outlined,
                      color: enabled ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _openRuleBuilder(editingIndex: ruleIndex),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SettingsNotificationRulePage extends StatefulWidget {
  const SettingsNotificationRulePage({super.key});

  @override
  State<SettingsNotificationRulePage> createState() =>
      _SettingsNotificationRulePageState();
}

class _SettingsNotificationRulePageState
    extends State<SettingsNotificationRulePage> {
  static const String _settingsKey = 'app_settings';
  static final RegExp _placeholderPattern = RegExp(r'<([^<>]+)>');

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController();
  final TextEditingController _withinController = TextEditingController(
    text: '7',
  );

  String _activeAccountName = '';
  int? _editingIndex;
  bool _enabled = true;
  String _conditionFamily = 'date';
  String _dateCondition = 'today';
  String _withinUnit = 'weeks';
  String _numericCondition = 'gt';
  String _scope = 'daily';
  String _severity = 'info';
  String _selectedTableId = '';
  String _selectedColumnId = '';

  List<TableSchemaEntity> _schemas = <TableSchemaEntity>[];
  Map<String, List<TableRowHiveModel>> _rowsByTableId =
      <String, List<TableRowHiveModel>>{};
  int? _placeholderStartOffset;
  String _placeholderQuery = '';

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? args =
        Get.arguments is Map<String, dynamic>
            ? Get.arguments as Map<String, dynamic>
            : null;
    _activeAccountName = (args?['activeAccountName'] ?? '').toString();
    _editingIndex = args?['editingIndex'] as int?;
    final Map<String, dynamic>? initialRule = _asNullableStringMap(
      args?['initialRule'],
    );
    _loadSchemas();
    _applyInitial(initialRule);
    _messageController.addListener(_updatePlaceholderAutocompleteState);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      // Deep-link / navigation bypass protection:
      // Creating a new rule requires permission.
      if (_editingIndex == null) {
        final bool granted =
            await NotificationRuntimeService.ensurePermissionGranted();
        if (!granted && mounted) {
          Get.snackbar(
            'Notifications',
            'Notification permission is required to create notifications.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderRadius: 12,
            duration: const Duration(seconds: 3),
          );
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_updatePlaceholderAutocompleteState);
    _titleController.dispose();
    _messageController.dispose();
    _thresholdController.dispose();
    _withinController.dispose();
    super.dispose();
  }

  void _updatePlaceholderAutocompleteState() {
    final TextSelection selection = _messageController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      if (_placeholderStartOffset != null || _placeholderQuery.isNotEmpty) {
        setState(() {
          _placeholderStartOffset = null;
          _placeholderQuery = '';
        });
      }
      return;
    }
    final int caret = selection.extentOffset;
    final String text = _messageController.text;
    if (caret < 0 || caret > text.length) {
      return;
    }
    final String before = text.substring(0, caret);
    final int lastOpen = before.lastIndexOf('<');
    if (lastOpen < 0) {
      if (_placeholderStartOffset != null || _placeholderQuery.isNotEmpty) {
        setState(() {
          _placeholderStartOffset = null;
          _placeholderQuery = '';
        });
      }
      return;
    }
    final int closeAfterOpen = before.lastIndexOf('>');
    if (closeAfterOpen > lastOpen) {
      if (_placeholderStartOffset != null || _placeholderQuery.isNotEmpty) {
        setState(() {
          _placeholderStartOffset = null;
          _placeholderQuery = '';
        });
      }
      return;
    }
    final String query = before.substring(lastOpen + 1);
    if (_placeholderStartOffset != lastOpen || _placeholderQuery != query) {
      setState(() {
        _placeholderStartOffset = lastOpen;
        _placeholderQuery = query;
      });
    }
  }

  List<({String label, String insertText})> _placeholderSuggestions() {
    final String query = _placeholderQuery.trim().toLowerCase();
    final List<({String label, String insertText})> out =
        <({String label, String insertText})>[];
    final Set<String> seen = <String>{};
    void addForSchema(TableSchemaEntity schema) {
      for (final dynamic column in schema.columns) {
        final String candidate = '${schema.name}.${column.name}'.trim();
        if (candidate.isEmpty) {
          continue;
        }
        final String normalized = candidate.toLowerCase();
        if (query.isNotEmpty && !normalized.contains(query)) {
          continue;
        }
        if (!seen.add(normalized)) {
          continue;
        }
        out.add((label: candidate, insertText: '<$candidate>'));
      }
    }

    final TableSchemaEntity? selected = _schemas.firstWhereOrNull(
      (TableSchemaEntity s) => s.id == _selectedTableId,
    );
    if (selected != null) {
      addForSchema(selected);
    }
    for (final TableSchemaEntity schema in _schemas) {
      if (selected != null && schema.id == selected.id) {
        continue;
      }
      addForSchema(schema);
    }
    return out;
  }

  void _insertPlaceholderSuggestion(String insertText) {
    final int? start = _placeholderStartOffset;
    if (start == null) {
      return;
    }
    final TextSelection selection = _messageController.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return;
    }
    final int caret = selection.extentOffset;
    final String text = _messageController.text;
    if (start < 0 || start > caret || caret > text.length) {
      return;
    }
    final String replaced = text.replaceRange(start, caret, insertText);
    _messageController.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: start + insertText.length),
    );
    setState(() {
      _placeholderStartOffset = null;
      _placeholderQuery = '';
    });
  }

  Future<void> _loadSchemas() async {
    final GetAllTableSchemasUseCase getAllSchemas = Get.find();
    final List<TableSchemaEntity> schemas = await getAllSchemas();
    final Map<String, List<TableRowHiveModel>> rowsByTableId =
        _loadRowsByTableId();
    if (!mounted) {
      return;
    }
    setState(() {
      _schemas = schemas;
      _rowsByTableId = rowsByTableId;
      _selectedTableId =
          _selectedTableId.isEmpty && schemas.isNotEmpty
              ? schemas.first.id
              : _selectedTableId;
      _selectedColumnId = _resolveDefaultColumnId();
    });
  }

  void _applyInitial(Map<String, dynamic>? rule) {
    if (rule == null) {
      return;
    }
    _enabled = rule['enabled'] == true;
    _conditionFamily = (rule['conditionFamily'] ?? 'date').toString();
    _dateCondition = (rule['dateCondition'] ?? 'today').toString();
    _withinUnit = (rule['withinUnit'] ?? 'weeks').toString();
    _numericCondition = (rule['numericCondition'] ?? 'gt').toString();
    _scope = (rule['scope'] ?? 'daily').toString();
    _severity = (rule['severity'] ?? 'info').toString();
    _selectedTableId = (rule['tableId'] ?? '').toString();
    _selectedColumnId = (rule['columnId'] ?? '').toString();
    _titleController.text = (rule['title'] ?? '').toString();
    _messageController.text = (rule['message'] ?? '').toString();
    _thresholdController.text = (rule['threshold'] ?? '').toString();
    _withinController.text = (rule['withinValue'] ?? '7').toString();
  }

  String _resolveDefaultColumnId() {
    if (_selectedTableId.isEmpty) {
      return '';
    }
    TableSchemaEntity? schema;
    for (final TableSchemaEntity item in _schemas) {
      if (item.id == _selectedTableId) {
        schema = item;
        break;
      }
    }
    if (schema == null || schema.columns.isEmpty) {
      return '';
    }
    if (_selectedColumnId.isNotEmpty &&
        schema.columns.any((c) => c.id == _selectedColumnId)) {
      return _selectedColumnId;
    }
    return schema.columns.first.id;
  }

  Future<void> _saveRule() async {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? old = box.get(_settingsKey);
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      old?.accountWorkspaces,
    );
    final Map<String, dynamic> workspace = _asStringDynamicMap(
      workspaces[_activeAccountName],
    );
    final List<Map<String, dynamic>> notifications = _asMapList(
          workspace['notifications'],
        )
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: true);
    String existingRuleId = '';
    if (_editingIndex != null &&
        _editingIndex! >= 0 &&
        _editingIndex! < notifications.length) {
      existingRuleId =
          (notifications[_editingIndex!]['ruleId'] ?? '').toString().trim();
    }
    final String ruleId =
        existingRuleId.isEmpty
            ? 'rule_${DateTime.now().microsecondsSinceEpoch}'
            : existingRuleId;
    final Map<String, dynamic> payload = <String, dynamic>{
      'ruleId': ruleId,
      'enabled': _enabled,
      'tableId': _selectedTableId,
      'columnId': _selectedColumnId,
      'conditionFamily': _conditionFamily,
      'dateCondition': _dateCondition,
      'withinValue': int.tryParse(_withinController.text.trim()) ?? 0,
      'withinUnit': _withinUnit,
      'numericCondition': _numericCondition,
      'scope': _scope,
      'threshold': _thresholdController.text.trim(),
      'severity': _severity,
      'title': _titleController.text.trim(),
      'message': _messageController.text.trim(),
    };
    if (_editingIndex != null &&
        _editingIndex! >= 0 &&
        _editingIndex! < notifications.length) {
      notifications[_editingIndex!] = payload;
    } else {
      notifications.add(payload);
    }
    workspace['notifications'] = notifications;
    workspaces[_activeAccountName] = workspace;

    await box.put(
      _settingsKey,
      AppSettingsHiveModel(
        resourcesDownloaded: old?.resourcesDownloaded ?? false,
        themeMode: old?.themeMode ?? 'system',
        firstInstallCompleted: old?.firstInstallCompleted ?? false,
        themePresetName: old?.themePresetName ?? 'Ocean Blue',
        accountNames: old?.accountNames ?? const <String>[],
        activeAccountName: old?.activeAccountName ?? _activeAccountName,
        accountWorkspaces: workspaces,
      ),
    );
    await NotificationRuntimeService.evaluateRulesAndNotify(
      targetRuleId: ruleId,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteThisRule() async {
    final int? idx = _editingIndex;
    if (idx == null || idx < 0) {
      return;
    }
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Delete notification?'),
              content: const Text(
                'This will permanently remove the notification rule.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ==
        true;
    if (!confirmed) {
      return;
    }
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? old = box.get(_settingsKey);
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      old?.accountWorkspaces,
    );
    final Map<String, dynamic> workspace = _asStringDynamicMap(
      workspaces[_activeAccountName],
    );
    final List<Map<String, dynamic>> notifications = _asMapList(
          workspace['notifications'],
        )
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: true);
    if (idx >= 0 && idx < notifications.length) {
      notifications.removeAt(idx);
    }
    workspace['notifications'] = notifications;
    workspaces[_activeAccountName] = workspace;
    await box.put(
      _settingsKey,
      AppSettingsHiveModel(
        resourcesDownloaded: old?.resourcesDownloaded ?? false,
        themeMode: old?.themeMode ?? 'system',
        firstInstallCompleted: old?.firstInstallCompleted ?? false,
        themePresetName: old?.themePresetName ?? 'Ocean Blue',
        accountNames: old?.accountNames ?? const <String>[],
        activeAccountName: old?.activeAccountName ?? _activeAccountName,
        accountWorkspaces: workspaces,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TableSchemaEntity? selectedTable = _schemas.firstWhereOrNull(
      (TableSchemaEntity t) => t.id == _selectedTableId,
    );

    final ({IconData icon, Color color, String heading}) previewMeta =
        switch (_severity) {
          'danger' => (
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            heading: 'Danger',
          ),
          'warning' => (
            icon: Icons.schedule_rounded,
            color: Colors.orange,
            heading: 'Warning',
          ),
          _ => (
            icon: Icons.info_outline_rounded,
            color: Colors.blue,
            heading: 'Info',
          ),
        };
    final String previewTitle =
        _titleController.text.trim().isEmpty
            ? '${previewMeta.heading} Notification'
            : _titleController.text.trim();
    final String previewMessage =
        _messageController.text.trim().isEmpty
            ? 'Configure your custom notification message.'
            : _resolvePreviewMessage(_messageController.text.trim());
    final List<({String label, String insertText})> placeholderSuggestions =
        _placeholderStartOffset == null
            ? const <({String label, String insertText})>[]
            : _placeholderSuggestions();
    final Widget form = ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SwitchListTile(
          title: const Text('Enable Notification'),
          value: _enabled,
          onChanged: (bool value) => setState(() => _enabled = value),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedTableId.isEmpty ? null : _selectedTableId,
          decoration: const InputDecoration(
            labelText: 'Table',
            border: OutlineInputBorder(),
          ),
          items: _schemas
              .map(
                (TableSchemaEntity s) =>
                    DropdownMenuItem<String>(value: s.id, child: Text(s.name)),
              )
              .toList(growable: false),
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _selectedTableId = value;
              _selectedColumnId = _resolveDefaultColumnId();
            });
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedColumnId.isEmpty ? null : _selectedColumnId,
          decoration: const InputDecoration(
            labelText: 'Column',
            border: OutlineInputBorder(),
          ),
          items: (selectedTable?.columns ?? const <dynamic>[])
              .map<DropdownMenuItem<String>>(
                (dynamic c) => DropdownMenuItem<String>(
                  value: c.id as String,
                  child: Text(c.name as String),
                ),
              )
              .toList(growable: false),
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            setState(() => _selectedColumnId = value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _conditionFamily,
          decoration: const InputDecoration(
            labelText: 'Condition Type',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'date', child: Text('Date-based')),
            DropdownMenuItem(
              value: 'numeric',
              child: Text('Numeric / Aggregate'),
            ),
          ],
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            setState(() => _conditionFamily = value);
          },
        ),
        const SizedBox(height: 10),
        if (_conditionFamily == 'date') ...<Widget>[
          DropdownButtonFormField<String>(
            value: _dateCondition,
            decoration: const InputDecoration(
              labelText: 'Date Condition',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'today', child: Text('Today')),
              DropdownMenuItem(
                value: 'within',
                child: Text('Within X days/weeks'),
              ),
              DropdownMenuItem(value: 'before', child: Text('Before date')),
              DropdownMenuItem(value: 'after', child: Text('After date')),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _dateCondition = value);
            },
          ),
          const SizedBox(height: 10),
          if (_dateCondition == 'within')
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _withinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Within value',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _withinUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'days', child: Text('Days')),
                      DropdownMenuItem(value: 'weeks', child: Text('Weeks')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _withinUnit = value);
                    },
                  ),
                ),
              ],
            ),
        ] else ...<Widget>[
          DropdownButtonFormField<String>(
            value: _numericCondition,
            decoration: const InputDecoration(
              labelText: 'Numeric Condition',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'gt', child: Text('Greater than')),
              DropdownMenuItem(value: 'lt', child: Text('Less than')),
              DropdownMenuItem(value: 'eq', child: Text('Equals')),
              DropdownMenuItem(value: 'quota', child: Text('Reached quota')),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _numericCondition = value);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _scope,
            decoration: const InputDecoration(
              labelText: 'Scope',
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'daily', child: Text('Daily')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            ],
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _scope = value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _thresholdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Threshold / Value',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _severity,
          decoration: const InputDecoration(
            labelText: 'Severity',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(value: 'danger', child: Text('Danger')),
            DropdownMenuItem(value: 'warning', child: Text('Warning')),
            DropdownMenuItem(value: 'info', child: Text('Info')),
          ],
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            setState(() => _severity = value);
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Notification Title',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _messageController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Notification Message',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        Text(
          'Use < > to insert dynamic column values.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (placeholderSuggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: placeholderSuggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, int i) {
                  final ({String label, String insertText}) item =
                      placeholderSuggestions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.code, size: 18),
                    title: Text(item.label),
                    subtitle: Text(item.insertText),
                    onTap: () => _insertPlaceholderSuggestion(item.insertText),
                  );
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Live Preview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Icon(previewMeta.icon, color: previewMeta.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        previewTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(previewMessage, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saveRule,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Notification Rule'),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editingIndex == null ? 'Create Notification' : 'Edit Notification',
        ),
        actions: <Widget>[
          if (_editingIndex != null)
            IconButton(
              tooltip: 'Delete',
              onPressed: _deleteThisRule,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: form,
    );
  }

  String _resolvePreviewMessage(String messageTemplate) {
    if (messageTemplate.isEmpty) {
      return messageTemplate;
    }
    final Map<String, TableSchemaEntity> schemasByName =
        <String, TableSchemaEntity>{
          for (final TableSchemaEntity schema in _schemas)
            schema.name.trim().toLowerCase(): schema,
        };
    final TableSchemaEntity? selectedSchema = _schemas.firstWhereOrNull(
      (TableSchemaEntity schema) => schema.id == _selectedTableId,
    );
    final List<TableRowHiveModel> selectedRows =
        _rowsByTableId[_selectedTableId] ?? const <TableRowHiveModel>[];
    final TableRowHiveModel? selectedRow =
        selectedRows.isEmpty ? null : selectedRows.first;
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
      TableSchemaEntity? schema = selectedSchema;
      if (tableName != null && tableName.isNotEmpty) {
        schema = schemasByName[tableName.toLowerCase()];
      }
      if (schema == null) {
        return '[N/A]';
      }
      final TableSchemaEntity resolvedSchema = schema;
      final dynamic column = schema.columns.firstWhereOrNull(
        (dynamic col) =>
            col.name.toString().trim().toLowerCase() ==
            columnName.toLowerCase(),
      );
      if (column == null) {
        return '[N/A]';
      }
      final TableRowHiveModel? row =
          resolvedSchema.id == _selectedTableId
              ? selectedRow
              : (() {
                final List<TableRowHiveModel> tableRows =
                    _rowsByTableId[resolvedSchema.id] ??
                    const <TableRowHiveModel>[];
                return tableRows.isEmpty ? null : tableRows.first;
              })();
      if (row == null) {
        return '[N/A]';
      }
      final String columnId = (column.id?.toString() ?? '').trim();
      if (columnId.isEmpty) {
        return '[N/A]';
      }
      final String value = (row.values[columnId] ?? '').toString().trim();
      return value.isEmpty ? '[N/A]' : value;
    });
  }

  Map<String, List<TableRowHiveModel>> _loadRowsByTableId() {
    if (!Hive.isBoxOpen(HiveBoxes.rowsBox)) {
      return <String, List<TableRowHiveModel>>{};
    }
    final Box<TableRowHiveModel> rowBox = Hive.box<TableRowHiveModel>(
      HiveBoxes.rowsBox,
    );
    final Map<String, List<TableRowHiveModel>> rowsByTableId =
        <String, List<TableRowHiveModel>>{};
    for (final TableRowHiveModel row in rowBox.values) {
      rowsByTableId
          .putIfAbsent(row.tableId, () => <TableRowHiveModel>[])
          .add(row);
    }
    return rowsByTableId;
  }
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

Map<String, dynamic>? _asNullableStringMap(dynamic raw) {
  final Map<String, dynamic> value = _asStringDynamicMap(raw);
  if (value.isEmpty) {
    return null;
  }
  return value;
}
