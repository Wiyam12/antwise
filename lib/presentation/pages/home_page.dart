import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/core/constants/app_constants.dart';
import 'package:antwise/core/theme/app_text_styles.dart';
import 'package:antwise/core/widgets/app_loading.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/drawer_nav_layout_type.dart';
import 'package:antwise/presentation/controllers/home_controller.dart';
import 'package:antwise/presentation/routes/app_routes.dart';
import 'package:antwise/presentation/widgets/bottom_nav/builder_bottom_nav_bar.dart';
import 'package:antwise/presentation/widgets/dynamic_builder_page_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

const double _kDrawerItemFontSize = 12;

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  Widget _aiFab() {
    return FloatingActionButton(
      onPressed: () => controller.openAiSupport(),
      tooltip: 'AI support',
      child: const Icon(Icons.smart_toy_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.pages;
      controller.selectedPageId.value;
      controller.builderContentRevision.value;
      controller.bottomNavLayout.value;
      controller.bottomNavCenterPageId.value;
      controller.bottomNavShowLabels.value;
      controller.drawerNavLayout.value;
      controller.accountNames.length;
      final bool isSetupMode = controller.shouldShowSetupMode;
      final bool hasExistingAccounts = controller.accountNames.isNotEmpty;
      if (controller.isLoading.value) {
        return Scaffold(
          appBar: _buildAppBar(
            context,
            showCreateAction: true,
            isSetupMode: isSetupMode,
            hasExistingAccounts: hasExistingAccounts,
          ),
          floatingActionButton: _aiFab(),
          body: const Center(child: AppLoading()),
        );
      }
      if (isSetupMode) {
        return Scaffold(
          appBar: _buildAppBar(
            context,
            showCreateAction: false,
            isSetupMode: true,
            hasExistingAccounts: hasExistingAccounts,
          ),
          floatingActionButton: _aiFab(),
          body: _SetupModeBody(
            isApplyingTemplate: controller.isApplyingSetupTemplate.value,
            onIsAccountNameUnique: controller.isAccountNameUnique,
            onSelectSimplePos: controller.applySimplePosTemplate,
            onSelectAdvance: controller.chooseAdvanceMode,
          ),
        );
      }
      if (!controller.hasPages) {
        return Scaffold(
          appBar: _buildAppBar(
            context,
            showCreateAction: true,
            isSetupMode: false,
            hasExistingAccounts: hasExistingAccounts,
          ),
          floatingActionButton: _aiFab(),
          body: _EmptyBuilderBody(onCreate: controller.openCreateHub),
        );
      }
      return _BuilderShell(controller: controller);
    });
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    required bool showCreateAction,
    required bool isSetupMode,
    required bool hasExistingAccounts,
  }) {
    final bool showSwitchAccountAction = isSetupMode && hasExistingAccounts;
    final bool showSettingsAction = !isSetupMode && hasExistingAccounts;
    return AppBar(
      title: const Text(AppConstants.appName),
      actions: <Widget>[
        if (showCreateAction)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create',
            onPressed: controller.openCreateHub,
          ),
        if (showSwitchAccountAction)
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Account',
            onPressed: () => _openAccountSelector(context),
          ),
        if (showSettingsAction)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: controller.openSettings,
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Future<void> _openAccountSelector(BuildContext context) async {
    final ThemeData theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Stack(
          children: <Widget>[
            Positioned(
              top:
                  kToolbarHeight + MediaQuery.of(dialogContext).padding.top + 8,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Card(
                    elevation: 10,
                    margin: EdgeInsets.zero,
                    child: SizedBox(
                      width: 320,
                      height: 360,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Accounts',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Obx(
                                () => ListView.separated(
                                  itemCount: controller.accountNames.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, int index) {
                                    final String accountName =
                                        controller.accountNames[index];
                                    final bool isActive =
                                        accountName ==
                                        controller.activeAccountName.value;
                                    return _accountCard(
                                      icon: Icons.business_outlined,
                                      title: accountName,
                                      isActive: isActive,
                                      onTap: () async {
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                        }
                                        await controller.switchAccount(
                                          accountName,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _accountCard(
                              icon: Icons.add_circle_outline,
                              title: 'Create New Account',
                              isActive: false,
                              leadingPrefix: '+ ',
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                Get.offAllNamed<void>(
                                  AppRoutes.home,
                                  arguments: <String, dynamic>{
                                    'forceSetupMode': true,
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _accountCard({
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
    String leadingPrefix = '',
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text('$leadingPrefix$title'),
        trailing:
            isActive
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _EmptyBuilderBody extends StatelessWidget {
  const _EmptyBuilderBody({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.dashboard_customize_outlined,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 20),
            Text(
              'No pages yet',
              style: AppTextStyles.emptyStateTitle(theme.textTheme),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first page to start building. Navigation will appear automatically from your choices.',
              style: AppTextStyles.emptyStateBody(theme.textTheme),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Page'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupModeBody extends StatelessWidget {
  const _SetupModeBody({
    required this.isApplyingTemplate,
    required this.onIsAccountNameUnique,
    required this.onSelectSimplePos,
    required this.onSelectAdvance,
  });

  final bool isApplyingTemplate;
  final bool Function(String accountName) onIsAccountNameUnique;
  final Future<void> Function({required String accountName}) onSelectSimplePos;
  final Future<void> Function({required String accountName}) onSelectAdvance;

  @override
  Widget build(BuildContext context) {
    return _SetupModeSelector(
      isApplyingTemplate: isApplyingTemplate,
      onIsAccountNameUnique: onIsAccountNameUnique,
      onSelectSimplePos: onSelectSimplePos,
      onSelectAdvance: onSelectAdvance,
    );
  }
}

enum _SetupModeChoice { simplePos, advance }

class _SetupModeSelector extends StatefulWidget {
  const _SetupModeSelector({
    required this.isApplyingTemplate,
    required this.onIsAccountNameUnique,
    required this.onSelectSimplePos,
    required this.onSelectAdvance,
  });

  final bool isApplyingTemplate;
  final bool Function(String accountName) onIsAccountNameUnique;
  final Future<void> Function({required String accountName}) onSelectSimplePos;
  final Future<void> Function({required String accountName}) onSelectAdvance;

  @override
  State<_SetupModeSelector> createState() => _SetupModeSelectorState();
}

class _SetupModeSelectorState extends State<_SetupModeSelector> {
  _SetupModeChoice? _selected;
  final TextEditingController _accountNameController = TextEditingController();
  String? _accountNameError;

  bool get _isAccountNameValid =>
      _accountNameError == null &&
      _accountNameController.text.trim().isNotEmpty;

  Future<void> _proceed() async {
    final String accountName = _accountNameController.text.trim();
    _validateAccountName(accountName);
    if (_selected == null ||
        widget.isApplyingTemplate ||
        !_isAccountNameValid) {
      return;
    }
    if (_selected == _SetupModeChoice.simplePos) {
      await widget.onSelectSimplePos(accountName: accountName);
      return;
    }
    await widget.onSelectAdvance(accountName: accountName);
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    super.dispose();
  }

  void _validateAccountName(String value) {
    final String trimmed = value.trim();
    String? error;
    if (trimmed.isEmpty) {
      error = 'Account name is required';
    } else if (!widget.onIsAccountNameUnique(trimmed)) {
      error = 'Account name already exists';
    }
    if (mounted) {
      setState(() {
        _accountNameError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Choose a Setup Mode',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _accountNameController,
            enabled: !widget.isApplyingTemplate,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Account Name',
              hintText: 'e.g. My workspace',
              errorText: _accountNameError,
              border: const OutlineInputBorder(),
            ),
            onChanged: _validateAccountName,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _setupModeCard(
                              context: context,
                              title: 'Simple POS Template',
                              subtitle:
                                  'Create a simple POS system from starter snapshot',
                              svgAssetPath: 'assets/svg/pos.svg',
                              highlighted: true,
                              selected: _selected == _SetupModeChoice.simplePos,
                              enabled: !widget.isApplyingTemplate,
                              onTap:
                                  () => setState(
                                    () =>
                                        _selected = _SetupModeChoice.simplePos,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _setupModeCard(
                              context: context,
                              title: 'Advance Mode',
                              subtitle:
                                  'Start blank and build everything manually',
                              svgAssetPath: 'assets/svg/building-blocks.svg',
                              highlighted: false,
                              selected: _selected == _SetupModeChoice.advance,
                              enabled: !widget.isApplyingTemplate,
                              onTap:
                                  () => setState(
                                    () => _selected = _SetupModeChoice.advance,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed:
                  (_selected == null ||
                          widget.isApplyingTemplate ||
                          !_isAccountNameValid)
                      ? null
                      : _proceed,
              child: const Text('Proceed'),
            ),
          ),
          const SizedBox(height: 25),
          if (widget.isApplyingTemplate)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _setupModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    String? svgAssetPath,
    IconData? icon,
    required bool highlighted,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    assert(
      (svgAssetPath != null) ^ (icon != null),
      'Provide exactly one of svgAssetPath or icon',
    );
    final ThemeData theme = Theme.of(context);
    final Color bg =
        selected
            ? (highlighted
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.secondaryContainer)
            : (highlighted
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.75)
                : theme.colorScheme.surfaceContainerLow);
    final Color fg = theme.colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient:
            selected
                ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF47D1E8), Color(0xFF5B6DFF)],
                )
                : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(selected ? 3 : 0),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color:
                  selected
                      ? Colors.transparent
                      : theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.25,
                      ),
            ),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (svgAssetPath != null)
                    SvgPicture.asset(svgAssetPath, width: 74, height: 74)
                  else
                    Icon(icon!, size: 74, color: fg),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BuilderShell extends StatelessWidget {
  const _BuilderShell({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BuilderPageEntity? page = controller.selectedPage;
    final bool hasExistingAccounts = controller.accountNames.isNotEmpty;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.openAiSupport(),
        tooltip: 'AI support',
        child: const Icon(Icons.smart_toy_outlined),
      ),
      appBar: AppBar(
        title: Text(
          page?.name ?? AppConstants.appName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create',
            onPressed: controller.openCreateHub,
          ),

          if (controller.shouldShowSetupMode && hasExistingAccounts)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch Account',
              onPressed: controller.openAccountSwitcher,
            ),
          if (hasExistingAccounts)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: controller.openSettings,
            ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: controller.shouldShowDrawer ? _buildDrawer(context, theme) : null,
      bottomNavigationBar:
          controller.shouldShowBottomNav
              ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme.copyWith(
                      primary: _resolvedMainColor(theme),
                    ),
                  ),
                  child: BuilderBottomNavBar(
                    key: ValueKey<String>(
                      '${controller.bottomNavLayout.value.name}-'
                      '${controller.bottomNavCenterPageId.value ?? 'none'}-'
                      '${controller.bottomNavShowLabels.value}',
                    ),
                    pages: controller.bottomPages,
                    layout: controller.bottomNavLayout.value,
                    centerPageId: controller.bottomNavCenterPageId.value,
                    selectedPageId: controller.selectedPageId.value,
                    onSelectPage: controller.selectPage,
                    showLabels: controller.bottomNavShowLabels.value,
                  ),
                ),
              )
              : null,
      body:
          page == null
              ? const Center(child: Text('Select a page'))
              : DynamicBuilderPageBody(
                key: ValueKey<String>(page.id),
                page: page,
                contentRevision: controller.builderContentRevision.value,
              ),
    );
  }

  Drawer _buildDrawer(BuildContext context, ThemeData theme) {
    final List<BuilderPageEntity> drawerPages = controller.drawerPages;
    final Map<String, BuilderPageEntity> byId = <String, BuilderPageEntity>{
      for (final BuilderPageEntity page in drawerPages) page.id: page,
    };
    final Map<String, List<BuilderPageEntity>> childrenByParent =
        <String, List<BuilderPageEntity>>{};
    for (final BuilderPageEntity page in drawerPages) {
      final String? parentId = page.parentPageId;
      if (parentId == null ||
          parentId == page.id ||
          !byId.containsKey(parentId)) {
        continue;
      }
      childrenByParent
          .putIfAbsent(parentId, () => <BuilderPageEntity>[])
          .add(page);
    }
    final List<BuilderPageEntity> topLevelPages = drawerPages
        .where((BuilderPageEntity page) {
          final String? parentId = page.parentPageId;
          return parentId == null ||
              parentId == page.id ||
              !byId.containsKey(parentId);
        })
        .toList(growable: false);

    final DrawerNavLayoutType layout = controller.drawerNavLayout.value;
    final bool themedBackground = layout == DrawerNavLayoutType.themeBackground;
    return Drawer(
      backgroundColor: themedBackground ? _themeBackgroundBase(theme) : null,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color:
                    themedBackground
                        ? _themeBackgroundActiveColor(
                          _themeBackgroundBase(theme),
                        )
                        : theme.colorScheme.primaryContainer,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  AppConstants.appName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color:
                        themedBackground
                            ? Colors.white
                            : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            ...topLevelPages.map(
              (BuilderPageEntity page) => _drawerTreeNode(
                context,
                theme,
                page,
                childrenByParent,
                depth: 0,
                trail: <String>{},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTreeNode(
    BuildContext context,
    ThemeData theme,
    BuilderPageEntity page,
    Map<String, List<BuilderPageEntity>> childrenByParent, {
    required int depth,
    required Set<String> trail,
  }) {
    if (trail.contains(page.id)) {
      return _drawerLeafTile(context, theme, page, depth: depth);
    }
    final List<BuilderPageEntity> children =
        childrenByParent[page.id] ?? <BuilderPageEntity>[];
    if (children.isEmpty) {
      return _drawerLeafTile(context, theme, page, depth: depth);
    }
    final bool selectedDescendant = _hasSelectedDescendant(
      page.id,
      childrenByParent,
      <String>{},
    );
    final Set<String> nextTrail = <String>{...trail, page.id};
    final bool isSelected = controller.selectedPageId.value == page.id;
    final DrawerNavLayoutType layout = controller.drawerNavLayout.value;

    return Padding(
      padding: _parentTilePadding(layout, depth),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isSelected || selectedDescendant,
          leading: Icon(
            AppIconRegistry.iconOf(page.iconName),
            color: _tileForeground(theme, layout, isSelected),
          ),
          title: Text(
            page.name,
            style:
                layout == DrawerNavLayoutType.pillGradient ||
                        layout == DrawerNavLayoutType.themeBackground
                    ? TextStyle(
                      fontSize: _kDrawerItemFontSize,
                      color:
                          isSelected
                              ? Colors.white
                              : layout == DrawerNavLayoutType.themeBackground
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    )
                    : theme.textTheme.titleMedium?.copyWith(
                      fontSize: _kDrawerItemFontSize,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
          ),
          backgroundColor: _tileBackground(theme, layout, isSelected),
          collapsedBackgroundColor: _tileBackground(theme, layout, isSelected),
          iconColor: _tileForeground(theme, layout, isSelected),
          collapsedIconColor: _tileForeground(theme, layout, isSelected),
          textColor: _tileForeground(theme, layout, isSelected),
          collapsedTextColor: _tileForeground(theme, layout, isSelected),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          children: children
              .map(
                (BuilderPageEntity child) => _drawerTreeNode(
                  context,
                  theme,
                  child,
                  childrenByParent,
                  depth: depth + 1,
                  trail: nextTrail,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _drawerLeafTile(
    BuildContext context,
    ThemeData theme,
    BuilderPageEntity page, {
    required int depth,
  }) {
    final bool isSelected = controller.selectedPageId.value == page.id;
    final DrawerNavLayoutType layout = controller.drawerNavLayout.value;
    final EdgeInsets depthPadding = EdgeInsets.only(left: depth * 12.0);
    switch (layout) {
      case DrawerNavLayoutType.classicList:
        return Padding(
          padding: depthPadding,
          child: ListTile(
            leading: Icon(AppIconRegistry.iconOf(page.iconName)),
            title: Text(
              page.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: _kDrawerItemFontSize,
              ),
            ),
            selected: isSelected,
            onTap: () {
              Navigator.of(context).maybePop();
              controller.selectPage(page.id);
            },
          ),
        );
      case DrawerNavLayoutType.softCard:
        return Padding(
          padding: EdgeInsets.only(
            left: 8 + depthPadding.left,
            right: 8,
            top: 2,
            bottom: 2,
          ),
          child: ListTile(
            leading: Icon(AppIconRegistry.iconOf(page.iconName)),
            title: Text(
              page.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: _kDrawerItemFontSize,
              ),
            ),
            selected: isSelected,
            selectedTileColor: theme.colorScheme.secondaryContainer.withValues(
              alpha: 0.55,
            ),
            selectedColor: theme.colorScheme.onSecondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () {
              Navigator.of(context).maybePop();
              controller.selectPage(page.id);
            },
          ),
        );
      case DrawerNavLayoutType.pillGradient:
        return Padding(
          padding: EdgeInsets.only(
            left: 12 + depthPadding.left,
            right: 12,
            top: 4,
            bottom: 4,
          ),
          child: Material(
            borderRadius: BorderRadius.circular(14),
            color: isSelected ? Colors.transparent : Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient:
                    isSelected
                        ? LinearGradient(
                          colors: <Color>[
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.78),
                          ],
                        )
                        : null,
              ),
              child: ListTile(
                leading: Icon(
                  AppIconRegistry.iconOf(page.iconName),
                  color:
                      isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  page.name,
                  style: TextStyle(
                    fontSize: _kDrawerItemFontSize,
                    color:
                        isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () {
                  Navigator.of(context).maybePop();
                  controller.selectPage(page.id);
                },
              ),
            ),
          ),
        );
      case DrawerNavLayoutType.themeBackground:
        return Padding(
          padding: EdgeInsets.only(
            left: 8 + depthPadding.left,
            right: 8,
            top: 3,
            bottom: 3,
          ),
          child: ListTile(
            leading: Icon(
              AppIconRegistry.iconOf(page.iconName),
              color: isSelected ? Colors.white : Colors.white,
            ),
            title: Text(
              page.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: _kDrawerItemFontSize,
                color: isSelected ? Colors.white : Colors.white,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            selected: isSelected,
            selectedTileColor: _themeBackgroundActiveColor(
              _themeBackgroundBase(theme),
            ),
            selectedColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () {
              Navigator.of(context).maybePop();
              controller.selectPage(page.id);
            },
          ),
        );
    }
  }

  bool _hasSelectedDescendant(
    String parentId,
    Map<String, List<BuilderPageEntity>> childrenByParent,
    Set<String> trail,
  ) {
    if (trail.contains(parentId)) {
      return false;
    }
    final String? selectedId = controller.selectedPageId.value;
    final List<BuilderPageEntity> children =
        childrenByParent[parentId] ?? <BuilderPageEntity>[];
    final Set<String> nextTrail = <String>{...trail, parentId};
    for (final BuilderPageEntity child in children) {
      if (child.id == selectedId) {
        return true;
      }
      if (_hasSelectedDescendant(child.id, childrenByParent, nextTrail)) {
        return true;
      }
    }
    return false;
  }

  Color? _tileBackground(
    ThemeData theme,
    DrawerNavLayoutType layout,
    bool isSelected,
  ) {
    switch (layout) {
      case DrawerNavLayoutType.classicList:
        return null;
      case DrawerNavLayoutType.softCard:
        return isSelected
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.1)
            : null;
      case DrawerNavLayoutType.pillGradient:
        return isSelected ? theme.colorScheme.primary : null;
      case DrawerNavLayoutType.themeBackground:
        return isSelected
            ? _themeBackgroundActiveColor(_themeBackgroundBase(theme))
            : Colors.white.withValues(alpha: 0.06);
    }
  }

  Color _tileForeground(
    ThemeData theme,
    DrawerNavLayoutType layout,
    bool isSelected,
  ) {
    switch (layout) {
      case DrawerNavLayoutType.classicList:
        return isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface;
      case DrawerNavLayoutType.softCard:
        return isSelected
            ? theme.colorScheme.onSecondaryContainer
            : theme.colorScheme.onSurface;
      case DrawerNavLayoutType.pillGradient:
        return isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface;
      case DrawerNavLayoutType.themeBackground:
        return Colors.white;
    }
  }

  EdgeInsets _parentTilePadding(DrawerNavLayoutType layout, int depth) {
    final double depthLeft = depth * 12.0;
    switch (layout) {
      case DrawerNavLayoutType.classicList:
        return EdgeInsets.only(left: depthLeft);
      case DrawerNavLayoutType.softCard:
        return EdgeInsets.only(
          left: 8 + depthLeft,
          right: 8,
          top: 2,
          bottom: 2,
        );
      case DrawerNavLayoutType.pillGradient:
        return EdgeInsets.only(
          left: 12 + depthLeft,
          right: 12,
          top: 4,
          bottom: 4,
        );
      case DrawerNavLayoutType.themeBackground:
        return EdgeInsets.only(
          left: 8 + depthLeft,
          right: 8,
          top: 3,
          bottom: 3,
        );
    }
  }
}

Color _themeBackgroundBase(ThemeData theme) {
  return theme.colorScheme.primary;
}

Color _themeBackgroundActiveColor(Color base) {
  return Color.alphaBlend(Colors.white.withValues(alpha: 0.26), base);
}

Color _resolvedMainColor(ThemeData theme) {
  final Color base = theme.colorScheme.primary;
  if (theme.brightness != Brightness.dark) {
    return base;
  }
  return Color.alphaBlend(Colors.white.withValues(alpha: 0.50), base);
}
