import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Settings Sections', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _settingsEntry(
            context,
            title: 'Bottom Nav Pages',
            subtitle: 'Reorder pages, manage MAIN PAGE, remove pages',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsBottomNav),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            title: 'Drawer Pages',
            subtitle: 'Reorder drawer pages and remove pages',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsDrawerNav),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            title: 'Theme Settings',
            subtitle: 'Primary/secondary color and mode',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsTheme),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            title: 'Page Layout Settings',
            subtitle: 'Widget grid and widgets/tables order per page',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsPageLayouts),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            title: 'Tables',
            subtitle: 'Table settings and configuration',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsTables),
          ),
          const SizedBox(height: 10),
          _settingsEntry(
            context,
            title: 'Widgets',
            subtitle: 'Widget settings and behavior',
            onTap: () => Get.toNamed<void>(AppRoutes.settingsWidgets),
          ),
        ],
      ),
    );
  }

  Widget _settingsEntry(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
