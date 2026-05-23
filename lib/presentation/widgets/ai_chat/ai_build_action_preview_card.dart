import 'package:antwise/core/services/ai/ai_build_action.dart';
import 'package:flutter/material.dart';

/// Unified, Cursor-style build plan: a single rounded container that previews
/// every AI-proposed action, with one primary "Build Plan" button at the
/// bottom that executes them all in order. Naming collisions are auto-resolved
/// downstream — the UI just shows progress.
class AiBuildActionChecklist extends StatelessWidget {
  const AiBuildActionChecklist({
    super.key,
    required this.actions,
    required this.onBuildPlan,
    required this.onDiscard,
    this.warnings = const <String>[],
    this.isApplying = false,
  });

  final List<AiBuildAction> actions;
  final List<String> warnings;

  /// Single primary action: apply every pending step in this plan.
  final VoidCallback onBuildPlan;

  /// Per-row skip (× icon). Disabled while the plan is being applied.
  final void Function(int actionIndex) onDiscard;

  /// Set while [onBuildPlan] is in flight so the button shows a spinner and
  /// individual rows can't be skipped.
  final bool isApplying;

  int get _pendingCount =>
      actions
          .where((AiBuildAction a) => a.status == AiBuildActionStatus.pending)
          .length;
  int get _appliedCount =>
      actions
          .where((AiBuildAction a) => a.status == AiBuildActionStatus.applied)
          .length;
  int get _failedCount =>
      actions
          .where((AiBuildAction a) => a.status == AiBuildActionStatus.failed)
          .length;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Build plan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '$_appliedCount / ${actions.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          for (int i = 0; i < actions.length; i++) ...<Widget>[
            _AiBuildActionChecklistTile(
              action: actions[i],
              onDiscard: isApplying ? null : () => onDiscard(i),
            ),
            if (i < actions.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
          ],
          if (warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                warnings.join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _BuildPlanPrimaryAction(
              pendingCount: _pendingCount,
              appliedCount: _appliedCount,
              failedCount: _failedCount,
              totalCount: actions.length,
              isApplying: isApplying,
              onTap: onBuildPlan,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildPlanPrimaryAction extends StatelessWidget {
  const _BuildPlanPrimaryAction({
    required this.pendingCount,
    required this.appliedCount,
    required this.failedCount,
    required this.totalCount,
    required this.isApplying,
    required this.onTap,
  });

  final int pendingCount;
  final int appliedCount;
  final int failedCount;
  final int totalCount;
  final bool isApplying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final bool hasPending = pendingCount > 0;
    final bool everythingDone = !hasPending && totalCount > 0;
    final String label =
        isApplying
            ? 'Building plan…'
            : everythingDone
            ? (failedCount == 0 ? 'Plan complete' : 'Retry $failedCount failed')
            : 'Build Plan${pendingCount > 0 ? ' ($pendingCount)' : ''}';

    final Widget icon =
        isApplying
            ? SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
              ),
            )
            : Icon(
              everythingDone && failedCount == 0
                  ? Icons.check_rounded
                  : Icons.bolt_rounded,
              size: 18,
            );

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: (isApplying || !hasPending) ? null : onTap,
        icon: icon,
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _AiBuildActionChecklistTile extends StatelessWidget {
  const _AiBuildActionChecklistTile({
    required this.action,
    required this.onDiscard,
  });

  final AiBuildAction action;

  /// Null disables the skip button (e.g. while a Build Plan run is in flight
  /// or after the action has already reached a terminal state).
  final VoidCallback? onDiscard;

  bool get _isPending => action.status == AiBuildActionStatus.pending;
  bool get _isApplied => action.status == AiBuildActionStatus.applied;
  bool get _isDiscarded => action.status == AiBuildActionStatus.discarded;
  bool get _isFailed => action.status == AiBuildActionStatus.failed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final bool faded = _isApplied || _isDiscarded;
    final TextDecoration? decoration =
        faded ? TextDecoration.lineThrough : null;
    final Color labelColor =
        faded ? scheme.onSurface.withValues(alpha: 0.55) : scheme.onSurface;
    final Color subtitleColor =
        faded
            ? scheme.onSurfaceVariant.withValues(alpha: 0.55)
            : scheme.onSurfaceVariant;
    final bool canDiscard = _isPending && onDiscard != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _ChecklistIndicator(status: action.status, intent: action.intent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _IntentChip(intent: action.intent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        style: (theme.textTheme.bodyMedium ?? const TextStyle())
                            .copyWith(
                              color: labelColor,
                              decoration: decoration,
                              fontWeight: FontWeight.w500,
                            ),
                        child: Text(
                          action.checklistLabel,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_subtitleFor(action).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _subtitleFor(action),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                        decoration: decoration,
                      ),
                    ),
                  ),
                if (_isFailed && (action.failureReason ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      action.failureReason!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: canDiscard ? 'Skip' : null,
            onPressed: canDiscard ? onDiscard : null,
            splashRadius: 18,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              _isDiscarded
                  ? Icons.do_not_disturb_on_outlined
                  : Icons.close_rounded,
              size: 18,
              color:
                  canDiscard
                      ? scheme.onSurfaceVariant
                      : scheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleFor(AiBuildAction action) {
    switch (action) {
      case CreatePageAction(:final AiBuildPageNavigation navigation):
        return 'Page • ${navigation.storageValue} nav';
      case CreateTableAction(
        :final String pageRef,
        :final List<AiBuildColumnSpec> columns,
      ):
        final String colSummary =
            columns.isEmpty
                ? 'no columns'
                : '${columns.length} column${columns.length == 1 ? '' : 's'}';
        return 'Table on $pageRef • $colSummary';
      case CreateCardWidgetAction(
        :final String tableRef,
        :final String columnName,
        :final String formula,
      ):
        final List<String> parts = <String>['Card widget'];
        if (tableRef.isNotEmpty) {
          parts.add(tableRef);
        }
        if (formula.isNotEmpty) {
          parts.add(formula);
        } else if (columnName.isNotEmpty) {
          parts.add(columnName);
        }
        return parts.join(' • ');
      case CreateChartWidgetAction(
        :final String tableRef,
        :final AiBuildChartType chartType,
        :final String xColumn,
        :final String yColumn,
      ):
        return '${chartType.storageValue} chart • $tableRef • $xColumn → $yColumn';
      case UpdatePageAction(
        :final AiBuildPageNavigation? navigation,
        :final String? icon,
      ):
        final List<String> parts = <String>['Page update'];
        if (navigation != null) {
          parts.add('${navigation.storageValue} nav');
        }
        if (icon != null && icon.isNotEmpty) {
          parts.add('icon: $icon');
        }
        return parts.join(' • ');
      case UpdateTableAction(:final List<AiBuildColumnSpec> columns):
        return 'Replace schema • ${columns.length} column'
            '${columns.length == 1 ? '' : 's'}';
      case UpdateWidgetAction(:final String pageRef, :final String? formula):
        final List<String> parts = <String>['Widget on $pageRef'];
        if (formula != null && formula.isNotEmpty) {
          parts.add(formula);
        }
        return parts.join(' • ');
      case DeletePageAction():
        return 'Delete page + dependent tables & widgets';
      case DeleteTableAction():
        return 'Delete table + rows + dependent widgets';
      case DeleteWidgetAction(:final String pageRef):
        return 'Widget on $pageRef';
    }
  }
}

/// Compact "Create / Update / Delete" pill rendered before each row's label.
class _IntentChip extends StatelessWidget {
  const _IntentChip({required this.intent});

  final AiBuildActionIntent intent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _IntentColors colors = _IntentColors.from(theme, intent);
    final String label = switch (intent) {
      AiBuildActionIntent.create => 'CREATE',
      AiBuildActionIntent.update => 'UPDATE',
      AiBuildActionIntent.delete => 'DELETE',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontSize: 10,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Theme-aware color trio (border / fill / on-color) per build-action intent.
class _IntentColors {
  const _IntentColors({
    required this.accent,
    required this.tint,
    required this.onAccent,
  });

  /// Strong border / icon color (green-ish / amber-ish / red-ish).
  final Color accent;

  /// Soft background fill for pending/applied states.
  final Color tint;

  /// Foreground when the indicator is filled with [accent].
  final Color onAccent;

  static _IntentColors from(ThemeData theme, AiBuildActionIntent intent) {
    final ColorScheme scheme = theme.colorScheme;
    final bool dark = theme.brightness == Brightness.dark;
    switch (intent) {
      case AiBuildActionIntent.create:
        // Use primary so we keep brand identity for the most common case.
        return _IntentColors(
          accent: scheme.primary,
          tint: scheme.primary.withValues(alpha: dark ? 0.18 : 0.10),
          onAccent: scheme.onPrimary,
        );
      case AiBuildActionIntent.update:
        // Amber stands in for "modify" — visible in light + dark mode.
        final Color amber =
            dark ? const Color(0xFFFFB74D) : const Color(0xFFE0A800);
        return _IntentColors(
          accent: amber,
          tint: amber.withValues(alpha: dark ? 0.20 : 0.14),
          onAccent: Colors.black,
        );
      case AiBuildActionIntent.delete:
        return _IntentColors(
          accent: scheme.error,
          tint: scheme.errorContainer.withValues(alpha: dark ? 0.55 : 0.40),
          onAccent: scheme.onError,
        );
    }
  }
}

/// Circular status indicator that animates between pending / applied /
/// discarded / failed states. The base color tracks the [intent] (green-ish
/// for CREATE, amber-ish for UPDATE, red-ish for DELETE) so the row reads at
/// a glance.
class _ChecklistIndicator extends StatelessWidget {
  const _ChecklistIndicator({required this.status, required this.intent});

  final AiBuildActionStatus status;
  final AiBuildActionIntent intent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final _IntentColors intentColors = _IntentColors.from(theme, intent);

    final ({Color border, Color fill, Color iconColor, IconData? icon}) style =
        switch (status) {
          AiBuildActionStatus.pending => (
            border: intentColors.accent,
            fill: Colors.transparent,
            iconColor: intentColors.accent,
            icon: switch (intent) {
              AiBuildActionIntent.create => null,
              AiBuildActionIntent.update => Icons.refresh_rounded,
              AiBuildActionIntent.delete => Icons.remove_rounded,
            },
          ),
          AiBuildActionStatus.applied => (
            border: intentColors.accent,
            fill: intentColors.accent,
            iconColor: intentColors.onAccent,
            icon: switch (intent) {
              AiBuildActionIntent.create => Icons.check_rounded,
              AiBuildActionIntent.update => Icons.check_rounded,
              AiBuildActionIntent.delete => Icons.delete_outline_rounded,
            },
          ),
          AiBuildActionStatus.discarded => (
            border: scheme.outlineVariant,
            fill: scheme.surfaceContainerHighest,
            iconColor: scheme.onSurfaceVariant,
            icon: Icons.remove_rounded,
          ),
          AiBuildActionStatus.failed => (
            border: scheme.error,
            fill: scheme.errorContainer,
            iconColor: scheme.onErrorContainer,
            icon: Icons.priority_high_rounded,
          ),
        };

    return Semantics(
      label: '${_intentLabel(intent)} · ${_statusLabel(status)}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: style.fill,
          shape: BoxShape.circle,
          border: Border.all(color: style.border, width: 1.6),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child:
              style.icon == null
                  ? const SizedBox.shrink(key: ValueKey<String>('empty'))
                  : Icon(
                    style.icon,
                    key: ValueKey<IconData>(style.icon!),
                    size: 14,
                    color: style.iconColor,
                  ),
        ),
      ),
    );
  }

  String _intentLabel(AiBuildActionIntent intent) => switch (intent) {
    AiBuildActionIntent.create => 'Create',
    AiBuildActionIntent.update => 'Update',
    AiBuildActionIntent.delete => 'Delete',
  };

  String _statusLabel(AiBuildActionStatus status) => switch (status) {
    AiBuildActionStatus.pending => 'pending',
    AiBuildActionStatus.applied => 'applied',
    AiBuildActionStatus.discarded => 'skipped',
    AiBuildActionStatus.failed => 'failed',
  };
}
