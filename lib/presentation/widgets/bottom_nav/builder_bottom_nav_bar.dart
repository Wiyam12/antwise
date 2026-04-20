import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/domain/entities/builder_page_entity.dart';
import 'package:antwise/domain/entities/bottom_nav_layout_type.dart';
import 'package:flutter/material.dart';

const double _kBottomNavLabelFontSize = 10;

/// Bottom navigation for the builder shell: layout follows [BottomNavLayoutType].
class BuilderBottomNavBar extends StatelessWidget {
  const BuilderBottomNavBar({
    super.key,
    required this.pages,
    required this.layout,
    required this.centerPageId,
    required this.selectedPageId,
    required this.onSelectPage,
    required this.showLabels,
  });

  final List<BuilderPageEntity> pages;
  final BottomNavLayoutType layout;
  final String? centerPageId;

  /// Resolved selection; must match one of [pages] when possible.
  final String? selectedPageId;
  final ValueChanged<String> onSelectPage;

  /// When false, only icons are shown (no text under items).
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    if (pages.length < 2) {
      return const SizedBox.shrink();
    }
    switch (layout) {
      case BottomNavLayoutType.standard:
        return _StandardBar(
          pages: pages,
          selectedPageId: selectedPageId,
          onSelectPage: onSelectPage,
          showLabels: showLabels,
        );
      case BottomNavLayoutType.centerIconEmphasis:
        return _CenterEmphasisBar(
          pages: pages,
          selectedPageId: selectedPageId,
          onSelectPage: onSelectPage,
          showLabels: showLabels,
        );
      case BottomNavLayoutType.floatingCenterAction:
        return _FloatingCenterBar(
          pages: pages,
          centerPageId: _resolvedFloatingCenterId(),
          selectedPageId: selectedPageId,
          onSelectPage: onSelectPage,
          showLabels: showLabels,
        );
    }
  }

  String? _resolvedFloatingCenterId() {
    if (centerPageId != null &&
        pages.any((BuilderPageEntity p) => p.id == centerPageId)) {
      return centerPageId;
    }
    if (pages.isEmpty) {
      return null;
    }
    return pages[pages.length ~/ 2].id;
  }

  static String shortLabel(String name) {
    if (name.length <= 12) {
      return name;
    }
    return '${name.substring(0, 10)}…';
  }
}

class _StandardBar extends StatelessWidget {
  const _StandardBar({
    required this.pages,
    required this.selectedPageId,
    required this.onSelectPage,
    required this.showLabels,
  });

  final List<BuilderPageEntity> pages;
  final String? selectedPageId;
  final ValueChanged<String> onSelectPage;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int selectedIndex = _indexOfSelected();
    final int maxIndex = pages.length - 1;
    final NavigationDestinationLabelBehavior labelBehavior =
        showLabels
            ? NavigationDestinationLabelBehavior.alwaysShow
            : NavigationDestinationLabelBehavior.alwaysHide;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Material(
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shadowColor: Colors.black26,
          color: scheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(100)),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: Colors.transparent,
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((
                Set<WidgetState> states,
              ) {
                final TextStyle base =
                    Theme.of(context).textTheme.labelMedium ??
                    const TextStyle();
                final bool isSelected = states.contains(WidgetState.selected);
                return base.copyWith(
                  fontSize: _kBottomNavLabelFontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                );
              }),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              labelBehavior: labelBehavior,
              selectedIndex: selectedIndex.clamp(0, maxIndex),
              onDestinationSelected: (int i) {
                if (i >= 0 && i < pages.length) {
                  onSelectPage(pages[i].id);
                }
              },
              destinations: <Widget>[
                for (final BuilderPageEntity p in pages)
                  NavigationDestination(
                    icon: Icon(
                      AppIconRegistry.iconOf(p.iconName),
                      color: scheme.onSurfaceVariant,
                      size: 30,
                    ),
                    selectedIcon: Icon(
                      AppIconRegistry.iconOf(p.iconName),
                      color: scheme.primary,
                      size: 30,
                    ),
                    label:
                        showLabels
                            ? BuilderBottomNavBar.shortLabel(p.name)
                            : '',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _indexOfSelected() {
    final String? id = selectedPageId;
    if (id == null) {
      return 0;
    }
    final int i = pages.indexWhere((BuilderPageEntity p) => p.id == id);
    return i >= 0 ? i : 0;
  }
}

class _CenterEmphasisBar extends StatelessWidget {
  const _CenterEmphasisBar({
    required this.pages,
    required this.selectedPageId,
    required this.onSelectPage,
    required this.showLabels,
  });

  final List<BuilderPageEntity> pages;
  final String? selectedPageId;
  final ValueChanged<String> onSelectPage;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Material(
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          shadowColor: Colors.black26,
          color: scheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(100)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
            child: Row(
              children:
                  pages.map((BuilderPageEntity p) {
                    final bool isSelected = selectedPageId == p.id;
                    final Color active = scheme.primary;
                    final Color inactive = scheme.onSurfaceVariant;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          onTap: () => onSelectPage(p.id),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(
                              vertical: showLabels ? 6 : 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? scheme.primaryContainer.withValues(
                                        alpha: 0.55,
                                      )
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: scheme.primary.withValues(
                                          alpha: 0.35,
                                        ),
                                      )
                                      : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  AppIconRegistry.iconOf(p.iconName),
                                  size: 30,
                                  color: isSelected ? active : inactive,
                                ),
                                if (showLabels) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    BuilderBottomNavBar.shortLabel(p.name),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: _kBottomNavLabelFontSize,
                                      color: isSelected ? active : inactive,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingCenterBar extends StatelessWidget {
  const _FloatingCenterBar({
    required this.pages,
    required this.centerPageId,
    required this.selectedPageId,
    required this.onSelectPage,
    required this.showLabels,
  });

  final List<BuilderPageEntity> pages;
  final String? centerPageId;
  final String? selectedPageId;
  final ValueChanged<String> onSelectPage;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int? centerIndex = _centerIndex();
    if (centerIndex == null) {
      return _StandardBar(
        pages: pages,
        selectedPageId: selectedPageId,
        onSelectPage: onSelectPage,
        showLabels: showLabels,
      );
    }
    final List<BuilderPageEntity> left = pages.sublist(0, centerIndex);
    final BuilderPageEntity center = pages[centerIndex];
    final List<BuilderPageEntity> right = pages.sublist(centerIndex + 1);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: SizedBox(
          height: showLabels ? 88 : 78,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: <Widget>[
              Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  clipBehavior: Clip.antiAlias,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  color: scheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                    child: Row(
                      children: <Widget>[
                        ...left.map(
                          (BuilderPageEntity p) => Expanded(
                            child: _CompactNavItem(
                              page: p,
                              selected: selectedPageId == p.id,
                              showLabels: showLabels,
                              onTap: () => onSelectPage(p.id),
                            ),
                          ),
                        ),
                        const SizedBox(width: 64),
                        ...right.map(
                          (BuilderPageEntity p) => Expanded(
                            child: _CompactNavItem(
                              page: p,
                              selected: selectedPageId == p.id,
                              showLabels: showLabels,
                              onTap: () => onSelectPage(p.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: showLabels ? 28 : 22,
                left: 0,
                right: 0,
                child: Center(
                  child: Material(
                    elevation: 6,
                    shadowColor: Colors.black38,
                    shape: const CircleBorder(),
                    color: scheme.primary,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onSelectPage(center.id),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(
                          AppIconRegistry.iconOf(center.iconName),
                          color: scheme.onPrimary,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? _centerIndex() {
    if (centerPageId == null) {
      return null;
    }
    final int i = pages.indexWhere(
      (BuilderPageEntity p) => p.id == centerPageId,
    );
    return i >= 0 ? i : null;
  }
}

class _CompactNavItem extends StatelessWidget {
  const _CompactNavItem({
    required this.page,
    required this.selected,
    required this.showLabels,
    required this.onTap,
  });

  final BuilderPageEntity page;
  final bool selected;
  final bool showLabels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color active = scheme.primary;
    final Color inactive = scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: showLabels ? 4 : 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              AppIconRegistry.iconOf(page.iconName),
              size: 30,
              color: selected ? active : inactive,
            ),
            if (showLabels) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                BuilderBottomNavBar.shortLabel(page.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: _kBottomNavLabelFontSize,
                  color: selected ? active : inactive,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
