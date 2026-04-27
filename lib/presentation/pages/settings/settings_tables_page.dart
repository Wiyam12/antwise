import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/presentation/controllers/settings_tables_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsTablesPage extends GetView<SettingsTablesController> {
  const SettingsTablesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tables Settings')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.pages.isEmpty) {
          return const Center(child: Text('No pages available'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: controller.pages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int index) {
            final page = controller.pages[index];
            final bool expanded = controller.expandedPages.contains(page.id);
            final tables = controller.tablesForPage(page.id);
            return Card(
              child: ExpansionTile(
                key: ValueKey<String>('page-${page.id}-$expanded'),
                initiallyExpanded: expanded,
                onExpansionChanged: (_) => controller.toggleExpanded(page.id),
                leading: Icon(AppIconRegistry.iconOf(page.iconName)),
                title: Text(page.name),
                children: <Widget>[
                  if (tables.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No tables assigned'),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tables.length,
                      onReorder:
                          (int oldIndex, int newIndex) => controller
                              .reorderTablesInPage(page.id, oldIndex, newIndex),
                      itemBuilder: (BuildContext context, int tableIndex) {
                        final table = tables[tableIndex];
                        return ListTile(
                          key: ValueKey<String>(table.id),
                          leading: const Icon(Icons.drag_indicator),
                          title: Text(table.name),
                          subtitle: Text(
                            'Rows: ${controller.rowCountByTable[table.id] ?? 0}',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: <Widget>[
                              IconButton(
                                onPressed:
                                    () => controller.openEditTable(table.id),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () => controller.deleteTable(table),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}
