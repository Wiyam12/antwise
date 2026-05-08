import 'dart:async';

import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/app_settings_hive_model.dart';
import 'package:antwise/data/models/hive/builder_page_hive_model.dart';
import 'package:antwise/data/models/hive/builder_widget_hive_model.dart';
import 'package:antwise/data/models/hive/navigation_config_hive_model.dart';
import 'package:antwise/data/models/hive/table_row_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _settingsKey = 'app_settings';

  List<String> _accountNames = <String>[];
  String _activeAccountName = '';

  @override
  void initState() {
    super.initState();
    _loadAccountState();
    final Map<String, dynamic>? args =
        Get.arguments is Map<String, dynamic>
            ? Get.arguments as Map<String, dynamic>
            : null;
    if (args?['openAccountSelector'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _openAccountSelector(context);
      });
    }
  }

  void _loadAccountState() {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? settings = box.get(_settingsKey);
    setState(() {
      _accountNames = settings?.accountNames ?? const <String>[];
      _activeAccountName = settings?.activeAccountName ?? '';
    });
  }

  Future<void> _switchAccount(String accountName) async {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return;
    }
    if (accountName == _activeAccountName) {
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? old = box.get(_settingsKey);
    final String currentAccountName = old?.activeAccountName ?? '';
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      old?.accountWorkspaces,
    );

    if (currentAccountName.isNotEmpty) {
      workspaces[currentAccountName] = _captureWorkspaceSnapshot(
        accountName: currentAccountName,
      );
    }
    await _clearWorkspaceSnapshot();
    final Map<String, dynamic>? targetWorkspace = _asNullableStringMap(
      workspaces[accountName],
    );
    if (targetWorkspace != null) {
      await _restoreWorkspaceSnapshot(targetWorkspace);
    }
    workspaces[accountName] = _captureWorkspaceSnapshot(
      accountName: accountName,
    );

    await box.put(
      _settingsKey,
      AppSettingsHiveModel(
        resourcesDownloaded: old?.resourcesDownloaded ?? false,
        themeMode: old?.themeMode ?? 'system',
        firstInstallCompleted: old?.firstInstallCompleted ?? false,
        themePresetName: old?.themePresetName ?? 'Ocean Blue',
        accountNames: old?.accountNames ?? _accountNames,
        activeAccountName: accountName,
        accountWorkspaces: workspaces,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _activeAccountName = accountName;
    });
    Get.offAllNamed<void>(AppRoutes.home);
  }

  Future<void> _clearWorkspaceSnapshot() async {
    if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      await Hive.box<BuilderPageHiveModel>(HiveBoxes.pagesBox).clear();
    }
    if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      await Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox).clear();
    }
    if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      await Hive.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox).clear();
    }
    if (Hive.isBoxOpen(HiveBoxes.rowsBox)) {
      await Hive.box<TableRowHiveModel>(HiveBoxes.rowsBox).clear();
    }
    if (Hive.isBoxOpen(HiveBoxes.navigationBox)) {
      await Hive.box<NavigationConfigHiveModel>(
        HiveBoxes.navigationBox,
      ).clear();
    }
  }

  Future<void> _openAccountSelector(BuildContext context) async {
    final ThemeData theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Stack(
          children: <Widget>[
            Positioned(
              top:
                  kToolbarHeight + MediaQuery.of(dialogContext).padding.top + 8,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Card(
                    elevation: 10,
                    margin: EdgeInsets.zero,
                    child: SizedBox(
                      width: 320,
                      height: 360,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Accounts',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _accountNames.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, int index) {
                                  final String accountName =
                                      _accountNames[index];
                                  final bool isActive =
                                      accountName == _activeAccountName;
                                  return _accountCard(
                                    icon: Icons.business_outlined,
                                    title: accountName,
                                    isActive: isActive,
                                    onTap: () async {
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                      if (!mounted) {
                                        return;
                                      }
                                      await _switchAccount(accountName);
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            _accountCard(
                              icon: Icons.add_circle_outline,
                              title: 'Create New Account',
                              isActive: false,
                              leadingPrefix: '+ ',
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                Get.offAllNamed<void>(
                                  AppRoutes.home,
                                  arguments: <String, dynamic>{
                                    'forceSetupMode': true,
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    _loadAccountState();
  }

  Future<void> _openAccountBottomSheet(BuildContext context) async {
    final ThemeData theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 420,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      'Accounts',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _accountNames.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, int index) {
                        final String accountName = _accountNames[index];
                        final bool isActive = accountName == _activeAccountName;
                        return _accountCard(
                          icon: Icons.business_outlined,
                          title: accountName,
                          isActive: isActive,
                          onTap: () async {
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                            if (!mounted) {
                              return;
                            }
                            await _switchAccount(accountName);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  _accountCard(
                    icon: Icons.add_circle_outline,
                    title: 'Create New Account',
                    isActive: false,
                    leadingPrefix: '+ ',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Get.offAllNamed<void>(
                        AppRoutes.home,
                        arguments: <String, dynamic>{'forceSetupMode': true},
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _loadAccountState();
  }

  @override
  Widget build(BuildContext context) {
    final bool canDeleteActiveWorkspace = _activeAccountName.trim().isNotEmpty;
    final String activeWorkspaceName =
        _activeAccountName.trim().isEmpty
            ? 'No active workspace'
            : _activeAccountName.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.tonalIcon(
            onPressed: () => _openAccountBottomSheet(context),
            icon: const Icon(Icons.workspaces_outline),
            label: Text('Current Workspace: $activeWorkspaceName'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _settingsEntry(
            context,
            prefixIcon: Icons.view_day_outlined,
            title: 'Bottom Nav Pages',
            subtitle: 'Reorder pages, manage MAIN PAGE, remove pages',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsBottomNav),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            prefixIcon: Icons.menu_open_outlined,
            title: 'Drawer Pages',
            subtitle: 'Reorder drawer pages and remove pages',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsDrawerNav),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            prefixIcon: Icons.palette_outlined,
            title: 'Theme Settings',
            subtitle: 'Primary/secondary color and mode',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsTheme),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            prefixIcon: Icons.dashboard_customize_outlined,
            title: 'Page Layout Settings',
            subtitle: 'Widget grid and widgets/tables order per page',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsPageLayouts),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            prefixIcon: Icons.table_chart_outlined,
            title: 'Tables',
            subtitle: 'Table settings and configuration',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsTables),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            prefixIcon: Icons.widgets_outlined,
            title: 'Widgets',
            subtitle: 'Widget settings and behavior',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsWidgets),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            prefixIcon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Rule-based notification settings',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsNotifications),
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Danger Zone',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // const SizedBox(height: 24),
          Divider(
            height: 1,
            thickness: 1.4,
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  canDeleteActiveWorkspace
                      ? _handleDeleteWorkspaceAccount
                      : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Delete this Workspace Account'),
            ),
          ),
          if (!canDeleteActiveWorkspace)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No active workspace account selected.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteWorkspaceAccount() async {
    final String targetAccountName = _activeAccountName.trim();
    if (targetAccountName.isEmpty || !Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return;
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? old = box.get(_settingsKey);
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      old?.accountWorkspaces,
    );
    workspaces[targetAccountName] = _captureWorkspaceSnapshot(
      accountName: targetAccountName,
    );
    final Map<String, dynamic> targetWorkspace =
        _asNullableStringMap(workspaces[targetAccountName]) ??
        <String, dynamic>{};
    final ({int pages, int tables, int widgets}) counts = _workspaceCounts(
      targetWorkspace,
    );

    final bool firstConfirmed = await _showDeleteWorkspaceFirstConfirm(
      accountName: targetAccountName,
      pagesCount: counts.pages,
      tablesCount: counts.tables,
      widgetsCount: counts.widgets,
    );
    if (!firstConfirmed) {
      return;
    }
    final bool secondConfirmed = await _showDeleteWorkspaceFinalConfirm();
    if (!secondConfirmed) {
      return;
    }

    final List<String> updatedAccountNames = <String>[
      for (final String name in (old?.accountNames ?? _accountNames))
        if (name.toLowerCase() != targetAccountName.toLowerCase()) name,
    ];
    workspaces.removeWhere(
      (String key, dynamic _) =>
          key.toLowerCase() == targetAccountName.toLowerCase(),
    );

    if (updatedAccountNames.isEmpty) {
      await _clearWorkspaceSnapshot();
      await box.put(
        _settingsKey,
        AppSettingsHiveModel(
          resourcesDownloaded: old?.resourcesDownloaded ?? false,
          themeMode: old?.themeMode ?? 'system',
          firstInstallCompleted: false,
          themePresetName: old?.themePresetName ?? 'Ocean Blue',
          accountNames: const <String>[],
          activeAccountName: '',
          accountWorkspaces: <String, dynamic>{},
        ),
      );
      if (mounted) {
        setState(() {
          _accountNames = <String>[];
          _activeAccountName = '';
        });
      }
      Get.offAllNamed<void>(
        AppRoutes.home,
        arguments: <String, dynamic>{'forceSetupMode': true},
      );
      return;
    }

    final String nextAccount = updatedAccountNames.first;
    await _clearWorkspaceSnapshot();
    final Map<String, dynamic>? nextWorkspace = _asNullableStringMap(
      workspaces[nextAccount],
    );
    if (nextWorkspace != null) {
      await _restoreWorkspaceSnapshot(nextWorkspace);
    }
    workspaces[nextAccount] = _captureWorkspaceSnapshot(
      accountName: nextAccount,
    );

    await box.put(
      _settingsKey,
      AppSettingsHiveModel(
        resourcesDownloaded: old?.resourcesDownloaded ?? false,
        themeMode: old?.themeMode ?? 'system',
        firstInstallCompleted: old?.firstInstallCompleted ?? true,
        themePresetName: old?.themePresetName ?? 'Ocean Blue',
        accountNames: updatedAccountNames,
        activeAccountName: nextAccount,
        accountWorkspaces: workspaces,
      ),
    );
    if (mounted) {
      setState(() {
        _accountNames = updatedAccountNames;
        _activeAccountName = nextAccount;
      });
    }
    Get.offAllNamed<void>(AppRoutes.home);
  }

  ({int pages, int tables, int widgets}) _workspaceCounts(
    Map<String, dynamic> snapshot,
  ) {
    final int pages = _asMapList(snapshot['pages']).length;
    final int tables = _asMapList(snapshot['tables']).length;
    final int widgets = _asMapList(snapshot['widgets']).length;
    return (pages: pages, tables: tables, widgets: widgets);
  }

  Future<bool> _showDeleteWorkspaceFirstConfirm({
    required String accountName,
    required int pagesCount,
    required int tablesCount,
    required int widgetsCount,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Delete Workspace Account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Account: $accountName'),
              const SizedBox(height: 4),
              Text('Pages: $pagesCount'),
              Text('Tables: $tablesCount'),
              Text('Widgets: $widgetsCount'),
              const SizedBox(height: 12),
              Text(
                'Deleting this workspace will permanently remove all data.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<bool> _showDeleteWorkspaceFinalConfirm() async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        int secondsLeft = 10;
        Timer? timer;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (Timer t) {
              if (!dialogContext.mounted) {
                t.cancel();
                return;
              }
              if (secondsLeft <= 0) {
                t.cancel();
                return;
              }
              setStateDialog(() {
                secondsLeft--;
              });
            });
            return AlertDialog(
              title: const Text('Final Confirmation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'This action is irreversible. All data will be permanently deleted.',
                    style: Theme.of(
                      dialogContext,
                    ).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(dialogContext).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    secondsLeft > 0
                        ? 'Please wait $secondsLeft seconds before confirming.'
                        : 'You can now confirm deletion.',
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      secondsLeft == 0
                          ? () {
                            timer?.cancel();
                            Navigator.of(dialogContext).pop(true);
                          }
                          : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor:
                        Theme.of(dialogContext).colorScheme.onError,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
    return result == true;
  }

  Widget _settingsEntry(
    BuildContext context, {
    required IconData prefixIcon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(prefixIcon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _accountCard({
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
    String leadingPrefix = '',
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text('$leadingPrefix$title'),
        trailing:
            isActive
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.chevron_right),
      ),
    );
  }

  Map<String, dynamic> _captureWorkspaceSnapshot({String? accountName}) {
    final List<Map<String, dynamic>> pages = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      final Box<BuilderPageHiveModel> pagesBox = Hive.box<BuilderPageHiveModel>(
        HiveBoxes.pagesBox,
      );
      pages.addAll(
        pagesBox.values.map((BuilderPageHiveModel page) {
          return <String, dynamic>{
            'id': page.id,
            'name': page.name,
            'icon': page.icon,
            'navigationType': page.navigationType,
            'isDeleted': page.isDeleted,
            'isDrawerParentContainer': page.isDrawerParentContainer,
            'parentPageId': page.parentPageId,
            'nestedDisplayType': page.nestedDisplayType,
            'nestedRootContentTabName': page.nestedRootContentTabName,
            'widgetGridCount': page.widgetGridCount,
            'layoutOrder': page.layoutOrder,
            'widgetOrder': page.widgetOrder,
          };
        }),
      );
    }

    final List<Map<String, dynamic>> tables = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      final Box<TableSchemaHiveModel> tablesBox =
          Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox);
      tables.addAll(
        tablesBox.values.map((TableSchemaHiveModel table) {
          return <String, dynamic>{
            'id': table.id,
            'pageId': table.pageId,
            'name': table.name,
            'description': table.description,
            'mode': table.mode,
            'layoutType': table.layoutType,
            'listDesignLayout': table.listDesignLayout,
            'swipeToDelete': table.swipeToDelete,
            'productDisplayMode': table.productDisplayMode,
            'tableKind': table.tableKind,
            'summaryConfig': _jsonSafe(table.summaryConfig),
            'inventoryDeduction': _jsonSafe(table.inventoryDeduction),
            'affectingTables': _jsonSafe(table.affectingTables),
            'validationRules': _jsonSafe(table.validationRules),
            'searchEnabled': table.searchEnabled,
            'dataLoadingMode': table.dataLoadingMode,
            'pageSize': table.pageSize,
            'lazyInitialLoad': table.lazyInitialLoad,
            'columns': table.columns.map(_jsonSafe).toList(growable: false),
          };
        }),
      );
    }

    final List<Map<String, dynamic>> widgets = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      final Box<BuilderWidgetHiveModel> widgetsBox =
          Hive.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox);
      widgets.addAll(
        widgetsBox.values.map((BuilderWidgetHiveModel widget) {
          return <String, dynamic>{
            'id': widget.id,
            'pageId': widget.pageId,
            'type': widget.type,
            'config': _jsonSafe(widget.config),
          };
        }),
      );
    }

    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    if (Hive.isBoxOpen(HiveBoxes.rowsBox)) {
      final Box<TableRowHiveModel> rowsBox = Hive.box<TableRowHiveModel>(
        HiveBoxes.rowsBox,
      );
      rows.addAll(
        rowsBox.values.map((TableRowHiveModel row) {
          return <String, dynamic>{
            'id': row.id,
            'tableId': row.tableId,
            'values': _jsonSafe(row.values),
          };
        }),
      );
    }

    Map<String, dynamic> navigation = <String, dynamic>{};
    if (Hive.isBoxOpen(HiveBoxes.navigationBox)) {
      final Box<NavigationConfigHiveModel> navBox =
          Hive.box<NavigationConfigHiveModel>(HiveBoxes.navigationBox);
      if (navBox.isNotEmpty) {
        final NavigationConfigHiveModel nav = navBox.values.first;
        navigation = <String, dynamic>{
          'bottomPageIds': nav.bottomPageIds,
          'drawerPageIds': nav.drawerPageIds,
          'activePageId': nav.activePageId,
          'mainPageId': nav.mainPageId,
          'bottomNavLayout': nav.bottomNavLayout,
          'bottomNavCenterPageId': nav.bottomNavCenterPageId,
          'bottomNavShowLabels': nav.bottomNavShowLabels,
          'drawerNavLayout': nav.drawerNavLayout,
        };
      }
    }

    return <String, dynamic>{
      'pages': pages,
      'tables': tables,
      'widgets': widgets,
      'rows': rows,
      'navigation': navigation,
      'notifications': _notificationsForAccount(accountName),
    };
  }

  List<Map<String, dynamic>> _notificationsForAccount(String? accountName) {
    if (!Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      return const <Map<String, dynamic>>[];
    }
    final Box<AppSettingsHiveModel> box = Hive.box<AppSettingsHiveModel>(
      HiveBoxes.settingsBox,
    );
    final AppSettingsHiveModel? settings = box.get(_settingsKey);
    final String targetAccount =
        (accountName ?? settings?.activeAccountName ?? '').trim();
    if (targetAccount.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    final Map<String, dynamic> workspaces = _asStringDynamicMap(
      settings?.accountWorkspaces,
    );
    final Map<String, dynamic> workspace = _asStringDynamicMap(
      workspaces[targetAccount],
    );
    return _asMapList(workspace['notifications'])
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> _restoreWorkspaceSnapshot(Map<String, dynamic> snapshot) async {
    final List<Map<String, dynamic>> pages = _asMapList(snapshot['pages']);
    final List<Map<String, dynamic>> tables = _asMapList(snapshot['tables']);
    final List<Map<String, dynamic>> widgets = _asMapList(snapshot['widgets']);
    final List<Map<String, dynamic>> rows = _asMapList(snapshot['rows']);
    final Map<String, dynamic> navigation = _asStringDynamicMap(
      snapshot['navigation'],
    );

    if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      final Box<BuilderPageHiveModel> box = Hive.box<BuilderPageHiveModel>(
        HiveBoxes.pagesBox,
      );
      await box.clear();
      for (final Map<String, dynamic> page in pages) {
        final BuilderPageHiveModel model = BuilderPageHiveModel(
          id: (page['id'] ?? '').toString(),
          name: (page['name'] ?? '').toString(),
          icon: (page['icon'] ?? 'article_outlined').toString(),
          navigationType: (page['navigationType'] ?? 'drawer').toString(),
          isDeleted: page['isDeleted'] == true,
          isDrawerParentContainer: page['isDrawerParentContainer'] == true,
          parentPageId: page['parentPageId']?.toString(),
          nestedDisplayType: page['nestedDisplayType']?.toString(),
          nestedRootContentTabName:
              page['nestedRootContentTabName']?.toString(),
          widgetGridCount: (page['widgetGridCount'] as num?)?.toInt() ?? 1,
          layoutOrder: _asStringList(page['layoutOrder']),
          widgetOrder: _asStringList(page['widgetOrder']),
        );
        await box.put(model.id, model);
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      final Box<TableSchemaHiveModel> box = Hive.box<TableSchemaHiveModel>(
        HiveBoxes.tablesBox,
      );
      await box.clear();
      for (final Map<String, dynamic> table in tables) {
        final TableSchemaHiveModel model = TableSchemaHiveModel(
          id: (table['id'] ?? '').toString(),
          pageId: (table['pageId'] ?? '').toString(),
          name: (table['name'] ?? '').toString(),
          description: (table['description'] ?? '').toString(),
          mode: (table['mode'] ?? 'crud').toString(),
          layoutType: (table['layoutType'] ?? 'vertical').toString(),
          listDesignLayout:
              (table['listDesignLayout'] ?? 'standard').toString(),
          swipeToDelete: table['swipeToDelete'] == true,
          productDisplayMode:
              (table['productDisplayMode'] ?? 'list').toString(),
          tableKind: (table['tableKind'] ?? 'standard').toString(),
          summaryConfig: _asNullableStringMap(table['summaryConfig']),
          inventoryDeduction: _asNullableStringMap(table['inventoryDeduction']),
          affectingTables: _asMapList(table['affectingTables']),
          validationRules: _asMapList(table['validationRules']),
          searchEnabled: table['searchEnabled'] == true,
          dataLoadingMode: (table['dataLoadingMode'] ?? 'lazy').toString(),
          pageSize: (table['pageSize'] as num?)?.toInt() ?? 10,
          lazyInitialLoad: (table['lazyInitialLoad'] as num?)?.toInt() ?? 5,
          columns: _asMapList(table['columns']),
        );
        await box.put(model.id, model);
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      final Box<BuilderWidgetHiveModel> box = Hive.box<BuilderWidgetHiveModel>(
        HiveBoxes.widgetsBox,
      );
      await box.clear();
      for (final Map<String, dynamic> widget in widgets) {
        final BuilderWidgetHiveModel model = BuilderWidgetHiveModel(
          id: (widget['id'] ?? '').toString(),
          pageId: (widget['pageId'] ?? '').toString(),
          type: (widget['type'] ?? 'card').toString(),
          config: _asStringDynamicMap(widget['config']),
        );
        await box.put(model.id, model);
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.rowsBox)) {
      final Box<TableRowHiveModel> box = Hive.box<TableRowHiveModel>(
        HiveBoxes.rowsBox,
      );
      await box.clear();
      for (final Map<String, dynamic> row in rows) {
        final TableRowHiveModel model = TableRowHiveModel(
          id: (row['id'] ?? '').toString(),
          tableId: (row['tableId'] ?? '').toString(),
          values: _asStringDynamicMap(row['values']),
        );
        await box.put(model.id, model);
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.navigationBox)) {
      final Box<NavigationConfigHiveModel> box =
          Hive.box<NavigationConfigHiveModel>(HiveBoxes.navigationBox);
      await box.clear();
      final NavigationConfigHiveModel model = NavigationConfigHiveModel(
        bottomPageIds: _asStringList(navigation['bottomPageIds']),
        drawerPageIds: _asStringList(navigation['drawerPageIds']),
        activePageId: navigation['activePageId']?.toString(),
        mainPageId: navigation['mainPageId']?.toString(),
        bottomNavLayout:
            (navigation['bottomNavLayout'] ?? 'standard').toString(),
        bottomNavCenterPageId: navigation['bottomNavCenterPageId']?.toString(),
        bottomNavShowLabels:
            navigation['bottomNavShowLabels'] is bool
                ? navigation['bottomNavShowLabels'] as bool
                : true,
        drawerNavLayout:
            (navigation['drawerNavLayout'] ?? 'softCard').toString(),
      );
      await box.put('navigation_config', model);
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

  List<String> _asStringList(dynamic raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw.map((dynamic item) => item.toString()).toList(growable: false);
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

  dynamic _jsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is List) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    if (value is Map) {
      return value.map<String, dynamic>(
        (dynamic key, dynamic mapValue) =>
            MapEntry<String, dynamic>(key.toString(), _jsonSafe(mapValue)),
      );
    }
    return value.toString();
  }
}
