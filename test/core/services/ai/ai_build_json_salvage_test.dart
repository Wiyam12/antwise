import 'package:antwise/core/services/ai/ai_build_action_parser.dart';
import 'package:antwise/core/services/ai/ai_build_json_salvage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiBuildJsonSalvage', () {
    test('rejects reasoning blob concatenated after prefill', () {
      const String leaky =
          '{Okay, so I need to build a JSON-only Antwise build converter for the user.}';
      final String rebuilt = AiBuildJsonSalvage.rebuildActionsPayload(leaky);
      expect(rebuilt, '{"actions":[]}');
      expect(AiBuildJsonSalvage.containsValidActions(leaky), isFalse);
    });

    test('extracts valid actions from noisy wrapper', () {
      const String noisy = '''
Some analysis here.
{"type":"create_page","ref":"gym_dashboard","name":"Gym Dashboard","icon":"fitness_center","navigation":"bottom"}
and more text
{"type":"create_table","ref":"members_table","pageRef":"Members","name":"Members","kind":"standard","columns":[{"name":"Full Name","type":"text"}]}
''';
      final String rebuilt = AiBuildJsonSalvage.rebuildActionsPayload(noisy);
      expect(AiBuildJsonSalvage.containsValidActions(rebuilt), isTrue);
      final result = AiBuildActionParser.parse(rebuilt);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.kind, 'create_page');
    });
  });

  group('AiBuildActionParser.mergePrefillResponse', () {
    test('does not produce malformed actions array from prose', () {
      const String modelOut =
          '{Okay, so I need to build a JSON-only Antwise build converter...}';
      final String merged = AiBuildActionParser.mergePrefillResponse(modelOut);
      expect(merged, '{"actions":[]}');
      final result = AiBuildActionParser.parse(modelOut);
      expect(result.hasActions, isFalse);
      expect(
        result.warnings.any((String w) => w.toLowerCase().contains('reasoning')),
        isTrue,
      );
    });
  });
}
