import 'package:antwise/core/services/ai/ai_workspace_mention.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('aiWorkspaceMentionKindSuffix', () {
    test('does not duplicate Summary when name already ends with Summary', () {
      expect(
        aiWorkspaceMentionKindSuffix('Attendance Summary', 'Summary'),
        isEmpty,
      );
      expect(
        '${'Attendance Summary'}${aiWorkspaceMentionKindSuffix('Attendance Summary', 'Summary')}',
        'Attendance Summary',
      );
    });

    test('appends kind when missing', () {
      expect(aiWorkspaceMentionKindSuffix('Transactions', 'Table'), ' Table');
    });
  });

  group('AiWorkspaceMentionCatalog', () {
    test('resolveFromMessage finds longest matching insert texts', () {
      final AiWorkspaceMentionCatalog catalog = AiWorkspaceMentionCatalog.fromItems(
        <AiWorkspaceMention>[
          const AiWorkspaceMention(
            id: 't1',
            kind: AiWorkspaceMentionKind.table,
            displayLabel: 'Transactions Table',
            insertText: '@Transactions Table',
            canonicalRef: 'table:Transactions',
          ),
          const AiWorkspaceMention(
            id: 'c1',
            kind: AiWorkspaceMentionKind.cardWidget,
            displayLabel: 'Weekly Sales Card',
            insertText: '@Weekly Sales Card',
            canonicalRef: 'widget:Weekly Sales',
            pageName: 'Home',
          ),
        ],
      );

      final List<AiWorkspaceMention> found = catalog.resolveFromMessage(
        'Update @Transactions Table and tweak @Weekly Sales Card formula',
      );

      expect(found, hasLength(2));
      expect(found.map((AiWorkspaceMention m) => m.canonicalRef), containsAll(<String>[
        'table:Transactions',
        'widget:Weekly Sales',
      ]));
    });

    test('buildPromptBlock lists authoritative refs', () {
      final AiWorkspaceMentionCatalog catalog = AiWorkspaceMentionCatalog.fromItems(
        <AiWorkspaceMention>[
          const AiWorkspaceMention(
            id: 't1',
            kind: AiWorkspaceMentionKind.summaryTable,
            displayLabel: 'Expenses Summary',
            insertText: '@Expenses Summary',
            canonicalRef: 'table:Expenses',
            pageName: 'Reports',
          ),
        ],
      );

      final String block = catalog.buildPromptBlock(
        catalog.resolveFromMessage('Connect @Expenses Summary to dashboard'),
      );

      expect(block, contains('MENTIONS (authoritative'));
      expect(block, contains('table:Expenses'));
      expect(block, contains('label="Expenses Summary"'));
      expect(block, contains('Prioritize MENTIONS'));
    });

    test('search ranks prefix matches ahead of substring matches', () {
      final AiWorkspaceMentionCatalog catalog = AiWorkspaceMentionCatalog.fromItems(
        <AiWorkspaceMention>[
          const AiWorkspaceMention(
            id: 'a',
            kind: AiWorkspaceMentionKind.table,
            displayLabel: 'Alpha Table',
            insertText: '@Alpha Table',
            canonicalRef: 'table:Alpha',
          ),
          const AiWorkspaceMention(
            id: 'b',
            kind: AiWorkspaceMentionKind.table,
            displayLabel: 'Beta Transactions Table',
            insertText: '@Beta Transactions Table',
            canonicalRef: 'table:Beta',
          ),
        ],
      );

      final List<AiWorkspaceMention> results = catalog.search('tran');
      expect(results.first.displayLabel, 'Beta Transactions Table');
    });
  });
}
