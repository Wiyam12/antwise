import 'dart:convert';

/// Extracts valid `{"type":"create_*",...}` action objects from noisy model text.
abstract final class AiBuildJsonSalvage {
  static const Set<String> knownActionTypes = <String>{
    'create_page',
    'create_table',
    'create_card_widget',
    'create_chart_widget',
    'update_page',
    'update_table',
    'update_widget',
    'delete_page',
    'delete_table',
    'delete_widget',
  };

  /// Builds strict `{"actions":[...]}` JSON from [raw] model continuation.
  static String rebuildActionsPayload(String raw) {
    final String cleaned = _stripNoise(raw);
    if (cleaned.isEmpty) {
      return '{"actions":[]}';
    }

    final String? full = _extractBalancedObjectWithActionsKey(cleaned);
    if (full != null) {
      final List<Map<String, dynamic>> fromFull = _filterActionMaps(
        _decodeActionsArray(full),
      );
      if (fromFull.isNotEmpty) {
        return jsonEncode(<String, dynamic>{'actions': fromFull});
      }
    }

    final List<Map<String, dynamic>> scanned = _scanActionObjects(cleaned);
    if (scanned.isNotEmpty) {
      return jsonEncode(<String, dynamic>{'actions': scanned});
    }

    if (cleaned.startsWith('[')) {
      final String wrapped = '{"actions":$cleaned}';
      final List<Map<String, dynamic>> fromArray = _filterActionMaps(
        _decodeActionsArray(wrapped),
      );
      if (fromArray.isNotEmpty) {
        return jsonEncode(<String, dynamic>{'actions': fromArray});
      }
    }

    return '{"actions":[]}';
  }

  static bool containsValidActions(String raw) {
    final String cleaned = _stripNoise(raw);
    if (cleaned.isEmpty) {
      return false;
    }
    final String? full = _extractBalancedObjectWithActionsKey(cleaned);
    if (full != null && _filterActionMaps(_decodeActionsArray(full)).isNotEmpty) {
      return true;
    }
    return _scanActionObjects(cleaned).isNotEmpty;
  }

  static String _stripNoise(String text) {
    String t = text.trim();
    const String thinkEnd = '</think>';
    final int lastEnd = t.lastIndexOf(thinkEnd);
    if (lastEnd >= 0) {
      t = t.substring(lastEnd + thinkEnd.length).trim();
    }
    t = t.replaceAll(
      RegExp(r'<think>[\s\S]*?</think>', multiLine: true),
      '',
    );
    final int openOnly = t.indexOf('<think>');
    if (openOnly >= 0) {
      t = t.substring(openOnly + '<think>'.length).trim();
    }
    t = t.replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '');
    // Drop reasoning paragraphs before the first plausible action object.
    final int typeIdx = t.indexOf('"type"');
    if (typeIdx > 0) {
      final int brace = t.lastIndexOf('{', typeIdx);
      if (brace > 0) {
        final String prefix = t.substring(0, brace).trim();
        if (_looksLikeReasoningPrefix(prefix)) {
          t = t.substring(brace);
        }
      }
    }
    return t.trim();
  }

  static bool _looksLikeReasoningPrefix(String prefix) {
    if (prefix.isEmpty) {
      return false;
    }
    if (prefix.startsWith('{') && prefix.contains('"actions"')) {
      return false;
    }
    final String lower = prefix.toLowerCase();
    return RegExp(
      r'\b(okay|ok|so|hmm|well|let me|i need to|the user|json-only|antwise|converter)\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  static String? _extractBalancedObjectWithActionsKey(String input) {
    final int start = input.indexOf('{');
    if (start < 0) {
      return null;
    }
    final int? end = _matchingBraceEnd(input, start);
    if (end == null) {
      return null;
    }
    final String candidate = input.substring(start, end + 1);
    if (!candidate.contains('"actions"')) {
      return null;
    }
    return candidate;
  }

  static List<Map<String, dynamic>> _decodeActionsArray(String jsonBody) {
    try {
      final dynamic decoded = jsonDecode(jsonBody);
      if (decoded is! Map<String, dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      final dynamic rawActions = decoded['actions'];
      if (rawActions is! List<dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
      for (final dynamic entry in rawActions) {
        if (entry is Map<String, dynamic>) {
          out.add(entry);
        }
      }
      return out;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  static List<Map<String, dynamic>> _filterActionMaps(
    List<Map<String, dynamic>> maps,
  ) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> m in maps) {
      final String type = (m['type'] as String?)?.trim().toLowerCase() ?? '';
      if (knownActionTypes.contains(type)) {
        out.add(m);
      }
    }
    return out;
  }

  static List<Map<String, dynamic>> _scanActionObjects(String input) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    final Set<String> seen = <String>{};
    int searchFrom = 0;
    while (searchFrom < input.length) {
      final int typeIdx = input.indexOf('"type"', searchFrom);
      if (typeIdx < 0) {
        break;
      }
      final int start = input.lastIndexOf('{', typeIdx);
      if (start < 0) {
        searchFrom = typeIdx + 6;
        continue;
      }
      final int? end = _matchingBraceEnd(input, start);
      if (end == null) {
        searchFrom = typeIdx + 6;
        continue;
      }
      final String fragment = input.substring(start, end + 1);
      searchFrom = end + 1;
      try {
        final dynamic decoded = jsonDecode(fragment);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final String type =
            (decoded['type'] as String?)?.trim().toLowerCase() ?? '';
        if (!knownActionTypes.contains(type)) {
          continue;
        }
        final String key = jsonEncode(decoded);
        if (seen.add(key)) {
          out.add(decoded);
        }
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  static int? _matchingBraceEnd(String input, int start) {
    int depth = 0;
    bool inString = false;
    bool escape = false;
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
          return i;
        }
      }
    }
    return null;
  }
}
