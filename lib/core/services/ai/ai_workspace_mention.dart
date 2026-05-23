import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/builder_page_hive_model.dart';
import 'package:antwise/data/models/hive/builder_widget_hive_model.dart';
import 'package:antwise/data/models/hive/table_schema_hive_model.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Kind of workspace entity referenced with `@` in AI chat.
enum AiWorkspaceMentionKind {
  page,
  table,
  summaryTable,
  cardWidget,
  chartWidget,
}

/// One selectable `@` mention from the active account workspace.
final class AiWorkspaceMention {
  const AiWorkspaceMention({
    required this.id,
    required this.kind,
    required this.displayLabel,
    required this.insertText,
    required this.canonicalRef,
    this.pageName = '',
    this.subtitle = '',
  });

  final String id;
  final AiWorkspaceMentionKind kind;
  final String displayLabel;
  final String insertText;
  final String canonicalRef;
  final String pageName;
  final String subtitle;

  String get categoryLabel => switch (kind) {
        AiWorkspaceMentionKind.page => 'Page',
        AiWorkspaceMentionKind.table => 'Table',
        AiWorkspaceMentionKind.summaryTable => 'Summary',
        AiWorkspaceMentionKind.cardWidget => 'Card',
        AiWorkspaceMentionKind.chartWidget => 'Chart',
      };

  IconData get icon => switch (kind) {
        AiWorkspaceMentionKind.page => Icons.article_outlined,
        AiWorkspaceMentionKind.table => Icons.table_chart_outlined,
        AiWorkspaceMentionKind.summaryTable => Icons.summarize_outlined,
        AiWorkspaceMentionKind.cardWidget => Icons.credit_card_outlined,
        AiWorkspaceMentionKind.chartWidget => Icons.show_chart_outlined,
      };

  String get emoji => switch (kind) {
        AiWorkspaceMentionKind.page => '📄',
        AiWorkspaceMentionKind.table => '📊',
        AiWorkspaceMentionKind.summaryTable => '🧾',
        AiWorkspaceMentionKind.cardWidget => '💳',
        AiWorkspaceMentionKind.chartWidget => '📈',
      };
}

/// Appends [kindLabel] only when [name] does not already end with it
/// (avoids labels like "Attendance Summary Summary").
String aiWorkspaceMentionKindSuffix(String name, String kindLabel) {
  final String trimmed = name.trim();
  final String lower = trimmed.toLowerCase();
  final String kind = kindLabel.trim().toLowerCase();
  if (kind.isEmpty || lower.endsWith(kind)) {
    return '';
  }
  return ' $kindLabel';
}

/// Loads mentionable workspace entities and builds AI prompt context.
final class AiWorkspaceMentionCatalog {
  AiWorkspaceMentionCatalog._(this.items);

  final List<AiWorkspaceMention> items;

  @visibleForTesting
  factory AiWorkspaceMentionCatalog.fromItems(List<AiWorkspaceMention> items) {
    return AiWorkspaceMentionCatalog._(items);
  }

  static AiWorkspaceMentionCatalog load() {
    final Map<String, String> pageNameById = <String, String>{};
    final List<AiWorkspaceMention> out = <AiWorkspaceMention>[];

    if (Hive.isBoxOpen(HiveBoxes.pagesBox)) {
      final List<BuilderPageHiveModel> pages =
          Hive.box<BuilderPageHiveModel>(HiveBoxes.pagesBox).values
              .where(
                (BuilderPageHiveModel p) =>
                    !p.isDeleted && p.name.trim().isNotEmpty,
              )
              .toList(growable: false)
            ..sort(
              (BuilderPageHiveModel a, BuilderPageHiveModel b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      for (final BuilderPageHiveModel p in pages) {
        final String name = p.name.trim();
        pageNameById[p.id] = name;
        final String pageSuffix = aiWorkspaceMentionKindSuffix(name, 'Page');
        final String pageLabel = '$name$pageSuffix';
        out.add(
          AiWorkspaceMention(
            id: p.id,
            kind: AiWorkspaceMentionKind.page,
            displayLabel: pageLabel,
            insertText: '@$pageLabel',
            canonicalRef: 'page:$name',
          ),
        );
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.tablesBox)) {
      for (final TableSchemaHiveModel t
          in Hive.box<TableSchemaHiveModel>(HiveBoxes.tablesBox).values) {
        final String name = t.name.trim();
        if (name.isEmpty) {
          continue;
        }
        final String pageName = pageNameById[t.pageId] ?? '';
        final bool isSummary = t.tableKind.trim().toLowerCase() == 'summary';
        final AiWorkspaceMentionKind kind = isSummary
            ? AiWorkspaceMentionKind.summaryTable
            : AiWorkspaceMentionKind.table;
        final String tableSuffix = aiWorkspaceMentionKindSuffix(
          name,
          isSummary ? 'Summary' : 'Table',
        );
        final String tableLabel = '$name$tableSuffix';
        out.add(
          AiWorkspaceMention(
            id: t.id,
            kind: kind,
            displayLabel: tableLabel,
            insertText: '@$tableLabel',
            canonicalRef: 'table:$name',
            pageName: pageName,
            subtitle: pageName.isEmpty ? '' : 'On $pageName',
          ),
        );
      }
    }

    if (Hive.isBoxOpen(HiveBoxes.widgetsBox)) {
      for (final BuilderWidgetHiveModel w
          in Hive.box<BuilderWidgetHiveModel>(HiveBoxes.widgetsBox).values) {
        final String title = (w.config['title'] as String?)?.trim() ?? '';
        if (title.isEmpty) {
          continue;
        }
        final String pageName = pageNameById[w.pageId] ?? '';
        final String type = w.type.trim().toLowerCase();
        if (type == 'card') {
          final String cardSuffix = aiWorkspaceMentionKindSuffix(title, 'Card');
          final String cardLabel = '$title$cardSuffix';
          out.add(
            AiWorkspaceMention(
              id: w.id,
              kind: AiWorkspaceMentionKind.cardWidget,
              displayLabel: cardLabel,
              insertText: '@$cardLabel',
              canonicalRef: 'widget:$title',
              pageName: pageName,
              subtitle: pageName.isEmpty ? '' : 'On $pageName',
            ),
          );
        } else if (type == 'chart') {
          final String chartSuffix =
              aiWorkspaceMentionKindSuffix(title, 'Chart');
          final String chartLabel = '$title$chartSuffix';
          out.add(
            AiWorkspaceMention(
              id: w.id,
              kind: AiWorkspaceMentionKind.chartWidget,
              displayLabel: chartLabel,
              insertText: '@$chartLabel',
              canonicalRef: 'widget:$title',
              pageName: pageName,
              subtitle: pageName.isEmpty ? '' : 'On $pageName',
            ),
          );
        }
      }
    }

    out.sort(
      (AiWorkspaceMention a, AiWorkspaceMention b) =>
          a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase()),
    );
    return AiWorkspaceMentionCatalog._(out);
  }

  /// Fuzzy filter for the `@` popup ([query] is text after `@`, no spaces at start).
  List<AiWorkspaceMention> search(String query, {int limit = 12}) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return items.take(limit).toList(growable: false);
    }
    final List<_ScoredMention> scored = <_ScoredMention>[];
    for (final AiWorkspaceMention m in items) {
      final int score = _score(m, q);
      if (score > 0) {
        scored.add(_ScoredMention(m, score));
      }
    }
    scored.sort(( _ScoredMention a, _ScoredMention b) => b.score.compareTo(a.score));
    return scored.take(limit).map(( _ScoredMention e) => e.mention).toList(growable: false);
  }

  static int _score(AiWorkspaceMention m, String q) {
    final String label = m.displayLabel.toLowerCase();
    final String page = m.pageName.toLowerCase();
    final String kind = m.categoryLabel.toLowerCase();
    if (label == q) {
      return 1000;
    }
    if (label.startsWith(q)) {
      return 800 + q.length;
    }
    if (label.contains(q)) {
      return 500 + q.length;
    }
    if (page.contains(q)) {
      return 300;
    }
    if (kind.contains(q)) {
      return 200;
    }
    final List<String> parts = q.split(RegExp(r'\s+'));
    if (parts.every((String p) => label.contains(p))) {
      return 400;
    }
    return 0;
  }

  /// Resolves mentions present in [message] (longest labels first).
  List<AiWorkspaceMention> resolveFromMessage(String message) {
    if (message.trim().isEmpty) {
      return const <AiWorkspaceMention>[];
    }
    final List<AiWorkspaceMention> sorted = List<AiWorkspaceMention>.from(items)
      ..sort(
        (AiWorkspaceMention a, AiWorkspaceMention b) =>
            b.insertText.length.compareTo(a.insertText.length),
      );
    final List<AiWorkspaceMention> found = <AiWorkspaceMention>[];
    final Set<String> seen = <String>{};
    for (final AiWorkspaceMention m in sorted) {
      if (message.contains(m.insertText) && seen.add(m.canonicalRef)) {
        found.add(m);
      }
    }
    return found;
  }

  /// Prompt block injected for Ask / Build when the user @-mentioned resources.
  String buildPromptBlock(List<AiWorkspaceMention> mentions) {
    if (mentions.isEmpty) {
      return '';
    }
    final StringBuffer b = StringBuffer()
      ..writeln('MENTIONS (authoritative — use these EXACT workspace names as targets):');
    for (final AiWorkspaceMention m in mentions) {
      final String pageBit =
          m.pageName.isEmpty ? '' : ' page="${m.pageName}"';
      b.writeln(
        '- ${m.canonicalRef} id="${m.id}" label="${m.displayLabel}" kind=${m.categoryLabel}$pageBit',
      );
    }
    b.writeln(
      'Prioritize MENTIONS for update/delete/modify/connect actions. '
      'Do not substitute different pages/tables/widgets.',
    );
    return b.toString().trimRight();
  }

  static String appendToPrompt(String userPrompt, String mentionsBlock) {
    final String trimmed = userPrompt.trim();
    if (mentionsBlock.trim().isEmpty) {
      return trimmed;
    }
    if (trimmed.isEmpty) {
      return mentionsBlock;
    }
    return '$trimmed\n\n$mentionsBlock';
  }
}

final class _ScoredMention {
  const _ScoredMention(this.mention, this.score);
  final AiWorkspaceMention mention;
  final int score;
}
