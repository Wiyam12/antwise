import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
        ],
      ),
    );
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
}
