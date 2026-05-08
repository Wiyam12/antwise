import 'dart:async';

import 'package:antwise/presentation/controllers/ai_chat_controller.dart';
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
  Worker? _isGeneratingWorker;
  Timer? _loadingMessageStage2Timer;
  Timer? _loadingMessageStage3Timer;
  String? _loadingMessage;

  @override
  void initState() {
    super.initState();
    controller = Get.find<AiChatController>();
    _isGeneratingWorker = ever<bool>(
      controller.isGenerating,
      _handleGeneratingChanged,
    );
    if (controller.isGenerating.value) {
      _startLoadingMessageCycle();
    }
  }

  @override
  void dispose() {
    _isGeneratingWorker?.dispose();
    _cancelLoadingMessageTimers();
    super.dispose();
  }

  void _handleGeneratingChanged(bool isGenerating) {
    if (isGenerating) {
      _startLoadingMessageCycle();
      return;
    }

    _cancelLoadingMessageTimers();
    if (_loadingMessage != null && mounted) {
      setState(() {
        _loadingMessage = null;
      });
    }
  }

  void _startLoadingMessageCycle() {
    _cancelLoadingMessageTimers();
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingMessage = 'Thinking...';
    });

    _loadingMessageStage2Timer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !controller.isGenerating.value) {
        return;
      }
      setState(() {
        _loadingMessage = 'Thinking may take some time...';
      });
    });

    _loadingMessageStage3Timer = Timer(const Duration(seconds: 8), () {
      if (!mounted || !controller.isGenerating.value) {
        return;
      }
      setState(() {
        _loadingMessage = 'Still generating response, please wait...';
      });
    });
  }

  void _cancelLoadingMessageTimers() {
    _loadingMessageStage2Timer?.cancel();
    _loadingMessageStage2Timer = null;
    _loadingMessageStage3Timer?.cancel();
    _loadingMessageStage3Timer = null;
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
                    'Ask about Antwise only — navigation, pages, tables, '
                    'settings, or other in-app features. Replies run on-device.',
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
                      child:
                          isActiveLoadingBubble
                              ? NeonHeadline(
                                key: ValueKey<String>(
                                  _loadingMessage ?? 'Thinking...',
                                ),
                                _loadingMessage ?? 'Thinking...',
                                mode: AnimatedTextMode.loop,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                              : SelectableText(
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
                    child: TextField(
                      controller: controller.inputController,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        unawaited(_sendChatMessageWithLogs(controller));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Obx(
                    () => IconButton.filled(
                      onPressed:
                          controller.isGenerating.value
                              ? null
                              : () {
                                unawaited(_sendChatMessageWithLogs(controller));
                              },
                      icon:
                          controller.isGenerating.value
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
