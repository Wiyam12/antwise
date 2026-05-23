import 'dart:convert';

import 'package:antwise/core/services/ai/ai_build_action.dart';
import 'package:antwise/core/services/ai/ai_build_json_salvage.dart';

/// Result of parsing raw model output into Build-mode actions.
class AiBuildActionParseResult {
  const AiBuildActionParseResult({
    required this.actions,
    required this.warnings,
    required this.fallbackText,
  });

  final List<AiBuildAction> actions;
  final List<String> warnings;

  /// Plain text fallback when no actions could be parsed (or alongside them).
  /// Useful for showing the model's prose if JSON parsing fails.
  final String fallbackText;

  bool get hasActions => actions.isNotEmpty;
}

/// Prefix written into the assistant turn so DeepSeek continues JSON instead of
/// opening a long reasoning block.
const String kAiBuildJsonPrefill = '{"actions":[';

/// Tolerantly extracts a `{"actions":[...]}` JSON object from on-device model
/// output. The model often wraps output in markdown fences, prefixes prose, or
/// streams thinking tags — we strip those before parsing.
abstract final class AiBuildActionParser {
  /// True when [raw] contains at least one salvageable executable action.
  static bool looksLikeJson(String raw) {
    if (raw.trim().isEmpty) {
      return false;
    }
    return AiBuildJsonSalvage.containsValidActions(raw);
  }

  /// Merges [kAiBuildJsonPrefill] with model continuation — never concatenates
  /// reasoning prose into the actions array.
  static String mergePrefillResponse(String modelOut) {
    final String t = _stripThinking(modelOut).trim();
    if (t.isEmpty) {
      return '{"actions":[]}';
    }
    return AiBuildJsonSalvage.rebuildActionsPayload(t);
  }

  static AiBuildActionParseResult parse(String raw) {
    final String cleaned = _stripThinking(raw).trim();
    if (cleaned.isEmpty) {
      return const AiBuildActionParseResult(
        actions: <AiBuildAction>[],
        warnings: <String>[],
        fallbackText: '',
      );
    }

    final String salvaged = AiBuildJsonSalvage.rebuildActionsPayload(cleaned);
    return _parseActionsPayload(
      salvaged,
      warnings: <String>[],
      fallbackSource: cleaned,
    );
  }

  static AiBuildActionParseResult _parseActionsPayload(
    String jsonBody, {
    required List<String> warnings,
    required String fallbackSource,
  }) {
    final List<AiBuildAction> actions = <AiBuildAction>[];

    try {
      final dynamic decoded = jsonDecode(jsonBody);
      if (decoded is! Map<String, dynamic>) {
        warnings.add('Build payload was not a JSON object.');
        return AiBuildActionParseResult(
          actions: const <AiBuildAction>[],
          warnings: warnings,
          fallbackText: fallbackSource,
        );
      }
      final List<dynamic>? rawActions = decoded['actions'] as List<dynamic>?;
      if (rawActions == null) {
        warnings.add('Build payload was missing an "actions" array.');
        return AiBuildActionParseResult(
          actions: const <AiBuildAction>[],
          warnings: warnings,
          fallbackText: fallbackSource,
        );
      }
      for (int i = 0; i < rawActions.length; i++) {
        final dynamic entry = rawActions[i];
        if (entry is! Map<String, dynamic>) {
          warnings.add('Skipped action #${i + 1}: not an object (reasoning text rejected).');
          continue;
        }
        final Map<String, dynamic> normalized = _normalizeActionJson(entry);
        final AiBuildAction? action = AiBuildAction.fromJson(normalized);
        if (action == null) {
          warnings.add('Skipped action #${i + 1}: unknown or invalid "type".');
          continue;
        }
        final String? invalidReason = _validateAction(action);
        if (invalidReason != null) {
          warnings.add('Skipped action #${i + 1}: $invalidReason');
          continue;
        }
        actions.add(action);
      }
    } catch (e) {
      warnings.add('JSON parse error: $e');
      return AiBuildActionParseResult(
        actions: const <AiBuildAction>[],
        warnings: warnings,
        fallbackText: fallbackSource,
      );
    }

    if (actions.isEmpty && rawActionsLeakReasoning(fallbackSource)) {
      warnings.add(
        'Model output contained reasoning instead of JSON; no executable actions extracted.',
      );
    }

    return AiBuildActionParseResult(
      actions: actions,
      warnings: warnings,
      fallbackText: actions.isEmpty ? fallbackSource : '',
    );
  }

  static bool rawActionsLeakReasoning(String raw) {
    final String lower = raw.toLowerCase();
    return RegExp(
      r'\b(okay|let me|i need to|the user|chain.of.thought|json-only antwise)\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  /// Fixes common model mistakes (e.g. `update_table` with widget fields).
  static Map<String, dynamic> _normalizeActionJson(Map<String, dynamic> json) {
    final String type = (json['type'] as String?)?.trim().toLowerCase() ?? '';
    if (type != 'update_table') {
      return json;
    }
    final bool looksLikeWidget = json.containsKey('pageRef') ||
        json.containsKey('title') ||
        (json['formula'] as String?)?.trim().isNotEmpty == true;
    final bool looksLikeTable = json.containsKey('columns') ||
        json.containsKey('kind') ||
        json.containsKey('summary');
    if (!looksLikeWidget || looksLikeTable) {
      return json;
    }
    final String title =
        (json['title'] as String?)?.trim().isNotEmpty == true
            ? (json['title'] as String).trim()
            : (json['name'] as String?)?.trim() ?? '';
    return <String, dynamic>{
      'type': 'update_widget',
      'pageRef': (json['pageRef'] as String?)?.trim() ?? '',
      'title': title,
      if (json['newTitle'] != null) 'newTitle': json['newTitle'],
      if (json['tableRef'] != null) 'tableRef': json['tableRef'],
      if (json['formula'] != null) 'formula': json['formula'],
      if (json['columnName'] != null) 'columnName': json['columnName'],
      'status': json['status'],
      if (json['failureReason'] != null) 'failureReason': json['failureReason'],
    };
  }

  static String _stripThinking(String text) {
    String t = text;
    // DeepSeek-style closing thinking tag (no opener) — drop everything up to
    // and including the LAST </think>.
    const String thinkEnd = '</think>';
    final int lastEnd = t.lastIndexOf(thinkEnd);
    if (lastEnd >= 0) {
      t = t.substring(lastEnd + thinkEnd.length);
    }
    t = t.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    t = t.replaceAll(
      RegExp(r'<redacted_thinking>.*?</redacted_thinking>', dotAll: true),
      '',
    );
    // Open-only <think> (model ran out of tokens before closing) — keep
    // anything after the unmatched opener in case JSON appears below it.
    final int openOnly = t.indexOf('<think>');
    if (openOnly >= 0) {
      t = t.substring(openOnly + '<think>'.length);
    }
    // Markdown fences.
    t = t.replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '');
    return t.trim();
  }

  static String? _validateAction(AiBuildAction action) {
    switch (action) {
      case CreatePageAction(:final String name):
        if (name.trim().isEmpty) {
          return 'page "name" is required.';
        }
        return null;
      case CreateTableAction(
        :final String pageRef,
        :final String name,
        :final List<AiBuildColumnSpec> columns,
        :final AiBuildTableKind tableKind,
        :final AiBuildSummarySpec? summary,
      ):
        if (name.trim().isEmpty) {
          return 'table "name" is required.';
        }
        if (pageRef.trim().isEmpty) {
          return 'table "pageRef" is required.';
        }
        if (tableKind == AiBuildTableKind.summary) {
          if (summary == null) {
            return 'summary table needs a "summary" block.';
          }
          return null;
        }
        if (columns.isEmpty) {
          return 'table needs at least one column.';
        }
        return null;
      case CreateCardWidgetAction(
        :final String pageRef,
        :final String title,
        :final String tableRef,
        :final String columnName,
        :final String formula,
      ):
        if (pageRef.trim().isEmpty) {
          return 'card "pageRef" is required.';
        }
        if (title.trim().isEmpty) {
          return 'card "title" is required.';
        }
        if (tableRef.trim().isEmpty &&
            columnName.trim().isEmpty &&
            formula.trim().isEmpty) {
          return 'card needs at least a tableRef + columnName or a formula.';
        }
        return null;
      case CreateChartWidgetAction(
        :final String pageRef,
        :final String tableRef,
        :final String title,
        :final String xColumn,
        :final String yColumn,
      ):
        if (pageRef.trim().isEmpty) {
          return 'chart "pageRef" is required.';
        }
        if (tableRef.trim().isEmpty) {
          return 'chart "tableRef" is required.';
        }
        if (title.trim().isEmpty) {
          return 'chart "title" is required.';
        }
        if (xColumn.trim().isEmpty || yColumn.trim().isEmpty) {
          return 'chart needs both xColumn and yColumn.';
        }
        return null;
      case UpdatePageAction(:final String name):
        if (name.trim().isEmpty) {
          return 'update_page "name" is required.';
        }
        return null;
      case UpdateTableAction(
        :final String name,
        :final List<AiBuildColumnSpec> columns,
        :final AiBuildTableKind tableKind,
        :final AiBuildSummarySpec? summary,
      ):
        if (name.trim().isEmpty) {
          return 'update_table "name" is required.';
        }
        if (tableKind == AiBuildTableKind.summary) {
          if (summary == null) {
            return 'summary update needs a "summary" block.';
          }
          return null;
        }
        if (columns.isEmpty) {
          return 'update_table needs at least one column.';
        }
        return null;
      case UpdateWidgetAction(:final String pageRef, :final String title):
        if (pageRef.trim().isEmpty) {
          return 'update_widget "pageRef" is required.';
        }
        if (title.trim().isEmpty) {
          return 'update_widget "title" is required.';
        }
        return null;
      case DeletePageAction(:final String name):
        if (name.trim().isEmpty) {
          return 'delete_page "name" is required.';
        }
        return null;
      case DeleteTableAction(:final String name):
        if (name.trim().isEmpty) {
          return 'delete_table "name" is required.';
        }
        return null;
      case DeleteWidgetAction(:final String pageRef, :final String title):
        if (pageRef.trim().isEmpty) {
          return 'delete_widget "pageRef" is required.';
        }
        if (title.trim().isEmpty) {
          return 'delete_widget "title" is required.';
        }
        return null;
    }
  }
}
