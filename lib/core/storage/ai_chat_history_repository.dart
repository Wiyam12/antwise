import 'dart:convert';

import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/core/storage/hive_service.dart';
import 'package:antwise/data/models/hive/ai_chat_message_hive_model.dart';
import 'package:antwise/data/models/hive/ai_chat_session_hive_model.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hive-backed AI chat: `account_id` + `workspace_id` → ordered messages.
abstract final class AiChatHistoryKeys {
  static const String prefsLegacyPrefix = 'ai_chat_history_v1_';

  /// Default workspace segment when no per-account workspace UUID exists yet.
  static const String defaultWorkspaceId = 'default';
}

/// Configuration for how much history loads into AI context vs UI.
abstract final class AiChatHistoryLimits {
  /// Included in LM context (paired user/assistant turns). Adjust 10–50 as needed.
  static const int defaultContextMessageCount = 24;
  static const int maxStoredMessagesPerSession = 800;
}

class AiChatHistoryRepository {
  AiChatHistoryRepository(this._hiveService, this._prefs);

  final HiveService _hiveService;
  final SharedPreferences _prefs;

  Box<AiChatSessionHiveModel> get _box =>
      _hiveService.box<AiChatSessionHiveModel>(HiveBoxes.aiChatHistoryBox);

  static String sanitizeKeySegment(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '__empty__';
    }
    return trimmed
        .replaceAll(RegExp(r'[/\\:?*"<>|\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// Composite Hive key: account → workspace → session blob.
  static String sessionStorageKey({
    required String accountId,
    required String workspaceId,
  }) {
    final String a = sanitizeKeySegment(accountId);
    final String w = sanitizeKeySegment(workspaceId);
    return '$a::$w';
  }

  Future<void> ensureBoxOpen() async {
    if (Hive.isBoxOpen(HiveBoxes.aiChatHistoryBox)) {
      return;
    }
    await Hive.openBox<AiChatSessionHiveModel>(HiveBoxes.aiChatHistoryBox);
  }

  AiChatSessionHiveModel _readSession(String key) {
    return _box.get(key) ?? AiChatSessionHiveModel(messages: <AiChatMessageHiveModel>[]);
  }

  Future<void> _writeSession(String key, AiChatSessionHiveModel session) async {
    await _box.put(key, session);
  }

  List<AiChatMessageHiveModel> _sortedCopy(
    List<AiChatMessageHiveModel> messages,
  ) {
    final List<AiChatMessageHiveModel> copy =
        List<AiChatMessageHiveModel>.from(messages);
    copy.sort(
      (AiChatMessageHiveModel a, AiChatMessageHiveModel b) =>
          a.timestampMillis.compareTo(b.timestampMillis),
    );
    return copy;
  }

  Future<void> _migrateLegacyPrefsIfNeeded({
    required String prefsAccountSegment,
    required String accountId,
    required String workspaceId,
  }) async {
    final String key = sessionStorageKey(
      accountId: accountId,
      workspaceId: workspaceId,
    );
    if ((_box.get(key)?.messages.isNotEmpty ?? false)) {
      return;
    }
    final String legacy =
        _prefs.getString(
          '${AiChatHistoryKeys.prefsLegacyPrefix}'
          '${Uri.encodeComponent(prefsAccountSegment)}',
        ) ??
        '';
    if (legacy.isEmpty) {
      return;
    }
    try {
      final dynamic decoded = jsonDecode(legacy);
      if (decoded is! List<dynamic>) {
        return;
      }
      final int nowBase = DateTime.now().millisecondsSinceEpoch;
      final List<AiChatMessageHiveModel> imported = <AiChatMessageHiveModel>[];
      for (int i = 0; i < decoded.length; i++) {
        final dynamic raw = decoded[i];
        if (raw is! Map) {
          continue;
        }
        final Map<String, dynamic> map = Map<String, dynamic>.from(raw);
        final String role = map['role'] as String? ?? 'assistant';
        final String text = map['text'] as String? ?? '';
        imported.add(
          AiChatMessageHiveModel(
            id: map['id'] as String? ?? 'migrated_$i',
            role: role,
            content: text,
            timestampMillis:
                map['timestampMillis'] as int? ??
                (nowBase + i),
            metadataJson: map['metadataJson'] as String? ?? '{"source":"migration"}',
          ),
        );
      }
      if (imported.isEmpty) {
        return;
      }
      await _writeSession(
        key,
        AiChatSessionHiveModel(messages: _sortedCopy(imported)),
      );
      await _prefs.remove(
        '${AiChatHistoryKeys.prefsLegacyPrefix}'
        '${Uri.encodeComponent(prefsAccountSegment)}',
      );
    } catch (_) {
      // Ignore corrupt legacy payloads.
    }
  }

  /// Returns messages ascending by timestamp (optional cap from the end).
  Future<List<AiChatMessageHiveModel>> fetchWorkspaceChatHistory({
    required String prefsAccountSegment,
    required String accountId,
    required String workspaceId,
    int? limitLast,
  }) async {
    await ensureBoxOpen();
    await _migrateLegacyPrefsIfNeeded(
      prefsAccountSegment: prefsAccountSegment,
      accountId: accountId,
      workspaceId: workspaceId,
    );
    final String key = sessionStorageKey(
      accountId: accountId,
      workspaceId: workspaceId,
    );
    final List<AiChatMessageHiveModel> sorted =
        _sortedCopy(_readSession(key).messages);
    if (limitLast != null && sorted.length > limitLast) {
      return sorted.sublist(sorted.length - limitLast);
    }
    return sorted;
  }

  /// Inserts if [id] is not already present. Keeps order by timestamp; trims oldest over cap.
  Future<void> insertMessage({
    required String accountId,
    required String workspaceId,
    required AiChatMessageHiveModel message,
  }) async {
    await ensureBoxOpen();
    final String key = sessionStorageKey(
      accountId: accountId,
      workspaceId: workspaceId,
    );
    final AiChatSessionHiveModel session = _readSession(key);
    if (session.messages.any((AiChatMessageHiveModel m) => m.id == message.id)) {
      return;
    }
    final List<AiChatMessageHiveModel> next =
        <AiChatMessageHiveModel>[...session.messages, message];
    List<AiChatMessageHiveModel> sorted = _sortedCopy(next);
    if (sorted.length > AiChatHistoryLimits.maxStoredMessagesPerSession) {
      final int drop = sorted.length - AiChatHistoryLimits.maxStoredMessagesPerSession;
      sorted = sorted.sublist(drop);
    }
    await _writeSession(key, AiChatSessionHiveModel(messages: sorted));
  }

  Future<void> clearWorkspaceChatHistory({
    required String accountId,
    required String workspaceId,
  }) async {
    await ensureBoxOpen();
    final String key = sessionStorageKey(
      accountId: accountId,
      workspaceId: workspaceId,
    );
    await _box.delete(key);
  }

  /// Replaces only the `metadataJson` of a previously persisted message.
  /// No-op if the message is not found in the workspace session.
  Future<void> updateMessageMetadata({
    required String accountId,
    required String workspaceId,
    required String messageId,
    required String metadataJson,
  }) async {
    await ensureBoxOpen();
    final String key = sessionStorageKey(
      accountId: accountId,
      workspaceId: workspaceId,
    );
    final AiChatSessionHiveModel session = _readSession(key);
    bool changed = false;
    final List<AiChatMessageHiveModel> next = session.messages
        .map((AiChatMessageHiveModel m) {
          if (m.id != messageId) {
            return m;
          }
          changed = true;
          return AiChatMessageHiveModel(
            id: m.id,
            role: m.role,
            content: m.content,
            timestampMillis: m.timestampMillis,
            metadataJson: metadataJson,
          );
        })
        .toList(growable: false);
    if (!changed) {
      return;
    }
    await _writeSession(key, AiChatSessionHiveModel(messages: _sortedCopy(next)));
  }

  Future<void> deleteMessage({
    required String accountId,
    required String workspaceId,
    required String messageId,
  }) async {
    await ensureBoxOpen();
    final String key = sessionStorageKey(
      accountId: accountId,
      workspaceId: workspaceId,
    );
    final AiChatSessionHiveModel session = _readSession(key);
    final List<AiChatMessageHiveModel> next = session.messages
        .where((AiChatMessageHiveModel m) => m.id != messageId)
        .toList(growable: false);
    if (next.length == session.messages.length) {
      return;
    }
    await _writeSession(key, AiChatSessionHiveModel(messages: _sortedCopy(next)));
  }

  /// Formats recent turns for model context: chronological lines, capped.
  String buildConversationContextBlock({
    required List<AiChatMessageHiveModel> messagesAscending,
    int maxMessages = AiChatHistoryLimits.defaultContextMessageCount,
  }) {
    if (messagesAscending.isEmpty || maxMessages <= 0) {
      return '';
    }
    final Iterable<AiChatMessageHiveModel> nonEmpty =
        messagesAscending.where((AiChatMessageHiveModel m) =>
            m.content.trim().isNotEmpty,);
    final List<AiChatMessageHiveModel> usable =
        List<AiChatMessageHiveModel>.from(nonEmpty, growable: false);
    if (usable.isEmpty) {
      return '';
    }
    final int start =
        usable.length > maxMessages ? usable.length - maxMessages : 0;
    final List<AiChatMessageHiveModel> slice = usable.sublist(start);
    final StringBuffer lines = StringBuffer();
    for (final AiChatMessageHiveModel m in slice) {
      final String label =
          m.role.toLowerCase() == 'user' ? 'User' : 'Assistant';
      lines.writeln('$label: ${m.content.trim()}');
    }
    return lines.toString().trimRight();
  }
}

