import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/presentation/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsDeletedPagesPage extends GetView<SettingsController> {
  const SettingsDeletedPagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deleted Pages')),
      body: Obx(() {
        final List<BuilderPageEntity> deleted = controller.deletedPages;
        if (deleted.isEmpty) {
          return const Center(child: Text('No deleted pages'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (BuildContext context, int index) {
            final BuilderPageEntity page = deleted[index];
            return ListTile(
              leading: Icon(AppIconRegistry.iconOf(page.iconName)),
              title: Text(page.name),
              subtitle: const Text('Soft deleted'),
              trailing: FilledButton.tonal(
                onPressed: () => controller.restoreDeletedPage(page.id),
                child: const Text('Restore'),
              ),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: deleted.length,
        );
      }),
    );
  }
}
