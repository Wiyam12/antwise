import 'package:antwise/domain/entities/drawer_nav_layout_type.dart';
import 'package:flutter/material.dart';

class DrawerNavLayoutPicker extends StatelessWidget {
  const DrawerNavLayoutPicker({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final DrawerNavLayoutType selected;
  final ValueChanged<DrawerNavLayoutType> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: cardWidth,
              child: _DrawerLayoutCard(
                title: 'Classic',
                subtitle: 'Clean list menu',
                selected: selected == DrawerNavLayoutType.classicList,
                onTap: () => onSelect(DrawerNavLayoutType.classicList),
                minWidth: cardWidth,
                child: const _MiniClassicDrawerPreview(),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _DrawerLayoutCard(
                title: 'Soft card',
                subtitle: 'Highlighted row',
                selected: selected == DrawerNavLayoutType.softCard,
                onTap: () => onSelect(DrawerNavLayoutType.softCard),
                minWidth: cardWidth,
                child: const _MiniSoftDrawerPreview(),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _DrawerLayoutCard(
                title: 'Pill gradient',
                subtitle: 'Rounded active item',
                selected: selected == DrawerNavLayoutType.pillGradient,
                onTap: () => onSelect(DrawerNavLayoutType.pillGradient),
                minWidth: cardWidth,
                child: const _MiniGradientDrawerPreview(),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _DrawerLayoutCard(
                title: 'Theme bg',
                subtitle: 'Primary drawer surface',
                selected: selected == DrawerNavLayoutType.themeBackground,
                onTap: () => onSelect(DrawerNavLayoutType.themeBackground),
                minWidth: cardWidth,
                child: const _MiniThemeBackgroundDrawerPreview(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DrawerLayoutCard extends StatelessWidget {
  const _DrawerLayoutCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.minWidth,
    required this.child,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth.clamp(120, 400)),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2.2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: 104, child: child),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniClassicDrawerPreview extends StatelessWidget {
  const _MiniClassicDrawerPreview();

  @override
  Widget build(BuildContext context) {
    return _MiniDrawerShell(
      layout: DrawerNavLayoutType.classicList,
      selectedIndex: 0,
    );
  }
}

class _MiniSoftDrawerPreview extends StatelessWidget {
  const _MiniSoftDrawerPreview();

  @override
  Widget build(BuildContext context) {
    return _MiniDrawerShell(
      layout: DrawerNavLayoutType.softCard,
      selectedIndex: 1,
    );
  }
}

class _MiniGradientDrawerPreview extends StatelessWidget {
  const _MiniGradientDrawerPreview();

  @override
  Widget build(BuildContext context) {
    return _MiniDrawerShell(
      layout: DrawerNavLayoutType.pillGradient,
      selectedIndex: 2,
    );
  }
}

class _MiniThemeBackgroundDrawerPreview extends StatelessWidget {
  const _MiniThemeBackgroundDrawerPreview();

  @override
  Widget build(BuildContext context) {
    return _MiniDrawerShell(
      layout: DrawerNavLayoutType.themeBackground,
      selectedIndex: 1,
    );
  }
}

class _MiniDrawerShell extends StatelessWidget {
  const _MiniDrawerShell({required this.layout, required this.selectedIndex});

  final DrawerNavLayoutType layout;
  final int selectedIndex;

  static const List<({IconData icon, String label})> _items =
      <({IconData icon, String label})>[
        (icon: Icons.dashboard_outlined, label: 'Dashboard'),
        (icon: Icons.assessment_outlined, label: 'Reports'),
        (icon: Icons.settings_outlined, label: 'Settings'),
      ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool themedBackground = layout == DrawerNavLayoutType.themeBackground;
    final Color themedBase = _themeBackgroundBase(theme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: themedBackground ? themedBase : scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              themedBackground
                  ? themedBase.withValues(alpha: 0.75)
                  : scheme.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.person_outline,
                      size: 10,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Menu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            themedBackground
                                ? Colors.white.withValues(alpha: 0.92)
                                : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (int i = 0; i < _items.length; i++) ...<Widget>[
                _MiniDrawerItemTile(
                  layout: layout,
                  icon: _items[i].icon,
                  label: _items[i].label,
                  selected: i == selectedIndex,
                ),
                if (i != _items.length - 1) const SizedBox(height: 2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDrawerItemTile extends StatelessWidget {
  const _MiniDrawerItemTile({
    required this.layout,
    required this.icon,
    required this.label,
    required this.selected,
  });

  final DrawerNavLayoutType layout;
  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool themedBackground = layout == DrawerNavLayoutType.themeBackground;
    final Color activeBg = _themeBackgroundActiveColor(
      _themeBackgroundBase(theme),
    );
    final Color nonSelectedText =
        themedBackground ? Colors.white : scheme.onSurface;
    final Color nonSelectedIcon =
        themedBackground
            ? Colors.white.withValues(alpha: 0.92)
            : scheme.onSurfaceVariant;

    switch (layout) {
      case DrawerNavLayoutType.classicList:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 12,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      case DrawerNavLayoutType.softCard:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color:
                selected
                    ? scheme.secondaryContainer.withValues(alpha: 0.55)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 12,
                color:
                    selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        selected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      case DrawerNavLayoutType.pillGradient:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient:
                selected
                    ? LinearGradient(
                      colors: <Color>[
                        scheme.primary,
                        scheme.primary.withValues(alpha: 0.78),
                      ],
                    )
                    : null,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 12,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      case DrawerNavLayoutType.themeBackground:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 12,
                color: selected ? Colors.white : nonSelectedIcon,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? Colors.white : nonSelectedText,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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
