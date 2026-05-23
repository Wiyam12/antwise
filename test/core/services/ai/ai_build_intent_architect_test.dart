import 'package:antwise/core/services/ai/ai_build_action.dart';
import 'package:antwise/core/services/ai/ai_build_intent_analyzer.dart';
import 'package:antwise/core/services/ai/ai_build_system_architect.dart';
import 'package:antwise/core/services/ai/ai_build_workspace_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiBuildIntentAnalyzer', () {
    test('detects greenfield gym fitness tracking', () {
      final AiBuildIntentAnalysis a = AiBuildIntentAnalyzer.analyze(
        userPrompt: 'Create me basic gym fitness tracking system',
      );
      expect(a.domain, AiBuildDomain.gym);
      expect(a.scope, AiBuildSystemScope.greenfieldSystem);
      expect(a.modules, contains('Members'));
    });

    test('detects greenfield finance system', () {
      final AiBuildIntentAnalysis a = AiBuildIntentAnalyzer.analyze(
        userPrompt: 'create me a basic finance system',
      );
      expect(a.domain, AiBuildDomain.finance);
      expect(a.scope, AiBuildSystemScope.greenfieldSystem);
      expect(a.modules, contains('Finance Dashboard'));
      expect(a.modules, contains('Transactions'));
    });

    test('treats formula update as incremental', () {
      final AiBuildIntentAnalysis a = AiBuildIntentAnalyzer.analyze(
        userPrompt: 'update weekly summary card formula on home',
      );
      expect(a.scope, AiBuildSystemScope.incremental);
    });
  });

  group('AiBuildSystemArchitect', () {
    test('expands gym system into many create actions', () {
      final AiBuildIntentAnalysis intent = AiBuildIntentAnalyzer.analyze(
        userPrompt: 'Create me basic gym fitness tracking system',
      );
      final AiBuildArchitectResult? result = AiBuildSystemArchitect.tryExpand(
        userPrompt: 'Create me basic gym fitness tracking system',
        analysis: intent,
        snapshot: AiBuildWorkspaceSnapshot.build(),
      );
      expect(result, isNotNull);
      expect(result!.parseResult.actions.length, greaterThan(15));
      expect(result.plan.domain, 'gym');
    });

    test('expands finance system into many create actions', () {
      final AiBuildIntentAnalysis intent = AiBuildIntentAnalyzer.analyze(
        userPrompt: 'create me a basic finance system',
      );
      final AiBuildArchitectResult? result = AiBuildSystemArchitect.tryExpand(
        userPrompt: 'create me a basic finance system',
        analysis: intent,
        snapshot: AiBuildWorkspaceSnapshot.build(),
      );
      expect(result, isNotNull);
      expect(result!.parseResult.actions.length, greaterThan(10));
      expect(
        result.parseResult.actions.whereType<CreatePageAction>().length,
        greaterThanOrEqualTo(5),
      );
      expect(
        result.parseResult.actions.whereType<CreateTableAction>().length,
        greaterThanOrEqualTo(4),
      );
      expect(
        result.parseResult.actions.whereType<CreateCardWidgetAction>().length,
        greaterThanOrEqualTo(2),
      );
      expect(result.plan.domain, 'finance');
      expect(result.plan.modules, isNotEmpty);
    });

    test('returns null for incremental edits', () {
      final AiBuildIntentAnalysis intent = AiBuildIntentAnalyzer.analyze(
        userPrompt: 'update card formula on home',
      );
      expect(
        AiBuildSystemArchitect.tryExpand(
          userPrompt: 'update card formula on home',
          analysis: intent,
        ),
        isNull,
      );
    });
  });
}
