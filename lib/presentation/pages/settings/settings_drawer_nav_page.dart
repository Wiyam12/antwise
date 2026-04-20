import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/drawer_nav_layout_type.dart';
import 'package:antwise/presentation/controllers/settings_controller.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:antwise/presentation/widgets/drawer_nav/drawer_nav_layout_preview_cards.dart';
import 'package:antwise/presentation/widgets/page_icon_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsDrawerNavPage extends GetView<SettingsController> {
  const SettingsDrawerNavPage({super.key});

  Future<void> _openIconPicker(BuildContext context, BuilderPageEntity page) {
    return PageIconPickerSheet.show(
      context,
      initialKey: page.iconName,
      initialName: page.name,
      onSave: (String key, String name) async {
        await controller.updatePageDetails(page.id, iconName: key, name: name);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawer Pages'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Deleted pages',
            onPressed: () => Get.toNamed<void>(AppRoutes.settingsDeletedPages),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        controller.pagesRevision.value;
        final List<String> parentIds = controller.drawerParentIds;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            Text('Drawer layout', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Choose how drawer menu items are styled. This updates drawer presentation while keeping your existing header.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DrawerNavLayoutPicker(
              selected: controller.drawerNavLayout.value,
              onSelect: (DrawerNavLayoutType type) {
                controller.setDrawerNavLayout(type);
              },
            ),
            const SizedBox(height: 24),
            Text('Pages', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (parentIds.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No pages in drawer navigation yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: parentIds.length,
                  onReorder: controller.reorderDrawerParents,
                  itemBuilder: (BuildContext context, int index) {
                    final String parentId = parentIds[index];
                    final BuilderPageEntity? parent = controller.pageById(
                      parentId,
                    );
                    if (parent == null) {
                      return SizedBox(
                        key: ValueKey<String>('drawer-parent-$parentId'),
                        child: const SizedBox.shrink(),
                      );
                    }
                    final bool isMain = controller.mainPageId.value == parentId;
                    final List<String> childIds = controller.drawerChildIdsOf(
                      parentId,
                    );
                    return Material(
                      key: ValueKey<String>('drawer-parent-$parentId'),
                      child: _ParentDrawerItem(
                        parent: parent,
                        isMain: isMain,
                        childIds: childIds,
                        parentIndex: index,
                        controller: controller,
                        onEdit: () => _openIconPicker(context, parent),
                        onDelete: () => controller.removeFromDrawer(parentId),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _ParentDrawerItem extends StatelessWidget {
  const _ParentDrawerItem({
    required this.parent,
    required this.isMain,
    required this.childIds,
    required this.parentIndex,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  final BuilderPageEntity parent;
  final bool isMain;
  final List<String> childIds;
  final int parentIndex;
  final SettingsController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ExpansionTile(
      title: Row(
        children: <Widget>[
          Icon(
            AppIconRegistry.iconOf(parent.iconName),
            size: 24,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              parent.name,
              style: theme.textTheme.labelSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMain)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'MAIN',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      subtitle:
          childIds.isEmpty
              ? null
              : Text(
                '${childIds.length} child page${childIds.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      leading: ReorderableDragStartListener(
        index: parentIndex,
        child: Padding(
          padding: const EdgeInsets.only(right: 4, left: 4),
          child: Icon(Icons.drag_handle, color: theme.colorScheme.outline),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit parent page',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove parent from drawer navigation',
            onPressed: onDelete,
          ),
        ],
      ),
      childrenPadding: const EdgeInsets.only(left: 12, right: 8, bottom: 6),
      children: <Widget>[
        if (childIds.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              'No child pages.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: childIds.length,
            onReorder: (int oldIndex, int newIndex) {
              controller.reorderDrawerChildren(parent.id, oldIndex, newIndex);
            },
            itemBuilder: (BuildContext context, int childIndex) {
              final String childId = childIds[childIndex];
              final BuilderPageEntity? child = controller.pageById(childId);
              if (child == null) {
                return SizedBox(
                  key: ValueKey<String>('drawer-child-${parent.id}-$childId'),
                  child: const SizedBox.shrink(),
                );
              }
              return Material(
                key: ValueKey<String>('drawer-child-${parent.id}-$childId'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 16),
                      ReorderableDragStartListener(
                        index: childIndex,
                        child: Icon(
                          Icons.drag_handle,
                          size: 20,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        AppIconRegistry.iconOf(child.iconName),
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          child.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit child page',
                        onPressed:
                            () => PageIconPickerSheet.show(
                              context,
                              initialKey: child.iconName,
                              initialName: child.name,
                              onSave: (String key, String name) async {
                                await controller.updatePageDetails(
                                  child.id,
                                  iconName: key,
                                  name: name,
                                );
                              },
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove child from drawer navigation',
                        onPressed: () => controller.removeFromDrawer(childId),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
