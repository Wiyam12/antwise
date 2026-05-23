import 'package:antwise/core/services/ai/ai_build_plan.dart';
import 'package:antwise/core/services/ai/ai_build_plan_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiBuildPlanParser.parse', () {
    test('parses domain and modules when present', () {
      const String raw = '''
{"steps":["create_page Finance Dashboard"],"domain":"finance","modules":["Finance Dashboard","Accounts"]}
''';
      final AiBuildPlan? plan = AiBuildPlanParser.parse(raw);
      expect(plan, isNotNull);
      expect(plan!.domain, 'finance');
      expect(plan.modules, equals(<String>['Finance Dashboard', 'Accounts']));
    });

    test('parses a well-formed plan with refs', () {
      const String raw = '''
{"steps":["create_page Sales bottom","create_table Orders on Sales columns Name,Amount"],"refs":{"pages":["Sales"],"tables":["Orders"]}}
''';
      final AiBuildPlan? plan = AiBuildPlanParser.parse(raw);
      expect(plan, isNotNull);
      expect(plan!.steps, hasLength(2));
      expect(plan.steps.first, contains('create_page Sales'));
      expect(plan.pageRefs, equals(<String>{'Sales'}));
      expect(plan.tableRefs, equals(<String>{'Orders'}));
      expect(plan.widgetRefs, isEmpty);
    });

    test('strips thinking tags before extracting JSON', () {
      const String raw = '''
<think>let me think</think>
{"steps":["create_page Reports both"]}
''';
      final AiBuildPlan? plan = AiBuildPlanParser.parse(raw);
      expect(plan, isNotNull);
      expect(plan!.steps.single, 'create_page Reports both');
    });

    test('strips markdown fences', () {
      const String raw = '''
```json
{"steps":["delete_page Old"]}
```
''';
      final AiBuildPlan? plan = AiBuildPlanParser.parse(raw);
      expect(plan, isNotNull);
      expect(plan!.steps.single, 'delete_page Old');
    });

    test('returns null when steps array is missing', () {
      const String raw = '{"refs":{"pages":["Sales"]}}';
      expect(AiBuildPlanParser.parse(raw), isNull);
    });

    test('returns null when JSON is unparseable', () {
      expect(AiBuildPlanParser.parse('not json at all'), isNull);
      expect(AiBuildPlanParser.parse('{"steps":'), isNull);
    });

    test('returns empty plan when steps is an empty array', () {
      const String raw = '{"steps":[]}';
      final AiBuildPlan? plan = AiBuildPlanParser.parse(raw);
      expect(plan, isNotNull);
      expect(plan!.hasSteps, isFalse);
      expect(plan.isEmpty, isTrue);
    });

    test('drops empty step strings and trims whitespace', () {
      const String raw = '''
{"steps":["  create_page A  ", "", "  ", "update_table B "]}
''';
      final AiBuildPlan? plan = AiBuildPlanParser.parse(raw);
      expect(plan, isNotNull);
      expect(plan!.steps, equals(<String>['create_page A', 'update_table B']));
    });
  });

  group('AiBuildPlanParser.mergePrefillResponse', () {
    test('returns the bare prefill when the model produced nothing', () {
      expect(
        AiBuildPlanParser.mergePrefillResponse(''),
        kAiBuildPlanJsonPrefill,
      );
    });

    test('returns extracted JSON when it is already complete', () {
      const String complete = '{"steps":["create_page Sales bottom"]}';
      expect(AiBuildPlanParser.mergePrefillResponse(complete), complete);
    });

    test('wraps a bare array fragment back into a steps object', () {
      const String fragment = '["create_page Sales bottom"]';
      final String merged = AiBuildPlanParser.mergePrefillResponse(fragment);
      expect(merged, '{"steps":["create_page Sales bottom"]}');
    });

    test(
      'prepends the prefill when the model continued without an opening brace',
      () {
        const String continuation = '"create_page Sales"]}';
        final String merged = AiBuildPlanParser.mergePrefillResponse(
          continuation,
        );
        expect(merged.startsWith(kAiBuildPlanJsonPrefill), isTrue);
      },
    );
  });

  group('AiBuildPlanParser.looksLikeJson', () {
    test('returns true for output containing a parseable steps object', () {
      expect(
        AiBuildPlanParser.looksLikeJson('prose then {"steps":["x"]}'),
        isTrue,
      );
    });

    test('returns false for plain prose', () {
      expect(
        AiBuildPlanParser.looksLikeJson('just talking about pages'),
        isFalse,
      );
    });
  });

  group('AiBuildPlan.toCompactJson', () {
    test('encodes steps and refs, omits empty refs blocks', () {
      const AiBuildPlan plan = AiBuildPlan(
        steps: <String>['create_page Sales bottom'],
        pageRefs: <String>{'Sales'},
      );
      final String encoded = plan.toCompactJson();
      expect(encoded, contains('"steps":["create_page Sales bottom"]'));
      expect(encoded, contains('"pages":["Sales"]'));
      expect(encoded, isNot(contains('"tables"')));
      expect(encoded, isNot(contains('"widgets"')));
    });

    test('omits refs key entirely when all ref sets are empty', () {
      const AiBuildPlan plan = AiBuildPlan(
        steps: <String>['create_page Sales bottom'],
      );
      expect(plan.toCompactJson(), isNot(contains('"refs"')));
    });
  });
}
