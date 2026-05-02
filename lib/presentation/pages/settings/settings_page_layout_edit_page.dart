import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/presentation/controllers/settings_page_layout_edit_controller.dart';
import 'package:antwise/presentation/widgets/card_widget_grid_layout.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:reorderables/reorderables.dart';

class SettingsPageLayoutEditPage
    extends GetView<SettingsPageLayoutEditController> {
  const SettingsPageLayoutEditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Layout Settings')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Obx(
        () => SizedBox(
          width: 220,
          child: FilledButton(
            onPressed: controller.isSaving.value ? null : controller.save,
            child: const Text('Save Changes'),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final page = controller.page.value;
        if (page == null) {
          return const Center(child: Text('Page not found'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            Text(page.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Layout order', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.components.length,
              onReorder: controller.reorder,
              itemBuilder: (BuildContext context, int index) {
                final c = controller.components[index];
                if (c.key == SettingsPageLayoutEditController.widgetsKey) {
                  final List<BuilderWidgetEntity> cards = controller.widgetCards
                      .toList(growable: false);
                  return Card(
                    key: ValueKey<String>(c.key),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Icons.dashboard_customize_outlined),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Card widgets block',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_indicator),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Card widgets per row',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Obx(() {
                            final int boundedGridCount = controller
                                .widgetGridCount
                                .value
                                .clamp(1, 3);
                            return SegmentedButton<int>(
                              segments: const <ButtonSegment<int>>[
                                ButtonSegment<int>(value: 1, label: Text('1')),
                                ButtonSegment<int>(value: 2, label: Text('2')),
                                ButtonSegment<int>(value: 3, label: Text('3')),
                              ],
                              selected: <int>{boundedGridCount},
                              onSelectionChanged: (Set<int> next) {
                                if (next.isEmpty) {
                                  return;
                                }
                                controller.setWidgetGridCount(next.first);
                              },
                            );
                          }),
                          const SizedBox(height: 10),
                          Obx(
                            () => _buildWidgetsPreviewGrid(
                              cards,
                              controller.widgetGridCount.value.clamp(1, 3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Card(
                  key: ValueKey<String>(c.key),
                  child: ListTile(
                    leading: Icon(
                      c.key.startsWith('chart:')
                          ? Icons.insert_chart_outlined
                          : Icons.table_rows_outlined,
                    ),
                    title: Text(c.label),
                    subtitle:
                        c.key.startsWith('chart:')
                            ? const Text('Chart widget')
                            : const Text('Table section'),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      }),
    );
  }

  Widget _widgetCardFrame(
    String title, {
    IconData icon = Icons.widgets_outlined,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.drag_indicator),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetsPreviewGrid(List<BuilderWidgetEntity> cards, int perRow) {
    if (cards.isEmpty) {
      return const Text('No card widgets in this block.');
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = 8;
        final double fullWidth = constraints.maxWidth;
        final int boundedPerRow = perRow.clamp(1, 3);
        final List<double> slotWidths = computeCardWidgetWrapSlotWidths(
          maxWidth: fullWidth,
          spacing: spacing,
          gridCount: boundedPerRow,
          widgetCount: cards.length,
        );
        return ReorderableWrap(
          spacing: spacing,
          runSpacing: spacing,
          needsLongPressDraggable: true,
          onReorder: (int oldIndex, int newIndex) {
            controller.reorderCardsPreview(oldIndex, newIndex);
          },
          children: cards
              .asMap()
              .entries
              .map((MapEntry<int, BuilderWidgetEntity> e) {
                final int i = e.key;
                final BuilderWidgetEntity card = e.value;
                final double cardWidth = slotWidths[i];
                return SizedBox(
                  key: ValueKey<String>(card.id),
                  width: cardWidth,
                  child: _widgetCardFrame(
                    card.config['title']?.toString().trim().isNotEmpty == true
                        ? card.config['title'].toString().trim()
                        : 'Card widget',
                    icon: Icons.dashboard_customize_outlined,
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}
