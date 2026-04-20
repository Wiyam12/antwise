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
        const double minCard = 148.0;
        final int crossAxisCount =
            constraints.maxWidth >= minCard * 3 + 32 ? 3 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _DrawerLayoutCard(
              title: 'Classic',
              subtitle: 'Clean list menu',
              selected: selected == DrawerNavLayoutType.classicList,
              onTap: () => onSelect(DrawerNavLayoutType.classicList),
              minWidth:
                  crossAxisCount == 3
                      ? (constraints.maxWidth - 24) / 3
                      : constraints.maxWidth,
              child: const _MiniClassicDrawerPreview(),
            ),
            _DrawerLayoutCard(
              title: 'Soft card',
              subtitle: 'Highlighted row',
              selected: selected == DrawerNavLayoutType.softCard,
              onTap: () => onSelect(DrawerNavLayoutType.softCard),
              minWidth:
                  crossAxisCount == 3
                      ? (constraints.maxWidth - 24) / 3
                      : constraints.maxWidth,
              child: const _MiniSoftDrawerPreview(),
            ),
            _DrawerLayoutCard(
              title: 'Pill gradient',
              subtitle: 'Rounded active item',
              selected: selected == DrawerNavLayoutType.pillGradient,
              onTap: () => onSelect(DrawerNavLayoutType.pillGradient),
              minWidth:
                  crossAxisCount == 3
                      ? (constraints.maxWidth - 24) / 3
                      : constraints.maxWidth,
              child: const _MiniGradientDrawerPreview(),
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
                SizedBox(height: 68, child: child),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: <Widget>[
          _miniLine(scheme.onSurfaceVariant, 0.42),
          const SizedBox(height: 6),
          _miniLine(scheme.onSurface, 0.72),
          const SizedBox(height: 6),
          _miniLine(scheme.onSurfaceVariant, 0.68),
          const SizedBox(height: 6),
          _miniLine(scheme.onSurfaceVariant, 0.63),
        ],
      ),
    );
  }
}

class _MiniSoftDrawerPreview extends StatelessWidget {
  const _MiniSoftDrawerPreview();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: <Widget>[
          _miniLine(scheme.onSurfaceVariant, 0.42),
          const SizedBox(height: 6),
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 6),
          _miniLine(scheme.onSurfaceVariant, 0.68),
          const SizedBox(height: 6),
          _miniLine(scheme.onSurfaceVariant, 0.63),
        ],
      ),
    );
  }
}

class _MiniGradientDrawerPreview extends StatelessWidget {
  const _MiniGradientDrawerPreview();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: <Widget>[
          _miniLine(scheme.onSurfaceVariant, 0.42),
          const SizedBox(height: 6),
          Container(
            height: 14,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.75),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 6),
          _miniLine(scheme.onSurfaceVariant, 0.68),
          const SizedBox(height: 6),
          _miniLine(scheme.onSurfaceVariant, 0.63),
        ],
      ),
    );
  }
}

Widget _miniLine(Color color, double factor) {
  return Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: factor,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    ),
  );
}
