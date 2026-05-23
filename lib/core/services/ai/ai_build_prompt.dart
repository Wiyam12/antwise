import 'package:antwise/core/services/ai/ai_build_plan.dart';
import 'package:antwise/core/services/ai/ai_build_schema_documentation.dart';
import 'package:antwise/core/services/ai/ai_build_workspace_snapshot.dart';

/// Prompt assets for AI **Build mode**. The model is instructed to output a
/// strict JSON object describing builder actions (no prose, no thinking).
///
/// The ekv1280 on-device model allows at most **1280 tokens total** (system +
/// user + assistant prefill + JSON output). [kBuildMaxInputChars] caps the
/// combined system + user prompt so inference stays within that window.
///
/// Two flavours are exposed:
///
/// - **Monolithic** ([buildSystemInstruction] + [buildUserTurn]): the legacy
///   single-shot path. Used as a fallback when the planner stage fails.
/// - **Plan-aware** ([buildBuilderSystemInstruction] + [buildBuilderUserTurn]):
///   the second call in the two-stage pipeline. The plan tells the builder
///   which entities matter, so we can drop the full formula reference and
///   trim the workspace context to just those entities.
abstract final class AiBuildPrompt {
  /// Rough char budget for system + user (~880 tokens at ~3.5 chars/token),
  /// leaving headroom for JSON output within the model's 1280-token cap.
  static const int kBuildMaxInputChars = 3100;

  /// Appended on build retries when the model leaks reasoning into output.
  static const String kJsonOnlyOutputSuffix =
      'OUTPUT: Start with { end with }. ONLY {"actions":[...]} — zero reasoning, '
      'zero markdown, zero text outside JSON. Each actions[] item MUST be an object '
      'with "type". NEVER put prose inside actions.';

  /// Monolithic system prompt. Used when no plan is available (planner
  /// fallback) or when a caller explicitly wants the original behaviour.
  static String buildSystemInstruction() {
    return '''
JSON-only Antwise build converter. FORBIDDEN in output: reasoning, thinking, planning, analysis, explanations, markdown, comments, prose, chain-of-thought. Think internally only.
Response=exactly one JSON object: first char { last char }. ONLY key "actions" (array of action objects). NEVER put text inside actions[].
Analyze REQ internally (domain, modules) but output ONLY executable create_*/update_*/delete_* objects.
Greenfield: infer ALL modules (pages, tables, cards, charts) — do not wait for user to list each part.
Intents:add/build→create_*;edit/rename/convert→update_*;delete→delete_*.
Card/chart formula→update_widget(pageRef,title,formula).Never update_table for cards.
Copy WORKSPACE names exactly.
When MENTIONS block is present, those refs are authoritative targets for update/delete/modify/connect.

Actions:
create_page{ref,name,icon,navigation:bottom|drawer|both|none}
create_table{ref,pageRef,name,columns:[{name,type}],kind?:standard|summary,summary?:{sourceTable,groupBy,aggregate,operation:sum|count|avg|min|max}}
create_card_widget{pageRef,tableRef,title,columnName?,formula?}
create_chart_widget{pageRef,tableRef,title,chartType:bar|line|pie,xColumn,yColumn}
update_page{name,newName?,icon?,navigation?}
update_table{name,newName?,columns?,kind?,summary?}
update_widget{pageRef,title,newTitle?,formula?,tableRef?,columnName?,chartType?,xColumn?,yColumn?}
delete_page{name}|delete_table{name}|delete_widget{pageRef,title}
col types:text|number|date|boolean|dropdown. Not build→{"actions":[]}

Ex: convert table to summary→{"actions":[{"type":"update_table","name":"Report","kind":"summary","summary":{"sourceTable":"Transactions","groupBy":"Product","aggregate":"Total Amount","operation":"sum"}}]}
Ex: weekly transactions card on Home→{"actions":[{"type":"create_card_widget","pageRef":"Home","tableRef":"Transactions","title":"Weekly Transactions","formula":"SUM(IF(Transactions.Date>=DAYS_AGO(7),IF(Transactions.Date<=TODAY(),Transactions.\\"Total Amount\\",0),0))"}]}
Ex: update card formula to last 30 days→{"actions":[{"type":"update_widget","pageRef":"Home","title":"Weekly Transactions","formula":"SUM(IF(Transactions.Date>=DAYS_AGO(30),IF(Transactions.Date<=TODAY(),Transactions.\\"Total Amount\\",0),0))"}]}
Ex: greenfield finance system→many create_page/create_table/create_card_widget/create_chart_widget for Dashboard,Accounts,Transactions,Expenses,Assets,Reports (infer all modules).

${AiBuildSchemaDocumentation.compactApplicationReference()}
''';
  }

  /// Slimmer system prompt for the plan-aware builder. Drops the long
  /// application reference because the planner already chose the action
  /// shapes and entity names.
  static String buildBuilderSystemInstruction() {
    return '''
JSON-only Antwise build converter. FORBIDDEN: reasoning, thinking, planning, analysis, explanations, markdown, comments, prose in output.
Response=exactly one JSON object {..."actions":[...]...}. First char { last char }. Each actions[] entry MUST be {"type":"create_*",...} only.
You are an application architect: infer missing pages/tables/widgets from domain intent, not only explicit PLAN steps.
PLAN may include domain+modules — generate the FULL related system (all modules) when scope is greenfield.
Map each inferred module + plan step to actions below. Copy WORKSPACE names exactly.
When MENTIONS block is present, those refs are authoritative targets for update/delete/modify/connect.

Actions:
create_page{ref,name,icon,navigation:bottom|drawer|both|none}
create_table{ref,pageRef,name,columns:[{name,type}],kind?:standard|summary,summary?:{sourceTable,groupBy,aggregate,operation:sum|count|avg|min|max}}
create_card_widget{pageRef,tableRef,title,columnName?,formula?}
create_chart_widget{pageRef,tableRef,title,chartType:bar|line|pie,xColumn,yColumn}
update_page{name,newName?,icon?,navigation?}
update_table{name,newName?,columns?,kind?,summary?}
update_widget{pageRef,title,newTitle?,formula?,tableRef?,columnName?,chartType?,xColumn?,yColumn?}
delete_page{name}|delete_table{name}|delete_widget{pageRef,title}
col types:text|number|date|boolean|dropdown. Empty plan→{"actions":[]}
Card/chart formula→update_widget(pageRef,title,formula). Never update_table for cards.

${AiBuildSchemaDocumentation.compactFormulaReference()}
''';
  }

  /// Legacy user turn (no planner). Kept for the monolithic fallback path.
  static String buildUserTurn({
    required String userPrompt,
    required AiBuildWorkspaceSnapshot snapshot,
    String intentLine = '',
    String mentionsBlock = '',
  }) {
    final String context =
        snapshot.isEmpty
            ? '{"pages":{},"tables":{}}'
            : snapshot.builderContextJson();
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('WORKSPACE:$context');
    if (intentLine.trim().isNotEmpty) {
      buffer.writeln(intentLine.trim());
    }
    if (mentionsBlock.trim().isNotEmpty) {
      buffer.writeln(mentionsBlock.trim());
    }
    buffer.writeln('REQ:${userPrompt.trim()}');
    buffer.writeln('JSON only `{` first char.');
    final int remaining = kBuildMaxInputChars - buildSystemInstruction().length;
    return _trimToCharBudget(
      buffer.toString().trimRight(),
      remaining > 256 ? remaining : 256,
    );
  }

  /// Plan-aware builder user turn. `WORKSPACE` is filtered to the entities
  /// referenced by [plan], and a `PLAN:` line carries the planner output so
  /// the builder can map steps 1:1 to actions.
  static String buildBuilderUserTurn({
    required String userPrompt,
    required AiBuildWorkspaceSnapshot snapshot,
    required AiBuildPlan plan,
    String intentLine = '',
    String mentionsBlock = '',
  }) {
    final String context =
        snapshot.isEmpty
            ? '{"pages":{},"tables":{}}'
            : snapshot.builderContextJson(plan: plan);
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('WORKSPACE:$context');
    if (intentLine.trim().isNotEmpty) {
      buffer.writeln(intentLine.trim());
    }
    if (mentionsBlock.trim().isNotEmpty) {
      buffer.writeln(mentionsBlock.trim());
    }
    buffer.writeln('PLAN:${plan.toCompactJson()}');
    if (plan.modules.isNotEmpty) {
      buffer.writeln(
        'ARCHITECT:Emit create actions for ALL modules in PLAN (pages, tables, cards, charts). '
        'Do not stop at the first step.',
      );
    }
    buffer.writeln('REQ:${userPrompt.trim()}');
    buffer.writeln('JSON only `{` first char.');
    final int remaining =
        kBuildMaxInputChars - buildBuilderSystemInstruction().length;
    return _trimToCharBudget(
      buffer.toString().trimRight(),
      remaining > 256 ? remaining : 256,
    );
  }

  /// Ensures [userTurn] fits with [systemInstruction] under [kBuildMaxInputChars].
  static String enforceInputBudget({
    required String systemInstruction,
    required String userTurn,
  }) {
    final int remaining = kBuildMaxInputChars - systemInstruction.length;
    return _trimToCharBudget(userTurn, remaining > 256 ? remaining : 256);
  }

  /// Full pre-prompt for logging (system + user turn concatenated).
  static String buildLoggablePrompt({
    required String userPrompt,
    required AiBuildWorkspaceSnapshot snapshot,
    AiBuildPlan? plan,
    String? originalUserPrompt,
    String intentLine = '',
    String mentionsBlock = '',
  }) {
    final bool hasPlan = plan != null && plan.hasSteps;
    final String systemInstruction =
        hasPlan ? buildBuilderSystemInstruction() : buildSystemInstruction();
    final String userTurn =
        hasPlan
            ? buildBuilderUserTurn(
              userPrompt: userPrompt,
              snapshot: snapshot,
              plan: plan,
              intentLine: intentLine,
              mentionsBlock: mentionsBlock,
            )
            : buildUserTurn(
              userPrompt: userPrompt,
              snapshot: snapshot,
              intentLine: intentLine,
              mentionsBlock: mentionsBlock,
            );

    final StringBuffer buffer = StringBuffer();
    buffer.writeln(hasPlan ? '# BUILDER SYSTEM (plan-aware)' : '# SYSTEM');
    buffer.writeln(systemInstruction.trim());
    buffer.writeln();
    buffer.writeln('# USER TURN');
    buffer.writeln(userTurn);
    if (originalUserPrompt != null &&
        originalUserPrompt.trim().isNotEmpty &&
        originalUserPrompt.trim() != userPrompt.trim()) {
      buffer.writeln();
      buffer.writeln('# ORIGINAL USER MESSAGE (pre-paraphrase, internal)');
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
