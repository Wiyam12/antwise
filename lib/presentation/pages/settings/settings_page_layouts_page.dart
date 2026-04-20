import 'package:antwise/presentation/controllers/settings_page_layout_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsPageLayoutsPage extends GetView<SettingsPageLayoutController> {
  const SettingsPageLayoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pages Layout Settings')),
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
            return Card(
              child: ListTile(
                title: Text(page.name),
                subtitle: Text(
                  'Widgets per row: ${page.widgetGridCount.clamp(1, 3)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => controller.openPageLayout(page.id),
              ),
            );
          },
        );
      }),
    );
  }
}
