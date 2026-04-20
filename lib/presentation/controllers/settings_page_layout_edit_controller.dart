import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/builder_widget_entity.dart';
import 'package:antwise/domain/entities/table_schema_entity.dart';
import 'package:antwise/domain/usecases/get_all_builder_widgets_usecase.dart';
import 'package:antwise/domain/usecases/get_all_table_schemas_usecase.dart';
import 'package:antwise/domain/usecases/get_builder_pages_usecase.dart';
import 'package:antwise/domain/usecases/replace_builder_pages_usecase.dart';
import 'package:antwise/presentation/controllers/home_controller.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:get/get.dart';

class PageLayoutComponent {
  const PageLayoutComponent({
    required this.key,
    required this.label,
    this.tableId,
    this.widgetId,
  });

  final String key;
  final String label;
  final String? tableId;
  final String? widgetId;
}

class SettingsPageLayoutEditController extends GetxController {
  SettingsPageLayoutEditController(
    this._getPages,
    this._replacePages,
    this._getSchemas,
    this._getWidgets,
  );

  static const String widgetsKey = 'widgets';
  static String tableKey(String tableId) => 'table:$tableId';
  static String chartKey(String widgetId) => 'chart:$widgetId';

  final GetBuilderPagesUseCase _getPages;
  final ReplaceBuilderPagesUseCase _replacePages;
  final GetAllTableSchemasUseCase _getSchemas;
  final GetAllBuilderWidgetsUseCase _getWidgets;

  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final Rxn<BuilderPageEntity> page = Rxn<BuilderPageEntity>();
  final RxInt widgetGridCount = 1.obs;
  final RxList<PageLayoutComponent> components = <PageLayoutComponent>[].obs;
  final RxList<BuilderWidgetEntity> widgetCards = <BuilderWidgetEntity>[].obs;
  final RxnString draggingWidgetId = RxnString();

  String? _pageId;
  List<BuilderPageEntity> _allPages = <BuilderPageEntity>[];
  List<String>? _dragStartOrderIds;
  bool _dropAcceptedInCurrentDrag = false;

  @override
  void onInit() {
    super.onInit();
    _pageId = Get.arguments?.toString();
    load();
  }

  Future<void> load() async {
    final String? pageId = _pageId;
    if (pageId == null || pageId.isEmpty) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    try {
      _allPages = await _getPages();
      BuilderPageEntity? target;
      for (final BuilderPageEntity p in _allPages) {
        if (p.id == pageId) {
          target = p;
          break;
        }
      }
      page.value = target;
      if (target == null) {
        return;
      }
      final BuilderPageEntity targetPage = target;
      widgetGridCount.value = targetPage.widgetGridCount.clamp(1, 3);
      final List<TableSchemaEntity> allSchemas = await _getSchemas();
      final List<BuilderWidgetEntity> allWidgets = await _getWidgets();
      final List<BuilderWidgetEntity> pageCards = allWidgets
          .where((BuilderWidgetEntity w) => w.pageId == targetPage.id && w.type == 'card')
          .toList(growable: false);
      widgetCards.assignAll(_orderCards(pageCards, targetPage.widgetOrder));
      final List<BuilderWidgetEntity> pageCharts = allWidgets
          .where((BuilderWidgetEntity w) => w.pageId == targetPage.id && w.type == 'chart')
          .toList(growable: false)
        ..sort(
          (BuilderWidgetEntity a, BuilderWidgetEntity b) =>
              _widgetDisplayOrder(a).compareTo(_widgetDisplayOrder(b)),
        );
      final List<TableSchemaEntity> pageTables = allSchemas
          .where((TableSchemaEntity s) => s.pageId == targetPage.id)
          .toList(growable: false);
      final Set<String> tableIdsWithWidget = allWidgets
          .where((BuilderWidgetEntity w) => w.pageId == targetPage.id && w.type == 'table')
          .map((BuilderWidgetEntity w) => w.config['tableId']?.toString() ?? '')
          .where((String id) => id.isNotEmpty)
          .toSet();
      final Set<String> availableKeys = <String>{widgetsKey};
      final List<PageLayoutComponent> available = <PageLayoutComponent>[
        const PageLayoutComponent(key: widgetsKey, label: 'Widgets'),
      ];
      for (final BuilderWidgetEntity chart in pageCharts) {
        final String title =
            chart.config['title']?.toString().trim().isNotEmpty == true
                ? chart.config['title'].toString().trim()
                : 'Chart widget';
        available.add(
          PageLayoutComponent(
            key: chartKey(chart.id),
            label: title,
            widgetId: chart.id,
          ),
        );
      }
      for (final TableSchemaEntity table in pageTables) {
        if (tableIdsWithWidget.isNotEmpty && !tableIdsWithWidget.contains(table.id)) {
          continue;
        }
        final String key = tableKey(table.id);
        availableKeys.add(key);
        available.add(
          PageLayoutComponent(key: key, label: table.name, tableId: table.id),
        );
      }

      final Map<String, PageLayoutComponent> byKey = <String, PageLayoutComponent>{
        for (final PageLayoutComponent c in available) c.key: c,
      };
      final List<PageLayoutComponent> ordered = <PageLayoutComponent>[];
      for (final String key in targetPage.layoutOrder) {
        final PageLayoutComponent? comp = byKey.remove(key);
        if (comp != null) {
          ordered.add(comp);
        }
      }
      ordered.addAll(byKey.values);
      components.assignAll(ordered);
    } finally {
      isLoading.value = false;
    }
  }

  void setWidgetGridCount(int count) {
    widgetGridCount.value = count.clamp(1, 3);
  }

  void reorder(int oldIndex, int newIndex) {
    final List<PageLayoutComponent> current = components.toList(growable: true);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final PageLayoutComponent moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    components.assignAll(current);
  }

  void moveWidgetCard(String draggedId, String targetId) {
    if (draggedId == targetId) {
      return;
    }
    final List<BuilderWidgetEntity> current = widgetCards.toList(growable: true);
    final int from = current.indexWhere((BuilderWidgetEntity w) => w.id == draggedId);
    final int to = current.indexWhere((BuilderWidgetEntity w) => w.id == targetId);
    if (from < 0 || to < 0) {
      return;
    }
    final BuilderWidgetEntity moved = current.removeAt(from);
    current.insert(to, moved);
    widgetCards.assignAll(current);
  }

  Future<void> reorderWidgetCards(int oldIndex, int newIndex) async {
    final List<BuilderWidgetEntity> current = widgetCards.toList(growable: true);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 ||
        oldIndex >= current.length ||
        newIndex < 0 ||
        newIndex > current.length) {
      return;
    }
    final BuilderWidgetEntity moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    widgetCards.assignAll(current);
    _syncDraftPageWidgetOrder();
    await _persistWidgetOrderImmediately();
  }

  Future<void> reorderCardsPreview(int oldIndex, int newIndex) async {
    await reorderWidgetCards(oldIndex, newIndex);
  }

  Future<void> reorderWidgetCardsById(String draggedId, String targetId) async {
    if (draggedId == targetId) {
      return;
    }
    final List<BuilderWidgetEntity> current = widgetCards.toList(growable: true);
    final int oldIndex = current.indexWhere((BuilderWidgetEntity w) => w.id == draggedId);
    final int targetIndex = current.indexWhere((BuilderWidgetEntity w) => w.id == targetId);
    if (oldIndex < 0 || targetIndex < 0) {
      return;
    }
    final BuilderWidgetEntity moved = current.removeAt(oldIndex);
    final int insertIndex = oldIndex < targetIndex ? targetIndex - 1 : targetIndex;
    current.insert(insertIndex, moved);
    widgetCards.assignAll(current);
    _syncDraftPageWidgetOrder();
    await _persistWidgetOrderImmediately();
  }

  void startWidgetDrag(String widgetId) {
    draggingWidgetId.value = widgetId;
    _dropAcceptedInCurrentDrag = false;
    _dragStartOrderIds = widgetCards
        .map((BuilderWidgetEntity w) => w.id)
        .toList(growable: false);
  }

  void previewWidgetHover(String targetId) {
    final String? draggedId = draggingWidgetId.value;
    if (draggedId == null || draggedId == targetId) {
      return;
    }
    final List<BuilderWidgetEntity> current = widgetCards.toList(growable: true);
    final int from = current.indexWhere((BuilderWidgetEntity w) => w.id == draggedId);
    final int to = current.indexWhere((BuilderWidgetEntity w) => w.id == targetId);
    if (from < 0 || to < 0 || from == to) {
      return;
    }
    final BuilderWidgetEntity moved = current.removeAt(from);
    current.insert(to, moved);
    widgetCards.assignAll(current);
  }

  Future<void> acceptWidgetDrop(String targetId) async {
    previewWidgetHover(targetId);
    _dropAcceptedInCurrentDrag = true;
    _syncDraftPageWidgetOrder();
    await _persistWidgetOrderImmediately();
  }

  void finishWidgetDrag({required bool accepted}) {
    final bool shouldKeepDrop = accepted || _dropAcceptedInCurrentDrag;
    if (!shouldKeepDrop && _dragStartOrderIds != null) {
      widgetCards.assignAll(
        _orderCards(widgetCards.toList(growable: false), _dragStartOrderIds!),
      );
    } else {
      _syncDraftPageWidgetOrder();
    }
    draggingWidgetId.value = null;
    _dropAcceptedInCurrentDrag = false;
    _dragStartOrderIds = null;
  }

  void _syncDraftPageWidgetOrder() {
    final BuilderPageEntity? currentPage = page.value;
    if (currentPage == null) {
      return;
    }
    final List<String> orderIds = widgetCards
        .map((BuilderWidgetEntity w) => w.id)
        .toList(growable: false);
    final BuilderPageEntity updated = currentPage.copyWith(widgetOrder: orderIds);
    page.value = updated;
    _allPages = _allPages
        .map((BuilderPageEntity p) => p.id == updated.id ? updated : p)
        .toList(growable: false);
  }

  Future<void> _persistWidgetOrderImmediately() async {
    final BuilderPageEntity? currentPage = page.value;
    if (currentPage == null) {
      return;
    }
    final List<String> orderIds = widgetCards
        .map((BuilderWidgetEntity w) => w.id)
        .toList(growable: false);
    final List<BuilderPageEntity> next = _allPages
        .map((BuilderPageEntity p) {
          if (p.id != currentPage.id) {
            return p;
          }
          return p.copyWith(widgetOrder: orderIds);
        })
        .toList(growable: false);
    _allPages = next;
    await _replacePages(next);
  }

  Future<void> save() async {
    final BuilderPageEntity? target = page.value;
    if (target == null) {
      return;
    }
    isSaving.value = true;
    try {
      final List<String> order =
          components.map((PageLayoutComponent c) => c.key).toList(growable: false);
      final List<BuilderPageEntity> next = _allPages
          .map((BuilderPageEntity p) {
            if (p.id != target.id) {
              return p;
            }
            return p.copyWith(
              widgetGridCount: widgetGridCount.value,
              layoutOrder: order,
              widgetOrder: widgetCards
                  .map((BuilderWidgetEntity w) => w.id)
                  .toList(growable: false),
            );
          })
          .toList(growable: false);
      await _replacePages(next);
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().refreshBuilderPageContent();
      }
      showAppSnackbar('Page layout', 'Saved');
      await Get.offAllNamed<void>(
        AppRoutes.home,
        arguments: <String, dynamic>{'selectedPageId': target.id},
      );
    } finally {
      isSaving.value = false;
    }
  }

  static List<BuilderWidgetEntity> _orderCards(
    List<BuilderWidgetEntity> cards,
    List<String> configuredOrder,
  ) {
    final Map<String, BuilderWidgetEntity> byId = <String, BuilderWidgetEntity>{
      for (final BuilderWidgetEntity w in cards) w.id: w,
    };
    final List<BuilderWidgetEntity> out = <BuilderWidgetEntity>[];
    for (final String id in configuredOrder) {
      final BuilderWidgetEntity? w = byId.remove(id);
      if (w != null) {
        out.add(w);
      }
    }
    final List<BuilderWidgetEntity> rest = byId.values.toList(growable: false)
      ..sort(
        (BuilderWidgetEntity a, BuilderWidgetEntity b) =>
            _widgetDisplayOrder(a).compareTo(_widgetDisplayOrder(b)),
      );
    out.addAll(rest);
    return out;
  }

  static int _widgetDisplayOrder(BuilderWidgetEntity w) {
    final dynamic o = w.config['widgetOrder'] ?? w.config['tableOrder'];
    if (o is num) {
      return o.toInt();
    }
    return 1 << 20;
  }
}
