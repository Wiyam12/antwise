import 'dart:convert';

import 'package:antwise/core/services/ai/ai_hive_json_extractor.dart';
import 'package:antwise/core/services/ai/ai_prompt_paraphraser.dart';

/// Builds the on-device model pre-prompt from the standard app template.
abstract final class AiPromptBuilder {
  static const String _intro =
      'You are a helpful AI chat assistant integrated into a mobile application.\n'
      '\n'
      'You answer general questions directly. For questions about the user\'s '
      'workspace (tables, products, transactions, counts, totals), use the '
      'provided JSON as the only source of truth.';

  static const String _dataSectionHeader =
      '## APPLICATION DATA (JSON CONTEXT)\n'
      '\n'
      'The following JSON represents the current state of the application for the user.\n'
      'It may include transactions, users, items, computed summaries, and other related records.\n'
      '\n'
      'Use this data directly to answer user questions.';

  static const String _responseRules =
      '## RESPONSE RULES\n'
      '\n'
      '* Give the answer first in 1–3 short sentences.\n'
      '* Never show reasoning, planning, or step-by-step thinking.\n'
      '* Never say "let me look", "I need to figure out", or describe your process.\n'
      '\n'
      '**Workspace / app data questions** (tables, products, sales, counts):\n'
      '* Use ONLY the JSON below.\n'
      '* For counts, use each table\'s `row_count` when records are empty.\n'
      '* Do NOT invent or assume missing data.\n'
      '* If not in the JSON, say it is not in the provided data.\n'
      '\n'
      '**General knowledge questions** (science, definitions, how things work):\n'
      '* Answer directly from general knowledge.\n'
      '* Do NOT search, cite, or mention the JSON, tables, or records.';

  /// Static guidance passed via [InferenceModelSession.createSession].
  static String buildSystemInstruction() {
    return '$_intro\n\n---\n\n$_responseRules';
  }

  /// User turn: JSON context block and the user question.
  static String buildUserTurn({
    required String userPrompt,
    required AiHiveContextPayload hiveContext,
    String tableOutlineFallback = '',
    String workspaceMentionsBlock = '',
  }) {
    final String question = userPrompt.trim();
    final String jsonBody = _resolveJsonBody(
      hiveContext: hiveContext,
      tableOutlineFallback: tableOutlineFallback,
    );

    final String questionTypeBlock =
        isWorkspaceQuestion(question)
            ? '## QUESTION TYPE\n'
                '\n'
                'Workspace data — answer using the JSON below only.\n'
            : '## QUESTION TYPE\n'
                '\n'
                'General knowledge — not about the JSON below. '
                'Answer the question directly; ignore the application data.\n';

    return '$_dataSectionHeader\n'
        '\n'
        '```json\n'
        '$jsonBody\n'
        '```\n'
        '\n'
        '---\n'
        '\n'
        '$questionTypeBlock'
        '\n'
        '---\n'
        '\n'
        '${_mentionsSection(workspaceMentionsBlock)}'
        '## USER QUESTION\n'
        '\n'
        '$question';
  }

  static String _mentionsSection(String workspaceMentionsBlock) {
    if (workspaceMentionsBlock.trim().isEmpty) {
      return '';
    }
    return '${workspaceMentionsBlock.trim()}\n'
        '\n'
        '---\n'
        '\n';
  }

  /// True when the user is asking about app tables, records, or workspace metrics.
  static bool isWorkspaceQuestion(String userPrompt) {
    final String q = userPrompt.trim().toLowerCase();
    if (q.isEmpty) {
      return false;
    }

    const List<String> workspaceSignals = <String>[
      'table',
      'product',
      'category',
      'transaction',
      'record',
      'row',
      'workspace',
      'inventory',
      'stock',
      'summary',
      'total amount',
      'total qty',
      'how many',
      'number of',
      'count of',
      'in my app',
      'in the app',
      'in my data',
    ];

    if (workspaceSignals.any((String s) => q.contains(s))) {
      return true;
    }

    const List<String> generalPrefixes = <String>[
      'what is ',
      'what are ',
      'who is ',
      'who are ',
      'define ',
      'explain ',
      'why is ',
      'why are ',
      'how does ',
      'how do ',
    ];

    if (generalPrefixes.any((String s) => q.startsWith(s))) {
      return false;
    }

    return false;
  }

  /// Full pre-prompt for logging (system + user turn combined).
  ///
  /// When [originalUserPrompt] is set, the logged `## USER QUESTION` section
  /// includes both the raw chat text and the paraphrased version used for inference.
  static String buildFullPrompt({
    required String userPrompt,
    required AiHiveContextPayload hiveContext,
    String tableOutlineFallback = '',
    String? originalUserPrompt,
  }) {
    final String userTurn = buildUserTurn(
      userPrompt: userPrompt,
      hiveContext: hiveContext,
      tableOutlineFallback: tableOutlineFallback,
    );
    if (originalUserPrompt == null) {
      return '${buildSystemInstruction()}\n\n---\n\n$userTurn';
    }
    final String loggedQuestion =
        AiPromptParaphraser.buildLoggedUserQuestionSection(
      original: originalUserPrompt,
      paraphrased: userPrompt,
    );
    final String userTurnForLog = userTurn.replaceFirst(
      RegExp(r'## USER QUESTION\n\n[\s\S]*$'),
      loggedQuestion,
    );
    return '${buildSystemInstruction()}\n\n---\n\n$userTurnForLog';
  }

  /// Answers simple counting questions from JSON metadata without the model.
  static String? tryDirectAnswerFromContext(
    String userPrompt,
    AiHiveContextPayload hiveContext,
  ) {
    final String q = userPrompt.trim().toLowerCase();
    if (q.isEmpty) {
      return null;
    }

    final bool asksTableCount =
        RegExp(
          r'\b(how many|number of|count of)\b',
          caseSensitive: false,
        ).hasMatch(q) &&
        RegExp(r'\btables?\b', caseSensitive: false).hasMatch(q);

    if (asksTableCount) {
      if (hiveContext.tableNames.isEmpty) {
        return 'There are no tables in the provided JSON data.';
      }
      final int n = hiveContext.tableNames.length;
      final String names = hiveContext.tableNames.join(', ');
      return n == 1
          ? 'You have 1 table: $names.'
          : 'You have $n tables: $names.';
    }

    final String? rowCountReply = _tryRowCountAnswer(q, hiveContext);
    if (rowCountReply != null) {
      return rowCountReply;
    }

    return null;
  }

  static String? _tryRowCountAnswer(
    String questionLower,
    AiHiveContextPayload hiveContext,
  ) {
    final bool asksCount = RegExp(
      r'\b(how many|how mny|number of|count of|total)\b',
      caseSensitive: false,
    ).hasMatch(questionLower) ||
        RegExp(
          r'\bhow\s+\w+\s+(products?|items?|records?|rows?)\s+(do\s+)?i\s+(have|own)\b',
          caseSensitive: false,
        ).hasMatch(questionLower);
    if (!asksCount) {
      return null;
    }

    final List<String> keywords = _extractCountKeywords(questionLower);
    if (keywords.isEmpty) {
      return null;
    }

    final bool mentionsSummary = questionLower.contains('summary');

    final ({String tableKey, int count})? match = _matchRowCountTable(
      keywords: keywords,
      rowCountByTableName: hiveContext.rowCountByTableName,
      skipSummaryTables: !mentionsSummary,
    );
    if (match == null) {
      return null;
    }
    final String matchedTable = match.tableKey;
    final int matchedCount = match.count;

    final String entity = _entityNounFromKeywords(keywords, matchedTable);
    if (matchedCount == 0) {
      return 'You have 0 $entity.';
    }
    if (matchedCount == 1) {
      final String singular =
          entity.endsWith('s') && entity.length > 1
              ? entity.substring(0, entity.length - 1)
              : entity;
      return 'You have 1 $singular.';
    }
    return 'You have $matchedCount $entity.';
  }

  static String _entityNounFromKeywords(
    List<String> keywords,
    String matchedTableLower,
  ) {
    for (final String keyword in keywords) {
      if (keyword == 'product' || keyword == 'products') {
        return 'products';
      }
      if (keyword == 'category' || keyword == 'categories') {
        return 'categories';
      }
      if (keyword == 'transaction' || keyword == 'transactions') {
        return 'transactions';
      }
      if (keyword == 'record' || keyword == 'records') {
        return 'records';
      }
      if (keyword == 'row' || keyword == 'rows') {
        return 'rows';
      }
      if (keyword == 'item' || keyword == 'items') {
        return 'products';
      }
    }
    if (matchedTableLower == 'products') {
      return 'products';
    }
    return matchedTableLower.endsWith('s')
        ? matchedTableLower
        : '${matchedTableLower}s';
  }

  static ({String tableKey, int count})? _matchRowCountTable({
    required List<String> keywords,
    required Map<String, int> rowCountByTableName,
    required bool skipSummaryTables,
  }) {
    for (final MapEntry<String, int> entry in rowCountByTableName.entries) {
      final String tableKey = entry.key;
      if (skipSummaryTables && tableKey.contains('summary')) {
        continue;
      }
      for (final String keyword in keywords) {
        if (_keywordMatchesTable(keyword, tableKey)) {
          return (tableKey: tableKey, count: entry.value);
        }
      }
    }

    const Map<String, String> keywordToTable = <String, String>{
      'item': 'products',
      'items': 'products',
      'product': 'products',
      'category': 'categories',
      'transaction': 'transactions',
    };
    for (final String keyword in keywords) {
      final String? hintedTable = keywordToTable[keyword];
      if (hintedTable != null && rowCountByTableName.containsKey(hintedTable)) {
        return (tableKey: hintedTable, count: rowCountByTableName[hintedTable]!);
      }
    }

    return null;
  }

  static bool _keywordMatchesTable(String keyword, String tableKeyLower) {
    return tableKeyLower == keyword ||
        tableKeyLower == '${keyword}s' ||
        (tableKeyLower.endsWith('s') &&
            tableKeyLower.substring(0, tableKeyLower.length - 1) == keyword);
  }

  static List<String> _extractCountKeywords(String questionLower) {
    final List<String> keywords = <String>[];
    const List<String> entities = <String>[
      'products',
      'product',
      'categories',
      'category',
      'transactions',
      'transaction',
      'customers',
      'customer',
      'orders',
      'order',
      'items',
      'item',
      'records',
      'record',
      'rows',
      'row',
    ];
    for (final String entity in entities) {
      if (questionLower.contains(entity)) {
        keywords.add(entity.endsWith('s') ? entity : '${entity}s');
        keywords.add(
          entity.endsWith('s')
              ? entity.substring(0, entity.length - 1)
              : entity,
        );
      }
    }
    return keywords.toSet().toList();
  }

  static String _resolveJsonBody({
    required AiHiveContextPayload hiveContext,
    required String tableOutlineFallback,
  }) {
    final String json = hiveContext.jsonBlock.trim();
    if (json.isNotEmpty) {
      return json;
    }
    final String outline = tableOutlineFallback.trim();
    if (outline.isNotEmpty) {
      return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'note': 'Structured row JSON unavailable; workspace outline follows.',
        'workspace_outline': outline,
      });
    }
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'note': 'No application records are available in local storage.',
    });
  }
}
