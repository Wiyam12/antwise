import 'package:antwise/core/services/ai/ai_build_workspace_snapshot.dart';

/// Prompt assets for the **planner** stage of Build mode. The planner outputs
/// a compact `{"steps":[...], "refs":{...}}` JSON object that the builder
/// stage uses to focus its context. Keeping this prompt small (no full
/// schema, no per-table column dump) means we get a much shorter input than
/// today's monolithic build prompt.
abstract final class AiBuildPlannerPrompt {
  /// Char budget for the planner system + user. ekv1280 caps total tokens at
  /// 1280; a ~512-token planner output target gives the prompt ~1700 chars.
  static const int kPlannerMaxInputChars = 1700;

  /// System instruction. Short on purpose — no action schema, just the shape
  /// of the planner JSON.
  static String buildSystemInstruction() {
    return '''
JSON-only Antwise build planner. FORBIDDEN in output: reasoning, thinking, analysis text, explanations, markdown, comments, prose.
Output exactly one object starting with `{` ending with `}`. Schema only:
{"steps":["..."],"domain":"finance|pos|gym|...","modules":["..."],"refs":{"pages":[],"tables":[],"widgets":[]}}
Analyze REQ internally (domain, greenfield vs edit, modules) but emit ONLY short step strings in steps[].
One step per future action. 4-10 words. refs=exact WORKSPACE names only.
When MENTIONS block is present, use those refs as authoritative targets.
Not a build→{"steps":[]}.
''';
  }

  /// User turn embedding the compact workspace name index + the paraphrased
  /// request. No column details here — the builder stage adds those when it
  /// knows which tables the plan touched.
  static String buildUserTurn({
    required String userPrompt,
    required AiBuildWorkspaceSnapshot snapshot,
    String intentLine = '',
    String mentionsBlock = '',
  }) {
    final String index = snapshot.isEmpty
        ? '{"pages":{},"tables":[]}'
        : snapshot.nameIndexJson();
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('INDEX:$index');
    if (intentLine.trim().isNotEmpty) {
      buffer.writeln(intentLine.trim());
    }
    if (mentionsBlock.trim().isNotEmpty) {
      buffer.writeln(mentionsBlock.trim());
    }
    buffer.writeln('REQ:${userPrompt.trim()}');
    buffer.writeln('JSON only `{` first char.');
    final int remaining =
        kPlannerMaxInputChars - buildSystemInstruction().length;
    return _trimToCharBudget(
      buffer.toString().trimRight(),
      remaining > 256 ? remaining : 256,
    );
  }

  /// Ensures [userTurn] fits with [systemInstruction] under
  /// [kPlannerMaxInputChars]. Mirrors [AiBuildPrompt.enforceInputBudget].
  static String enforceInputBudget({
    required String systemInstruction,
    required String userTurn,
  }) {
    final int remaining = kPlannerMaxInputChars - systemInstruction.length;
    return _trimToCharBudget(userTurn, remaining > 256 ? remaining : 256);
  }

  /// Pre-prompt for logging (system + user turn concatenated).
  static String buildLoggablePrompt({
    required String userPrompt,
    required AiBuildWorkspaceSnapshot snapshot,
    String? originalUserPrompt,
    String intentLine = '',
    String mentionsBlock = '',
  }) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('# PLANNER SYSTEM');
    buffer.writeln(buildSystemInstruction().trim());
    buffer.writeln();
    buffer.writeln('# PLANNER USER TURN');
    buffer.writeln(
      buildUserTurn(
        userPrompt: userPrompt,
        snapshot: snapshot,
        intentLine: intentLine,
        mentionsBlock: mentionsBlock,
      ),
    );
    if (originalUserPrompt != null &&
        originalUserPrompt.trim().isNotEmpty &&
        originalUserPrompt.trim() != userPrompt.trim()) {
      buffer.writeln();
      buffer.writeln('# ORIGINAL USER MESSAGE');
      buffer.writeln(originalUserPrompt.trim());
    }
    return buffer.toString().trimRight();
  }

  static String _trimToCharBudget(String text, int maxChars) {
    if (maxChars <= 0 || text.length <= maxChars) {
      return text;
    }
    if (maxChars < 32) {
      return text.substring(0, maxChars);
    }
    return '${text.substring(0, maxChars - 1)}…';
  }
}
