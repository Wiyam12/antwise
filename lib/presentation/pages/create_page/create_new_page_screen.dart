import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/presentation/controllers/create_new_page_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CreateNewPageScreen extends GetView<CreateNewPageController> {
  const CreateNewPageScreen({super.key});

  Future<bool> _confirmDiscard(BuildContext context) async {
    if (!controller.hasUnsavedChanges) {
      return true;
    }
    final bool? shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Discard page creation?'),
          content: const Text(
            'You have unsaved changes. Do you want to discard this page creation?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic _) async {
        if (didPop) {
          return;
        }
        if (await _confirmDiscard(context) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New page'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _confirmDiscard(context) && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Obx(
              () => Text(
                controller.requiresSecondBottomPage.value
                    ? 'Main page name'
                    : 'Page name',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => TextField(
                controller: controller.nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText:
                      controller.requiresSecondBottomPage.value
                          ? 'e.g. Home'
                          : 'e.g. Dashboard',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Obx(() {
              final bool shouldAskSecondPage =
                  controller.showInBottomNav.value &&
                  controller.requiresSecondBottomPage.value;
              if (!shouldAskSecondPage) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Generated new page name',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller.secondBottomPageNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Second bottom-nav page name',
                      hintText: 'e.g. Analytics',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bottom navigation needs at least 2 pages. '
                    'Add this second page now before saving.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),
            Text('Navigation placement', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Select one placement for this page.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Obx(
              () => _PlacementToggleBar(
                bottomSelected: controller.showInBottomNav.value,
                drawerSelected: controller.showInDrawer.value,
                onBottomTap: controller.setPlacementBottomNav,
                onDrawerTap: controller.setPlacementDrawer,
              ),
            ),
            Obx(() {
              if (!controller.showInDrawer.value) {
                return const SizedBox.shrink();
              }
              final List<BuilderPageEntity> parents =
                  controller.drawerParentCandidates;
              final String? selectedParent =
                  controller.selectedParentPageId.value;
              final String currentName = controller.nameController.text.trim();
              String? selectedParentName;
              for (final BuilderPageEntity p in parents) {
                if (p.id == selectedParent) {
                  selectedParentName = p.name;
                  break;
                }
              }
              final String? previewParentName =
                  controller.createParentInline.value
                      ? controller.newParentPageNameController.text.trim()
                      : selectedParentName;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Parent Page (Optional)',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value:
                        controller.createParentInline.value
                            ? '__create_new_parent__'
                            : selectedParent,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select existing parent',
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No parent'),
                      ),
                      ...parents.map(
                        (BuilderPageEntity p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      ),
                      const DropdownMenuItem<String?>(
                        value: '__create_new_parent__',
                        child: Text('Create new parent page...'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value == '__create_new_parent__') {
                        controller.toggleCreateParentInline(true);
                        return;
                      }
                      controller.toggleCreateParentInline(false);
                      controller.selectParentPage(value);
                    },
                  ),
                  if (controller.createParentInline.value) ...<Widget>[
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller.newParentPageNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'New parent page name',
                        hintText: 'e.g. Profile',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if ((previewParentName ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Hierarchy preview: $previewParentName > ${currentName.isEmpty ? 'New page' : currentName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              );
            }),
            const SizedBox(height: 32),
            Obx(
              () => FilledButton(
                onPressed: controller.isSaving.value ? null : controller.save,
                child:
                    controller.isSaving.value
                        ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Padding(
                          padding: const EdgeInsets.all(10),
                          child: const Text('Save page'),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacementToggleBar extends StatelessWidget {
  const _PlacementToggleBar({
    required this.bottomSelected,
    required this.drawerSelected,
    required this.onBottomTap,
    required this.onDrawerTap,
  });

  final bool bottomSelected;
  final bool drawerSelected;
  final VoidCallback onBottomTap;
  final VoidCallback onDrawerTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.82),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.all(5),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _ToggleOption(
                    label: 'Bottom nav bar',
                    selected: bottomSelected,
                    onTap: onBottomTap,
                  ),
                ),
                Expanded(
                  child: _ToggleOption(
                    label: 'Drawer menu',
                    selected: drawerSelected,
                    onTap: onDrawerTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,

              color: selected ? scheme.primary : scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
