import 'dart:convert';

import 'package:antwise/core/services/ai/ai_build_plan.dart';

/// Prefix written into the planner assistant turn so the model continues
/// JSON instead of opening a long reasoning block.
const String kAiBuildPlanJsonPrefill = '{"steps":[';

/// Tolerant parser for the planner stage. Mirrors the conventions used by
/// [AiBuildActionParser] (strip thinking tags / markdown fences / extract the
/// first balanced `{...}` containing `"steps"`).
abstract final class AiBuildPlanParser {
  /// Returns true when [raw] (after thinking-strip) contains a parseable
  /// planner object.
  static bool looksLikeJson(String raw) {
    final String cleaned = _stripThinking(raw).trim();
    if (cleaned.isEmpty) {
      return false;
    }
    return _extractJsonObject(cleaned) != null;
  }

  /// Merges [kAiBuildPlanJsonPrefill] with model continuation text.
  static String mergePrefillResponse(String modelOut) {
    final String t = _stripThinking(modelOut).trim();
    if (t.isEmpty) {
      return kAiBuildPlanJsonPrefill;
    }
    if (_extractJsonObject(t) != null) {
      return _extractJsonObject(t)!;
    }
    if (t.startsWith('[')) {
      return '{"steps":$t}';
    }
    String fragment = t;
    if (!fragment.startsWith('{')) {
      fragment = '{$fragment}';
    }
    return '$kAiBuildPlanJsonPrefill$fragment';
  }

  /// Returns `null` when the raw output cannot be parsed into a plan. Callers
  /// should fall back to the monolithic build pipeline in that case.
  static AiBuildPlan? parse(String raw) {
    final String cleaned = _stripThinking(raw).trim();
    if (cleaned.isEmpty) {
      return null;
    }
    final String? body = _extractJsonObject(cleaned);
    if (body == null) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final List<dynamic>? rawSteps = decoded['steps'] as List<dynamic>?;
      if (rawSteps == null) {
        return null;
      }
      final List<String> steps = <String>[
        for (final dynamic raw in rawSteps)
          if (raw is String && raw.trim().isNotEmpty) raw.trim(),
      ];

      Set<String> readRefs(dynamic refs, String key) {
        if (refs is! Map<String, dynamic>) {
          return const <String>{};
        }
        final dynamic list = refs[key];
        if (list is! List<dynamic>) {
          return const <String>{};
        }
        final Set<String> out = <String>{};
        for (final dynamic entry in list) {
          if (entry is String && entry.trim().isNotEmpty) {
            out.add(entry.trim());
          }
        }
        return out;
      }

      final dynamic refs = decoded['refs'];
      final String domain = (decoded['domain'] as String?)?.trim() ?? '';
      final List<String> modules = <String>[
        if (decoded['modules'] is List<dynamic>)
          for (final dynamic m in decoded['modules'] as List<dynamic>)
            if (m is String && m.trim().isNotEmpty) m.trim(),
      ];
      return AiBuildPlan(
        steps: steps,
        pageRefs: readRefs(refs, 'pages'),
        tableRefs: readRefs(refs, 'tables'),
        widgetRefs: readRefs(refs, 'widgets'),
        rawJson: body,
        domain: domain,
        modules: modules,
      );
    } catch (_) {
      return null;
    }
  }

  static String _stripThinking(String text) {
    String t = text;
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
    final int openOnly = t.indexOf('<think>');
    if (openOnly >= 0) {
      t = t.substring(openOnly + '<think>'.length);
    }
    t = t.replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '');
    return t.trim();
  }

  /// Returns the first balanced `{...}` substring containing `"steps"`.
  static String? _extractJsonObject(String input) {
    final int start = input.indexOf('{');
    if (start < 0) {
      return null;
    }
    int depth = 0;
    bool inString = false;
    bool escape = false;
    int end = -1;
    for (int i = start; i < input.length; i++) {
      final String ch = input[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (ch == r'\') {
        escape = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) {
        continue;
      }
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    if (end < 0) {
      return null;
    }
    final String candidate = input.substring(start, end + 1);
    if (!candidate.contains('"steps"')) {
      return null;
    }
    return candidate;
  }
}
