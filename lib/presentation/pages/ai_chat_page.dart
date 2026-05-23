import 'dart:async';

import 'package:antwise/core/services/ai/ai_build_action.dart';
import 'package:antwise/core/services/ai/ai_build_plan.dart';
import 'package:antwise/presentation/controllers/ai_chat_controller.dart';
import 'package:antwise/presentation/models/ai_generation_phase.dart';
import 'package:antwise/presentation/widgets/ai_chat/ai_build_action_preview_card.dart';
import 'package:antwise/presentation/widgets/ai_chat/ai_chat_mention_input.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_animated_text/my_animated_text.dart';

class NeonHeadline extends StatelessWidget {
  const NeonHeadline(
    this.text, {
    super.key,
    this.style,
    this.mode = AnimatedTextMode.loop,
  });

  final String text;
  final TextStyle? style;
  final AnimatedTextMode mode;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;

    return ShimmerText(
      text,
      mode: mode,
      style: (style ?? const TextStyle()).copyWith(
        shadows: <Shadow>[
          Shadow(color: accent.withValues(alpha: 0.45), blurRadius: 8),
          Shadow(color: accent.withValues(alpha: 0.25), blurRadius: 14),
        ],
      ),
    );
  }
}

Future<void> _sendChatMessageWithLogs(AiChatController controller) async {
  final String text = controller.inputController.text.trim();
  if (text.isEmpty || controller.isGenerating.value) {
    return;
  }
  debugPrint('[AiChat] user message: $text');
  await controller.send();
  final List<ChatMessage> list = controller.messages;
  if (list.isNotEmpty && list.last.role == 'assistant') {
    debugPrint('[AiChat] AI response: ${list.last.text}');
  }
}

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  late final AiChatController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<AiChatController>();
  }

  Future<void> _confirmAndClearHistory(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear chat history?'),
          content: const Text(
            'All messages in this workspace will be removed from this device. '
            'This cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await controller.clearWorkspaceHistory();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final String subtitle = controller.workspaceSubtitle.value;
          if (subtitle.isEmpty) {
            return const Text('AI support');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('AI support'),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          );
        }),
        actions: <Widget>[
          Obx(() {
            final bool busy =
                controller.isGenerating.value || !controller.historyReady.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SegmentedButton<AiChatMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const <ButtonSegment<AiChatMode>>[
                  ButtonSegment<AiChatMode>(
                    value: AiChatMode.ask,
                    label: Text('Ask'),
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  ),
                  ButtonSegment<AiChatMode>(
                    value: AiChatMode.build,
                    label: Text('Build'),
                    icon: Icon(Icons.auto_fix_high_outlined, size: 16),
                  ),
                ],
                selected: <AiChatMode>{controller.chatMode.value},
                onSelectionChanged:
                    busy
                        ? null
                        : (Set<AiChatMode> next) {
                          if (next.isNotEmpty) {
                            controller.setChatMode(next.first);
                          }
                        },
              ),
            );
          }),
          Obx(
            () => IconButton(
              tooltip: 'Clear chat history',
              icon: const Icon(Icons.delete_outline),
              onPressed:
                  controller.isGenerating.value ||
                          !controller.historyReady.value
                      ? null
                      : () => _confirmAndClearHistory(context),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Obx(() {
              if (!controller.historyReady.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final List<ChatMessage> list = controller.messages;
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'Ask about Antwise — navigation, pages, tables, settings, '
                    'or switch to Build to create, replace, or remove pages, '
                    'tables, and widgets. Replies run on-device.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.builder(
                controller: controller.scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: list.length,
                itemBuilder: (BuildContext context, int index) {
                  final ChatMessage m = list[index];
                  final bool user = m.role == 'user';
                  final bool isActiveLoadingBubble =
                      !user &&
                      m.text.isEmpty &&
                      controller.isGenerating.value &&
                      index == list.length - 1;

                  if (!user && m.text.isEmpty && !isActiveLoadingBubble) {
                    return const SizedBox.shrink();
                  }

                  final AiBuildMessageMetadata? buildMeta =
                      user ? null : m.buildMetadata;
                  if (buildMeta != null && buildMeta.hasActions) {
                    return _BuildModeChecklistMessage(
                      message: m,
                      metadata: buildMeta,
                      controller: controller,
                    );
                  }

                  if (isActiveLoadingBubble) {
                    return _GenerationProgressBubble(controller: controller);
                  }

                  return Align(
                    alignment:
                        user ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color:
                            user
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        m.text,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Obx(() {
                      final bool buildMode =
                          controller.chatMode.value == AiChatMode.build;
                      return AiChatMentionInput(
                        controller: controller.inputController,
                        focusNode: controller.chatInputFocusNode,
                        minLines: 1,
                        maxLines: 5,
                        hintText:
                            buildMode
                                ? 'Describe changes… @ to pick a resource'
                                : 'Message… @ to reference workspace',
                        onSubmitted: (_) {
                          unawaited(_sendChatMessageWithLogs(controller));
                        },
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  Obx(() {
                    final bool generating = controller.isGenerating.value;
                    return IconButton.filled(
                      tooltip: generating ? 'Stop generating' : 'Send',
                      onPressed: () {
                        if (generating) {
                          unawaited(controller.cancelGeneration());
                          return;
                        }
                        unawaited(_sendChatMessageWithLogs(controller));
                      },
                      icon: Icon(generating ? Icons.stop_rounded : Icons.send),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading bubble that reflects the controller's real generation phase.
///
/// Build mode renders a 4-step stepper bound to
/// [AiChatController.generationPhase] and, when the planner has produced
/// concrete steps, a compact plan preview below the stepper. Ask mode keeps
/// a single shimmering headline.
class _GenerationProgressBubble extends StatelessWidget {
  const _GenerationProgressBubble({required this.controller});

  final AiChatController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.94,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Obx(() {
          final AiGenerationPhase? phase = controller.generationPhase.value;
          if (controller.chatMode.value == AiChatMode.build) {
            return _BuildGenerationProgress(
              activePhase: phase,
              plan: controller.buildPlanPreview.value,
            );
          }
          final String label = phase?.label ?? 'Thinking…';
          return NeonHeadline(
            key: ValueKey<String>(label),
            label,
            mode: AnimatedTextMode.loop,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }),
      ),
    );
  }
}

/// 4-step vertical progress indicator for Build mode (reasoning, analyzing,
/// planning, finalizing). Earlier steps render as checks, the current step
/// shimmers, later steps stay muted. Includes a compact plan preview once
/// the planner stage produces concrete steps.
class _BuildGenerationProgress extends StatelessWidget {
  const _BuildGenerationProgress({
    required this.activePhase,
    required this.plan,
  });

  final AiGenerationPhase? activePhase;
  final AiBuildPlan? plan;

  int get _activeIndex {
    if (activePhase == null) {
      return kAiBuildGenerationStepper.length - 1;
    }
    final int idx = kAiBuildGenerationStepper.indexOf(activePhase!);
    return idx < 0 ? kAiBuildGenerationStepper.length - 1 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int activeIndex = _activeIndex;
    final bool showPlanPreview = plan != null &&
        plan!.hasSteps &&
        activeIndex >= kAiBuildGenerationStepper.indexOf(
              AiGenerationPhase.finalizing,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < kAiBuildGenerationStepper.length; i++)
          _BuildProgressStep(
            phase: kAiBuildGenerationStepper[i],
            state: i < activeIndex
                ? _StepState.completed
                : i == activeIndex
                    ? _StepState.active
                    : _StepState.pending,
            isFirst: i == 0,
            isLast: i == kAiBuildGenerationStepper.length - 1,
          ),
        if (showPlanPreview)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 28),
            child: _BuildPlanPreview(plan: plan!, theme: theme),
          ),
      ],
    );
  }
}

enum _StepState { pending, active, completed }

class _BuildProgressStep extends StatelessWidget {
  const _BuildProgressStep({
    required this.phase,
    required this.state,
    required this.isFirst,
    required this.isLast,
  });

  final AiGenerationPhase phase;
  final _StepState state;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color activeColor = scheme.primary;
    final Color completedColor = scheme.primary;
    final Color pendingColor = scheme.onSurfaceVariant.withValues(alpha: 0.55);
    final Color labelColor = switch (state) {
      _StepState.completed => scheme.onSurface,
      _StepState.active => scheme.onSurface,
      _StepState.pending => pendingColor,
    };

    final Widget indicator = _StepIndicator(
      state: state,
      activeColor: activeColor,
      completedColor: completedColor,
      pendingColor: pendingColor,
    );

    final Widget labelWidget = state == _StepState.active
        ? NeonHeadline(
            phase.label,
            mode: AnimatedTextMode.loop,
            style: theme.textTheme.bodyMedium?.copyWith(color: labelColor),
          )
        : Text(
            phase.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: labelColor,
              fontWeight: state == _StepState.completed
                  ? FontWeight.w500
                  : FontWeight.w400,
            ),
          );

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 6, bottom: isLast ? 0 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          indicator,
          const SizedBox(width: 10),
          Expanded(child: labelWidget),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.state,
    required this.activeColor,
    required this.completedColor,
    required this.pendingColor,
  });

  final _StepState state;
  final Color activeColor;
  final Color completedColor;
  final Color pendingColor;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _StepState.completed:
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: completedColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 12,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        );
      case _StepState.active:
        return SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(activeColor),
          ),
        );
      case _StepState.pending:
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: pendingColor, width: 1.5),
          ),
        );
    }
  }
}

class _BuildPlanPreview extends StatelessWidget {
  const _BuildPlanPreview({required this.plan, required this.theme});

  final AiBuildPlan plan;
  final ThemeData theme;

  static const int _maxStepsShown = 5;

  @override
  Widget build(BuildContext context) {
    final List<String> steps = plan.steps;
    final int visible = steps.length > _maxStepsShown ? _maxStepsShown : steps.length;
    final int overflow = steps.length - visible;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Plan',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < visible; i++)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• ${steps[i]}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
          if (overflow > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+ $overflow more',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders a Build-mode assistant message as a single unified plan: an
/// optional summary line above, the action checklist inside one container,
/// and one primary "Build Plan" button at the bottom (Cursor-style). All
/// pending actions run in order when the button is pressed; naming
/// collisions are auto-resolved by the executor.
class _BuildModeChecklistMessage extends StatelessWidget {
  const _BuildModeChecklistMessage({
    required this.message,
    required this.metadata,
    required this.controller,
  });

  final ChatMessage message;
  final AiBuildMessageMetadata metadata;
  final AiChatController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 24),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.94,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (message.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Obx(() {
                final bool isApplying =
                    controller.applyingPlanMessageId.value == message.id;
                return AiBuildActionChecklist(
                  actions: metadata.actions,
                  warnings: metadata.warnings,
                  isApplying: isApplying,
                  onBuildPlan: () {
                    unawaited(controller.applyBuildPlan(message.id));
                  },
                  onDiscard: (int actionIndex) {
                    unawaited(
                      controller.discardBuildAction(message.id, actionIndex),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
