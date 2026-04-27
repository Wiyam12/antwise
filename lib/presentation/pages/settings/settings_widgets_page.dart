import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/presentation/controllers/settings_widgets_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsWidgetsPage extends GetView<SettingsWidgetsController> {
  const SettingsWidgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widgets Settings')),
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
            final List<BuilderWidgetEntity> pageWidgets = controller
                .widgetsForPage(page.id);
            return Card(
              child: ExpansionTile(
                key: ValueKey<String>('page-${page.id}-$expanded'),
                initiallyExpanded: expanded,
                onExpansionChanged: (_) => controller.toggleExpanded(page.id),
                leading: Icon(AppIconRegistry.iconOf(page.iconName)),
                title: Text(page.name),
                children: <Widget>[
                  if (pageWidgets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No widgets assigned'),
                      ),
                    )
                  else
                    Column(
                      children: pageWidgets
                          .map((BuilderWidgetEntity widget) {
                            return ListTile(
                              title: Text(controller.widgetDisplayName(widget)),
                              trailing: Wrap(
                                spacing: 4,
                                children: <Widget>[
                                  IconButton(
                                    onPressed:
                                        () => controller.openEditWidget(
                                          widget.id,
                                        ),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    onPressed:
                                        () => controller.deleteWidget(widget),
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(growable: false),
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
