import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/domain/entities/bottom_nav_layout_type.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/presentation/controllers/settings_controller.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:antwise/presentation/widgets/bottom_nav/bottom_nav_layout_preview_cards.dart';
import 'package:antwise/presentation/widgets/page_icon_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsBottomNavPage extends GetView<SettingsController> {
  const SettingsBottomNavPage({super.key});

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
        title: const Text('Bottom Nav Pages'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Delete all bottom-nav pages',
            onPressed: controller.softDeleteAllBottomPages,
          ),
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
        final List<String> ids = controller.bottomOrder;
        final BottomNavLayoutType layout = controller.bottomNavLayout.value;
        final bool needsFloatingCenter = layout.needsCenterPageSelection;
        final bool isCenterEmphasis =
            layout == BottomNavLayoutType.centerIconEmphasis;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            Text(
              'Bottom navigation layout',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how the bar looks.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            BottomNavLayoutPicker(
              selected: layout,
              bottomNavPageCount: ids.length,
              onSelect: (BottomNavLayoutType type) {
                controller.setBottomNavLayout(type);
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                title: const Text('Show labels'),
                subtitle: Text(
                  layout == BottomNavLayoutType.standard
                      ? 'Off: icons only. Selected item uses icon color only (no background).'
                      : 'Off: icons only in the bottom bar.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: controller.bottomNavShowLabels.value,
                onChanged: (bool v) => controller.setBottomNavShowLabels(v),
              ),
            ),
            const SizedBox(height: 24),
            Text('Pages', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (ids.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No pages in bottom navigation yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (needsFloatingCenter)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          'Drag to reorder. The first page is the main page.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else if (isCenterEmphasis)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          'Drag to reorder. The first page is the main page. '
                          'The selected tab shows the highlight in the bar.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: ids.length,
                      onReorder: controller.reorderBottom,
                      itemBuilder: (BuildContext context, int index) {
                        final String id = ids[index];
                        final BuilderPageEntity? page = controller.pageById(id);
                        if (page == null) {
                          return SizedBox(
                            key: ValueKey<String>('bottom-$id'),
                            child: const SizedBox.shrink(),
                          );
                        }
                        final bool isMain = controller.mainPageId.value == id;
                        final bool isFloatingCenter =
                            needsFloatingCenter &&
                            controller.bottomNavCenterPageId.value == id;
                        return Material(
                          key: ValueKey<String>('bottom-$id'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      right: 4,
                                      left: 4,
                                    ),
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ),
                                Icon(
                                  AppIconRegistry.iconOf(page.iconName),
                                  size: 26,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        page.name,
                                        style: theme.textTheme.titleSmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (isMain || isFloatingCenter)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: <Widget>[
                                              if (isMain)
                                                Chip(
                                                  label: const Text(
                                                    'MAIN PAGE',
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  labelStyle:
                                                      theme
                                                          .textTheme
                                                          .labelSmall,
                                                ),
                                              if (isFloatingCenter)
                                                Chip(
                                                  label: const Text('CENTER'),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  backgroundColor:
                                                      theme
                                                          .colorScheme
                                                          .tertiaryContainer,
                                                  labelStyle: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (needsFloatingCenter)
                                  TextButton(
                                    onPressed:
                                        isFloatingCenter
                                            ? null
                                            : () =>
                                                controller.setCenterPage(id),
                                    child: Text(
                                      isFloatingCenter
                                          ? 'Center'
                                          : 'Set as center',
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Change icon',
                                  onPressed:
                                      () => _openIconPicker(context, page),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remove from bottom navigation',
                                  onPressed:
                                      () => controller.removeFromBottom(id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}
