import 'package:antwise/core/constants/app_constants.dart';
import 'package:antwise/presentation/controllers/create_page_hub_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreatePageScreen extends GetView<CreatePageHubController> {
  const CreatePageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          ListTile(
            leading: Icon(
              Icons.description_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Create New Page'),
            subtitle: const Text('Configure name and where it appears'),
            trailing: const Icon(Icons.chevron_right),
            onTap: controller.openNewPage,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Note: bottom navigation requires at least 2 pages.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.widgets_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Create Widgets'),
            subtitle: const Text('Card widgets — step-by-step'),
            trailing: const Icon(Icons.chevron_right),
            onTap: controller.openCreateWidget,
          ),
          ListTile(
            leading: Icon(
              Icons.table_chart_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Create Table'),
            subtitle: const Text('Build schema + behavior'),
            trailing: const Icon(Icons.chevron_right),
            onTap: controller.openCreateTable,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppConstants.appName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
