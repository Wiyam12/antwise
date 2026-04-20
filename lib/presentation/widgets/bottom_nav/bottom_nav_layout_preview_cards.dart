import 'package:antwise/core/app_snackbar.dart';
import 'package:antwise/domain/entities/bottom_nav_layout_type.dart';
import 'package:antwise/domain/validation/bottom_nav_layout_rules.dart';
import 'package:flutter/material.dart';

/// Selectable preview cards for bottom navigation layout (reference-style mini mockups).
class BottomNavLayoutPicker extends StatelessWidget {
  const BottomNavLayoutPicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.bottomNavPageCount,
  });

  final BottomNavLayoutType selected;
  final ValueChanged<BottomNavLayoutType> onSelect;

  /// When set, Floating Center is dimmed unless the count satisfies layout rules.
  final int? bottomNavPageCount;

  @override
  Widget build(BuildContext context) {
    final bool floatingSelectable =
        bottomNavPageCount == null
            ? true
            : BottomNavLayoutRules.isFloatingCenterValidForBottomCount(
              bottomNavPageCount!,
            );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double minCard = 148.0;
        final int crossAxisCount =
            constraints.maxWidth >= minCard * 3 + 32 ? 3 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.start,
          children: <Widget>[
            _LayoutPreviewCard(
              title: 'Standard',
              subtitle: 'Icon + label',
              selected: selected == BottomNavLayoutType.standard,
              onTap: () => onSelect(BottomNavLayoutType.standard),
              minWidth:
                  crossAxisCount == 3
                      ? (constraints.maxWidth - 24) / 3
                      : constraints.maxWidth,
              child: const _MiniStandardPreview(),
            ),
            _LayoutPreviewCard(
              title: 'Center emphasis',
              subtitle: 'Pill on center item',
              selected: selected == BottomNavLayoutType.centerIconEmphasis,
              onTap: () => onSelect(BottomNavLayoutType.centerIconEmphasis),
              minWidth:
                  crossAxisCount == 3
                      ? (constraints.maxWidth - 24) / 3
                      : constraints.maxWidth,
              child: const _MiniCenterEmphasisPreview(),
            ),
            _LayoutPreviewCard(
              title: 'Floating center',
              subtitle: 'FAB + side items',
              selected: selected == BottomNavLayoutType.floatingCenterAction,
              dimmed: !floatingSelectable,
              onTap: () {
                if (!floatingSelectable) {
                  showAppSnackbar(
                    'Bottom navigation',
                    BottomNavLayoutRules.floatingCenterSnackbarMessage,
                  );
                  return;
                }
                onSelect(BottomNavLayoutType.floatingCenterAction);
              },
              minWidth:
                  crossAxisCount == 3
                      ? (constraints.maxWidth - 24) / 3
                      : constraints.maxWidth,
              child: const _MiniFloatingPreview(),
            ),
          ],
        );
      },
    );
  }
}

class _LayoutPreviewCard extends StatelessWidget {
  const _LayoutPreviewCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    this.dimmed = false,
    required this.onTap,
    required this.minWidth,
    required this.child,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color borderColor =
        dimmed
            ? scheme.error.withValues(alpha: 0.45)
            : (selected ? scheme.primary : scheme.outlineVariant);
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth.clamp(120, 400)),
      child: Opacity(
        opacity: dimmed ? 0.5 : 1,
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
                  color: borderColor,
                  width: selected ? 2.2 : 1,
                ),
                boxShadow:
                    selected
                        ? <BoxShadow>[
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                        : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(height: 58, child: child),
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
      ),
    );
  }
}

class _MiniBarChrome extends StatelessWidget {
  const _MiniBarChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: child,
    );
  }
}

class _MiniStandardPreview extends StatelessWidget {
  const _MiniStandardPreview();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color active = scheme.primary;
    final Color inactive = scheme.onSurfaceVariant.withValues(alpha: 0.75);
    return _MiniBarChrome(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _MiniItem(active: true, color: active, muted: inactive),
          _MiniItem(active: false, color: active, muted: inactive),
          _MiniItem(active: false, color: active, muted: inactive),
          _MiniItem(active: false, color: active, muted: inactive),
        ],
      ),
    );
  }
}

class _MiniItem extends StatelessWidget {
  const _MiniItem({
    required this.active,
    required this.color,
    required this.muted,
  });

  final bool active;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final Color c = active ? color : muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.circle_outlined, size: 14, color: c),
        const SizedBox(height: 3),
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

class _MiniCenterEmphasisPreview extends StatelessWidget {
  const _MiniCenterEmphasisPreview();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color active = scheme.primary;
    final Color inactive = scheme.onSurfaceVariant.withValues(alpha: 0.75);
    return _MiniBarChrome(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _MiniItem(active: false, color: active, muted: inactive),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.circle_outlined, size: 14, color: active),
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: 2,
                  decoration: BoxDecoration(
                    color: active,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
          _MiniItem(active: false, color: active, muted: inactive),
          _MiniItem(active: false, color: active, muted: inactive),
        ],
      ),
    );
  }
}

class _MiniFloatingPreview extends StatelessWidget {
  const _MiniFloatingPreview();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color active = scheme.primary;
    final Color inactive = scheme.onSurfaceVariant.withValues(alpha: 0.75);
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: <Widget>[
        _MiniBarChrome(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _MiniItem(active: true, color: active, muted: inactive),
              _MiniItem(active: false, color: active, muted: inactive),
              const SizedBox(width: 18),
              _MiniItem(active: false, color: active, muted: inactive),
              _MiniItem(active: false, color: active, muted: inactive),
            ],
          ),
        ),
        Positioned(
          bottom: 14,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(Icons.add, size: 14, color: scheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
