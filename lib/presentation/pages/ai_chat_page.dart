import 'dart:async';

import 'package:antwise/presentation/controllers/ai_chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

class AiChatPage extends GetView<AiChatController> {
  const AiChatPage({super.key});

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
                        m.text.isEmpty && !user ? '…' : m.text,
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
