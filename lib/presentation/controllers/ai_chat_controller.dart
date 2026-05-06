import 'dart:async';
import 'dart:convert';

import 'package:antwise/core/constants/app_constants.dart';
import 'package:antwise/core/services/ai_service.dart';
import 'package:antwise/core/services/ai_support_table_snapshot.dart';
import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/app_settings_hive_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_controller.dart';

class ChatMessage {
  ChatMessage({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
    'text': text,
  };

  static ChatMessage? fromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
    final String role = map['role'] as String? ?? 'assistant';
    final String text = map['text'] as String? ?? '';
    return ChatMessage(role: role, text: text);
  }
}

class AiChatController extends GetxController {
  AiChatController(this._ai, this._prefs);

  static const String _prefsHistoryPrefix = 'ai_chat_history_v1_';
  static const String _fallbackWorkspaceId = '__default__';

  final AIService _ai;
  final SharedPreferences _prefs;

  final TextEditingController inputController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxBool isGenerating = false.obs;
  final RxString workspaceSubtitle = ''.obs;
  final RxBool historyReady = false.obs;

  @override
  void onReady() {
    super.onReady();
    unawaited(_loadHistoryAndGreet());
  }

  @override
  void onClose() {
    unawaited(_ai.stopGeneration());
    unawaited(_persistMessages());
    inputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> send() async {
    final String text = inputController.text.trim();
    if (text.isEmpty || isGenerating.value) {
      return;
    }
    inputController.clear();
    messages.add(ChatMessage(role: 'user', text: text));
    messages.add(ChatMessage(role: 'assistant', text: ''));
    isGenerating.value = true;
    _scrollToBottom();

    try {
      final String outline = AiSupportTableSnapshot.tryBuild();
      final String reply = await _ai.generateResponse(
        text,
        tableOutlineSnapshot: outline,
      );
      messages[messages.length - 1] = ChatMessage(
        role: 'assistant',
        text: reply,
      );
      messages.refresh();
    } catch (e) {
      messages[messages.length - 1] = ChatMessage(
        role: 'assistant',
        text: 'Error: $e',
      );
      messages.refresh();
    } finally {
      isGenerating.value = false;
      _scrollToBottom();
      await _persistMessages();
    }
  }

  Future<void> _loadHistoryAndGreet() async {
    try {
      workspaceSubtitle.value = _displayAccountLabel();
      final List<ChatMessage> loaded = _decodeMessages(
        _prefs.getString(_historyPrefsKey()),
      );
      if (loaded.isEmpty) {
        messages.assignAll(<ChatMessage>[
          ChatMessage(role: 'assistant', text: _buildOpeningGreeting()),
        ]);
        await _persistMessages();
      } else {
        messages.assignAll(loaded);
      }
      _scrollToBottom();
    } finally {
      historyReady.value = true;
    }
  }

  String _historyPrefsKey() =>
      '$_prefsHistoryPrefix${Uri.encodeComponent(_workspaceStorageId())}';

  /// Stable id for storage (may be [AiChatController._fallbackWorkspaceId]).
  String _workspaceStorageId() {
    if (Get.isRegistered<HomeController>()) {
      final String name =
          Get.find<HomeController>().activeAccountName.value.trim();
      if (name.isNotEmpty) {
        return name;
      }
    }
    if (Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      final Box<AppSettingsHiveModel> box =
          Hive.box<AppSettingsHiveModel>(HiveBoxes.settingsBox);
      final AppSettingsHiveModel? settings = box.get(HiveKeys.appSettings);
      final String name = settings?.activeAccountName.trim() ?? '';
      if (name.isNotEmpty) {
        return name;
      }
    }
    return _fallbackWorkspaceId;
  }

  String _displayAccountLabel() {
    final String id = _workspaceStorageId();
    return id == _fallbackWorkspaceId ? '' : id;
  }

  String _buildOpeningGreeting() {
    final String label = _displayAccountLabel().trim();
    if (label.isEmpty) {
      return 'Hi! I help only with ${AppConstants.appName} features — navigation, '
          'pages, tables, settings, and in-app troubleshooting. What do you need?';
    }
    return 'Hi, $label! I help only with ${AppConstants.appName} in this app — '
        'navigation, tables, settings, and similar. How can I help?';
  }

  List<ChatMessage> _decodeMessages(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <ChatMessage>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return <ChatMessage>[];
      }
      return decoded
          .map(ChatMessage.fromJson)
          .whereType<ChatMessage>()
          .toList(growable: false);
    } catch (_) {
      return <ChatMessage>[];
    }
  }

  Future<void> _persistMessages() async {
    final List<ChatMessage> snapshot =
        messages
            .where(
              (ChatMessage m) =>
                  !(m.role == 'assistant' && m.text.trim().isEmpty),
            )
            .toList(growable: false);
    await _prefs.setString(
      _historyPrefsKey(),
      jsonEncode(snapshot.map((ChatMessage m) => m.toJson()).toList()),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) {
        return;
      }
      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
}
