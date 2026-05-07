import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:get/get.dart';

final class AIService extends GetxService {
  Future<void>? _initFuture;
  Future<void>? _defaultModelEnsureFuture;

  static const String _logName = 'AIService';
  static const ModelType _defaultModelType = ModelType.gemmaIt;
  static const int _warmupMaxTokens = 768;

  /// Native / desktop: LiteRT-LM bundle (see flutter_gemma example `gemma4_E2B`).
  static const String _defaultGemmaModelUrlNative =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  /// Web uses the `.task` build (`ModelFileType.task`).
  static const String _defaultGemmaModelUrlWeb =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-web.task';

  /// Temperature schedule for retries when the runtime returns an empty string.
  static const List<double> _retryTemperatures = <double>[0.72, 0.38, 0.12];

  /// Shown when the user asks for anything outside Antwise usage (model must match).
  static const String outOfScopeReply =
      "Sorry, I can only assist with this application's features.";

  /// Strict in-app support scope (embedded  in every user turn for `.task` models).
  static const String _supportPolicyBlock = '';

  /// For `ModelFileType.task`, flutter_gemma forwards [Message.text] verbatim (no
  /// automatic Gemma turn markup). IT models expect explicit turns or generation
  /// can be empty or unstable.
  static String _gemmaTaskChatPrompt(String userContent) {
    const String startTurn = '<start_of_turn>';
    const String endTurn = '<end_of_turn>';
    const String userRole = 'user';
    const String modelRole = 'model';
    final String body =
        '$_supportPolicyBlock\n---\nUser message:\n$userContent';
    return '$startTurn$userRole\n$body$endTurn\n$startTurn$modelRole\n';
  }

  /// Minimal turn markup for warm-up probes only.
  static String _gemmaWarmupPrompt(String userContent) {
    const String startTurn = '<start_of_turn>';
    const String endTurn = '<end_of_turn>';
    return '$startTurn'
        'user\n'
        '$userContent'
        '$endTurn\n'
        '$startTurn'
        'model\n';
  }

  static String _buildInScopeRetryPrompt(String userContent) {
    return '$userContent\n\n'
        'Important clarification: The user is asking about Antwise app usage '
        'and formula features (including examples tied to their workspace '
        'tables when listed). This is in scope. Answer directly with Antwise '
        'behavior and concrete TableName.ColumnName examples when helpful '
        'instead of refusing.';
  }

  static bool _asksAboutIfFormula(String text) {
    return RegExp(r'\bIF\s*\(', caseSensitive: false).hasMatch(text);
  }

  /// Small models sometimes stall on `IF()` (English "if" collision). Disambiguate in-prompt only.
  static String _expandFormulaKeywordAmbiguity(String trimmedUserMessage) {
    if (!_asksAboutIfFormula(trimmedUserMessage)) {
      return trimmedUserMessage;
    }
    return '$trimmedUserMessage\n'
        '(Assistant note: IF(...) here means the Antwise formula function '
        'IF(condition, valueIfTrue, valueIfFalse), not the English word "if".)';
  }

  /// Last-chance paraphrase when IF questions decode as empty across temperatures.
  static String _ifFormulaAnswerSeed(String originalUserMessage) {
    return 'Answer briefly for Antwise support.\n'
        'User asked: ${originalUserMessage.trim()}\n'
        'Explain the formula IF(condition, valueIfTrue, valueIfFalse) used in '
        'Antwise table formula columns: what each argument is and how it picks '
        'a result. Mention that expressions use Table.column references like '
        'other formula functions.';
  }

  /// When the model refuses or stalls on "give me an example" style formula asks.
  static String _formulaExampleAnswerSeed(
    String originalUserMessage,
    String tableOutlineSnapshot,
  ) {
    final String trimmed = originalUserMessage.trim();
    final String outline = tableOutlineSnapshot.trim();
    final StringBuffer b =
        StringBuffer()
          ..writeln('Answer briefly for Antwise support.')
          ..writeln('User asked: $trimmed')
          ..writeln(
            'Give one or two concrete formula examples in Antwise syntax: '
            'TableName.ColumnName, or "Table Name".Column when the table name '
            'has spaces. Mention what AVG(...) averages (numeric column refs / '
            'values in this app).',
          );
    if (outline.isNotEmpty) {
      b.writeln(
        'Prefer names from this workspace outline when sensible:\n$outline',
      );
    }
    return b.toString();
  }

  static bool _wantsFormulaExample(String trimmedUserMessage) {
    final String lower = trimmedUserMessage.toLowerCase();
    if (!RegExp(
      r'\b(example|examples|sample|samples|based on|using my|my existing|my tables|existing tables)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return false;
    }
    return _mentionsAntwiseFormulaFn(trimmedUserMessage) ||
        RegExp(
          r'\b(formulas?|functions?)\b',
          caseSensitive: false,
        ).hasMatch(lower);
  }

  /// Detects formula-function topics even when the user writes "AVG formula" without ().
  static bool _mentionsAntwiseFormulaFn(String q) {
    if (_formulaFnInQuestion.hasMatch(q)) {
      return true;
    }
    final String lower = q.toLowerCase();
    if (RegExp(
          r'\b(example|examples|sample|samples)\b',
          caseSensitive: false,
        ).hasMatch(lower) &&
        RegExp(
          r'\b(countif|count|avg|sum|if|lookup|today)\b',
          caseSensitive: false,
        ).hasMatch(lower)) {
      return true;
    }
    if (!RegExp(r'\b(formulas?|functions?)\b').hasMatch(lower)) {
      return false;
    }
    return RegExp(
      r'\b(countif|count|avg|sum|if|lookup|today)\b',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  /// Stops the model from treating "examples from my tables" as out-of-scope.
  static String _expandFormulaExampleIntent(String trimmedUserMessage) {
    final String lower = trimmedUserMessage.toLowerCase();
    final bool wantsConcrete = RegExp(
      r'\b(example|examples|sample|samples|based on|using my|my existing|my tables|existing tables)\b',
      caseSensitive: false,
    ).hasMatch(lower);
    if (!wantsConcrete) {
      return trimmedUserMessage;
    }
    if (!_mentionsAntwiseFormulaFn(trimmedUserMessage) &&
        !RegExp(
          r'\b(formulas?|functions?)\b',
          caseSensitive: false,
        ).hasMatch(lower)) {
      return trimmedUserMessage;
    }
    return '$trimmedUserMessage\n'
        '(Assistant note: The user wants Antwise formula examples. Workspace '
        'table/column names below are in-app configuration — sample AVG/SUM/'
        'COUNT/IF expressions using them are in-scope support. Answer; do not '
        'refuse.)';
  }

  static String _composeUserPayload(
    String trimmedUserMessage,
    String tableOutlineSnapshot,
  ) {
    String x = _expandFormulaKeywordAmbiguity(trimmedUserMessage);
    x = _expandFormulaExampleIntent(x);
    final String outline = tableOutlineSnapshot.trim();
    if (outline.isEmpty) {
      return x;
    }
    return '$x\n\n'
        '---\n'
        'Workspace tables (for realistic formula examples; references use '
        'TableName.ColumnName, or "Table Name".Column when the table name has '
        'spaces):\n'
        '$outline';
  }

  /// Short social/messages that must stay in-scope without relying on the model.
  static String? _cannedSocialReply(String trimmed) {
    final String lower = trimmed.toLowerCase();
    if (trimmed.length > 64) {
      return null;
    }
    if (RegExp(
          r'^(hi+|hello|hey|howdy|yo|sup)(\s+(there|everyone|team))?\s*[!.…]*$',
          caseSensitive: false,
        ).hasMatch(lower) ||
        RegExp(
          r'^good\s+(morning|afternoon|evening)\b',
          caseSensitive: false,
        ).hasMatch(lower)) {
      return 'Hello! I help only with Antwise — navigation, pages, tables, '
          'settings, workspaces, and in-app troubleshooting. What would you '
          'like to do?';
    }
    if (RegExp(
      r'^(thanks?|thank\s+you|thx)\s*[!.]*$',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return 'You are welcome. Ask any time about using Antwise.';
    }
    if (RegExp(
      r'^(bye|goodbye|cya|see\s+you)(\s+later)?\s*[!.]*$',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return 'Goodbye. Come back if you need help with Antwise.';
    }
    if (RegExp(
          r'^what\s+(can\s+you\s+do|do\s+you\s+do)(\s+here)?\s*\??$',
          caseSensitive: false,
        ).hasMatch(lower) ||
        RegExp(
          r'^how\s+can\s+you\s+help\s*\??$',
          caseSensitive: false,
        ).hasMatch(lower)) {
      return 'I help only with Antwise: moving around the app, builder pages, '
          'tables and data, settings, workspaces, downloads, and notifications. '
          'What are you trying to do?';
    }
    return null;
  }

  /// User messages that are clearly about Antwise features (model refusal should be ignored).
  static bool _isAntwiseConceptOrFeatureQuestion(String trimmed) {
    final String lower = trimmed.toLowerCase();
    if (RegExp(r'\bformulas?\b').hasMatch(lower)) {
      return true;
    }
    if (RegExp(
      r'\b(table|tables|column|columns|row|rows)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    if (RegExp(
      r'\b(inventory|stock|deduct|deduction|affecting|validation\s+rule)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    if (RegExp(
      r'\b(workspace|navigation|settings|builder|notification)\b',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    if (RegExp(
      r'\b(IF|SUM|COUNT|AVG|COUNTIF|LOOKUP|TODAY)\s*\(',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  Future<void> initialize() {
    _initFuture ??= _initializeInternal();
    return _initFuture!;
  }

  Future<void> _initializeInternal() async {
    await FlutterGemma.initialize();
    _log('Gemma initialized');
  }

  Future<bool> checkModelExists() async {
    await initialize();
    return FlutterGemma.hasActiveModel();
  }

  Future<void> downloadModel({
    required void Function(int received, int? total) onProgress,
  }) async {
    await _ensureModelReady(onProgress: onProgress);
  }

  Future<void> warmUpModelSession() async {
    try {
      await initialize();
      await _ensureModelReady();
      final dynamic model = await FlutterGemma.getActiveModel(
        maxTokens: _warmupMaxTokens,
      );
      try {
        await _runStreamingInference(
          model,
          _gemmaWarmupPrompt('Hi'),
          temperature: _retryTemperatures.first,
        );
      } finally {
        await model.close();
      }
    } catch (e, st) {
      developer.log(
        'AI warm-up failed: $e',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<String> generateResponse(
    String userMessage, {
    bool logDiagnostics = true,
    bool applyIntentShortcuts = true,
    String tableOutlineSnapshot = '',
  }) async {
    final String trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      final String fb = _fallbackReply(trimmed);
      if (logDiagnostics && kDebugMode) {
        _log('Skipped inference (empty input)', details: fb);
      }
      return fb;
    }

    final String? canned = _cannedSocialReply(trimmed);
    if (canned != null) {
      if (logDiagnostics && kDebugMode) {
        _log('Canned in-scope reply', details: canned);
      }
      return canned;
    }

    await initialize();
    await _ensureModelReady();

    final String promptPayload = _composeUserPayload(
      trimmed,
      tableOutlineSnapshot,
    );
    final String prompt = _gemmaTaskChatPrompt(promptPayload);
    if (logDiagnostics && kDebugMode) {
      final String preview =
          prompt.length > 480 ? '${prompt.substring(0, 480)}…' : prompt;
      developer.log(
        'finalPrompt len=${prompt.length} preview=$preview',
        name: _logName,
      );
    }

    final dynamic model = await FlutterGemma.getActiveModel(maxTokens: 1024);
    try {
      String response = '';
      for (var attempt = 0; attempt < _retryTemperatures.length; attempt++) {
        final double temp = _retryTemperatures[attempt];
        try {
          final String raw = await _runStreamingInference(
            model,
            prompt,
            temperature: temp,
          );
          response = _finalizeSupportReply(raw);
          if (_matchesOutOfScopeRefusal(response) &&
              _isAntwiseConceptOrFeatureQuestion(trimmed)) {
            final String retryPrompt = _gemmaTaskChatPrompt(
              _buildInScopeRetryPrompt(
                _composeUserPayload(trimmed, tableOutlineSnapshot),
              ),
            );
            final String retryRaw = await _runStreamingInference(
              model,
              retryPrompt,
              temperature: temp,
            );
            response = _finalizeSupportReply(retryRaw);
            if (_matchesOutOfScopeRefusal(response)) {
              if (logDiagnostics && kDebugMode) {
                _log(
                  'Model still refused in-scope question; continuing retries',
                  details: 'attempt=${attempt + 1}',
                );
              }
              response = '';
            }
          }
        } catch (e, st) {
          if (logDiagnostics && kDebugMode) {
            developer.log(
              'inference attempt ${attempt + 1} failed: $e',
              name: _logName,
              error: e,
              stackTrace: st,
            );
          }
          response = '';
        }
        if (_isUsableModelReply(response, trimmed)) {
          break;
        }
        if (logDiagnostics && kDebugMode) {
          _log(
            'Empty or unusable model output; retrying',
            details:
                'attempt=${attempt + 1} nextTemp=${attempt + 1 < _retryTemperatures.length ? _retryTemperatures[attempt + 1] : '—'}',
          );
        }
      }

      if (!_isUsableModelReply(response, trimmed) &&
          _asksAboutIfFormula(trimmed)) {
        try {
          if (logDiagnostics && kDebugMode) {
            _log(
              'Trying IF-specific answer-seed prompt',
              details: 'previous outputs unusable',
            );
          }
          final String seedPrompt = _gemmaTaskChatPrompt(
            _ifFormulaAnswerSeed(trimmed),
          );
          final String seedRaw = await _runStreamingInference(
            model,
            seedPrompt,
            temperature: 0.55,
          );
          response = _finalizeSupportReply(seedRaw);
        } catch (e, st) {
          if (logDiagnostics && kDebugMode) {
            developer.log(
              'IF answer-seed inference failed: $e',
              name: _logName,
              error: e,
              stackTrace: st,
            );
          }
        }
      }

      if (!_isUsableModelReply(response, trimmed) &&
          _wantsFormulaExample(trimmed)) {
        try {
          if (logDiagnostics && kDebugMode) {
            _log(
              'Trying formula-example answer-seed prompt',
              details: 'previous outputs unusable',
            );
          }
          final String seedPrompt = _gemmaTaskChatPrompt(
            _formulaExampleAnswerSeed(trimmed, tableOutlineSnapshot),
          );
          final String seedRaw = await _runStreamingInference(
            model,
            seedPrompt,
            temperature: 0.55,
          );
          response = _finalizeSupportReply(seedRaw);
        } catch (e, st) {
          if (logDiagnostics && kDebugMode) {
            developer.log(
              'Formula-example answer-seed inference failed: $e',
              name: _logName,
              error: e,
              stackTrace: st,
            );
          }
        }
      }

      if (_isUsableModelReply(response, trimmed)) {
        if (logDiagnostics && kDebugMode) {
          _log('Gemma response', details: response);
        }
        return response;
      }

      final String fallback = _fallbackReply(trimmed);
      if (logDiagnostics && kDebugMode) {
        _log('Using fallback reply (model returned empty)', details: fallback);
      }
      return fallback;
    } finally {
      await model.close();
    }
  }

  /// Normalizes refusal wording and stray punctuation to [outOfScopeReply].
  String _finalizeSupportReply(String raw) {
    String t = raw.trim();
    if ((t.startsWith('"') && t.endsWith('"')) ||
        (t.startsWith("'") && t.endsWith("'"))) {
      t = t.substring(1, t.length - 1).trim();
    }
    if (_matchesOutOfScopeRefusal(t)) {
      return outOfScopeReply;
    }
    return t;
  }

  bool _matchesOutOfScopeRefusal(String t) {
    final String x = t.trim().toLowerCase();
    final String expected = outOfScopeReply.toLowerCase();
    if (x == expected || x == '$expected.') {
      return true;
    }
    return x.startsWith(expected);
  }

  bool _isUsableModelReply(String raw, String userQuestion) {
    final String t = raw.trim();
    if (t.isEmpty) {
      return false;
    }
    const String placeholder = '(No response generated)';
    if (t == placeholder || t.contains(placeholder)) {
      return false;
    }
    if (_isGenericNonAnswer(t)) {
      return false;
    }
    if (_isEchoOfUserQuestion(t, userQuestion)) {
      return false;
    }
    if (_userAsksFormulaExplanation(userQuestion) &&
        (_isBareFormulaStubReply(t) || _lacksFormulaExplanationLanguage(t))) {
      return false;
    }
    return true;
  }

  /// User is asking what a formula function means / is used for.
  static bool _userAsksFormulaExplanation(String userQuestion) {
    final String lower = userQuestion.toLowerCase();
    if (!_mentionsAntwiseFormulaFn(userQuestion)) {
      return false;
    }
    return RegExp(
      r'(what\s+is|what\s+does|what\s+are|how\s+does|how\s+do|explain|used?\s+for|purpose|meaning)',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  static final RegExp _formulaFnInQuestion = RegExp(
    r'\b(COUNTIF|COUNT|AVG|SUM|IF|LOOKUP|TODAY)\s*\(',
    caseSensitive: false,
  );

  /// Whole reply is essentially a single FUNC(...) token (not a sentence explanation).
  static bool _isBareFormulaStubReply(String response) {
    final String t = response.trim();
    if (t.isEmpty || t.length > 120) {
      return false;
    }
    if (!RegExp(r'\(.*\)').hasMatch(t)) {
      return false;
    }
    final List<String> parts =
        t.split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.length != 1) {
      return false;
    }
    final String single = parts.single;
    return RegExp(
      r'^[A-Za-z][A-Za-z0-9_]*\(.+\)\s*$',
      dotAll: true,
    ).hasMatch(single);
  }

  /// Short reply with almost no explanatory wording — typical lazy decode.
  static bool _lacksFormulaExplanationLanguage(String response) {
    final String t = response.trim().toLowerCase();
    if (t.length >= 56) {
      return false;
    }
    const List<String> hints = <String>[
      'average',
      'mean',
      'median',
      'sum',
      'total',
      'count',
      'divide',
      'calculat',
      'return',
      'used',
      'column',
      'table',
      'formula',
      'value',
      'condition',
      'compare',
      'aggregate',
      'numeric',
      'number',
      'rows',
      'antwise',
    ];
    return !hints.any((String h) => t.contains(h));
  }

  static final RegExp _echoLeadingFluff = RegExp(
    r'^(the\s+user\s+(asks|said|wrote)|you\s+(asked|said)|question\s*|q\s*)[:]?\s*',
    caseSensitive: false,
  );

  /// Strip wrappers/spacing/punctuation so we can detect models that repeat the prompt.
  static String _normalizeForEchoCompare(String s) {
    String x = s
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s:"]+'), '')
        .replaceAll(RegExp(r'[?.!,]+$'), '');
    x = x.replaceFirst(_echoLeadingFluff, '').trim();
    return x.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isEchoOfUserQuestion(String response, String userQuestion) {
    final String r = _normalizeForEchoCompare(response);
    final String u = _normalizeForEchoCompare(userQuestion);
    if (r.isEmpty || u.isEmpty) {
      return false;
    }
    return r == u || (r.endsWith(u) && r.length <= u.length + 28);
  }

  bool _isGenericNonAnswer(String text) {
    final String t = text.trim().toLowerCase();
    return t == 'is there anything else i can help you with today?' ||
        t == 'is there anything else i can help you with today' ||
        t == 'how can i help you today?' ||
        t == 'how can i help you today' ||
        t == 'what would you like to do?' ||
        t == 'what would you like to do' ||
        t == 'can i help with anything else?' ||
        t == 'can i help with anything else';
  }

  /// One session, one [addQueryChunk], streaming only — avoids sync-then-stream
  /// double prompts seen when empty sync responses triggered a second chunk.
  Future<String> _runStreamingInference(
    dynamic model,
    String prompt, {
    required double temperature,
  }) async {
    final dynamic session = await model.createSession(
      temperature: temperature,
      topK: 64,
      topP: 0.95,
    );
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      final StringBuffer buffer = StringBuffer();
      await for (final String token in session.getResponseAsync()) {
        buffer.write(token);
      }
      return buffer.toString().trim();
    } finally {
      await session.close();
    }
  }

  String _fallbackReply(String userMessage) {
    final String lower = userMessage.toLowerCase().trim();
    if (lower.isEmpty) {
      return 'Ask how to use Antwise — for example navigation, tables, pages, '
          'settings, or your workspace.';
    }
    if (RegExp(r'^(hi+|hello|hey|howdy|yo|sup)\b').hasMatch(lower)) {
      return 'Hello! I help only with Antwise — navigation, pages, tables, '
          'settings, and in-app troubleshooting. What would you like to do?';
    }
    return 'I could not generate an answer. Ask about Antwise features or '
        'describe what you are trying to do in the app.';
  }

  Stream<String> streamResponse(
    String userMessage, {
    bool logDiagnostics = true,
    bool applyIntentShortcuts = true,
    String tableOutlineSnapshot = '',
  }) async* {
    final String reply = await generateResponse(
      userMessage,
      logDiagnostics: logDiagnostics,
      applyIntentShortcuts: applyIntentShortcuts,
      tableOutlineSnapshot: tableOutlineSnapshot,
    );
    yield reply;
  }

  Stream<String> generateResponseStream(String userMessage) =>
      streamResponse(userMessage);

  Future<void> stopGeneration() async {}

  Future<void> _ensureModelReady({
    void Function(int received, int? total)? onProgress,
  }) async {
    try {
      _defaultModelEnsureFuture ??= _installDefaultModel(
        onProgress: onProgress,
      );
      await _defaultModelEnsureFuture!;
    } catch (_) {
      _defaultModelEnsureFuture = null;
      rethrow;
    }
  }

  Future<void> _installDefaultModel({
    void Function(int received, int? total)? onProgress,
  }) async {
    _log('Installing default Gemma model');
    final String? token = _readHuggingFaceToken();
    final String modelUrl =
        kIsWeb ? _defaultGemmaModelUrlWeb : _defaultGemmaModelUrlNative;
    final ModelFileType modelFileType =
        kIsWeb ? ModelFileType.task : ModelFileType.litertlm;
    try {
      await FlutterGemma.installModel(
        modelType: _defaultModelType,
        fileType: modelFileType,
      ).fromNetwork(modelUrl, token: token).withProgress((int progress) {
        if (onProgress == null) {
          return;
        }
        final int received = (progress * 10).clamp(0, 1000);
        onProgress(received, 1000);
      }).install();
    } catch (e) {
      final String message = e.toString();
      if (message.contains('401') || message.contains('restricted')) {
        throw StateError(
          'Default Gemma model download is gated on Hugging Face. '
          'Set HF_TOKEN in .env and make sure your account has access to '
          'litert-community/gemma-4-E2B-it-litert-lm.',
        );
      }
      rethrow;
    }
    onProgress?.call(1, 1);
    _log('Default Gemma model ready');
  }

  String? _readHuggingFaceToken() {
    final String? raw =
        dotenv.env['HF_TOKEN'] ?? dotenv.env['HUGGINGFACE_TOKEN'];
    if (raw == null) {
      return null;
    }
    final String token = raw.trim().replaceAll('"', '').replaceAll("'", '');
    return token.isEmpty ? null : token;
  }

  void _log(String message, {String? details}) {
    developer.log(
      details == null ? message : '$message — $details',
      name: _logName,
    );
  }
}
