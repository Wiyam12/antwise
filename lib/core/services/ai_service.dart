import 'dart:async';
import 'dart:developer' as developer;

import 'package:antwise/core/services/ai/ai_build_action_parser.dart';
import 'package:antwise/core/services/ai/ai_build_plan.dart';
import 'package:antwise/core/services/ai/ai_build_plan_parser.dart';
import 'package:antwise/core/services/ai/ai_build_planner_prompt.dart';
import 'package:antwise/core/services/ai/ai_build_prompt.dart';
import 'package:antwise/core/services/ai/ai_build_workspace_snapshot.dart';
import 'package:antwise/core/services/ai/ai_formula_processor.dart';
import 'package:antwise/core/services/ai/ai_hive_json_extractor.dart';
import 'package:antwise/core/services/ai/ai_prompt_builder.dart';
import 'package:antwise/core/services/ai/ai_prompt_paraphraser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/core/extensions.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:get/get.dart';

/// Thrown when [AIService.stopGeneration] interrupts an in-flight inference.
final class AiGenerationCancelledException implements Exception {
  const AiGenerationCancelledException();
}

final class AIService extends GetxService {
  Future<void>? _initFuture;
  Future<void>? _defaultModelEnsureFuture;

  /// Latest install progress sink (e.g. download screen). Shared with in-flight
  /// installs started by [warmUpModelSession] so UI updates are not dropped.
  void Function(int received, int? total)? _installProgressReporter;

  bool _generationCancelRequested = false;
  InferenceModelSession? _activeInferenceSession;

  /// Serializes every native LiteRT/MediaPipe turn (paraphrase, ask, build).
  /// The platform rejects overlapping `createSession` / `generate` calls with
  /// "Previous invocation still processing" if a prior session was cancelled
  /// but not fully torn down yet.
  Future<void> _exclusiveInferenceChain = Future<void>.value();

  static const String _logName = 'AIService';
  static const ModelType _defaultModelType = ModelType.deepSeek;
  static const int _warmupMaxTokens = 768;

  /// [DeepSeek R1 Distill Qwen 1.5B](https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B)
  /// multi-prefill `.task` build (~1.86 GB).
  static const String _defaultDeepSeekModelUrl =
      'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv1280.task';
  static const String _defaultModelFilename =
      'DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv1280.task';

  /// Temperature schedule for retries when the runtime returns an empty string.
  static const List<double> _retryTemperatures = <double>[0.6, 0.38, 0.12];

  /// Build mode: low temperature reduces R1 "thinking aloud" before JSON.
  static const List<double> _buildTemperatures = <double>[0.22, 0.1];

  /// Planner stage: even lower temperature — we want a short deterministic
  /// list of steps, not creative prose.
  static const double _plannerTemperature = 0.12;

  /// Planner runs with a tight max-token budget so the on-device session
  /// reserves more output room for the builder stage's actions JSON.
  static const int _plannerMaxTokens = 768;

  static const ModelFileType _defaultModelFileType = ModelFileType.task;

  static String _cleanModelOutput(String raw) {
    String cleaned = ModelThinkingFilter.cleanResponse(
      raw,
      isThinking: false,
      modelType: _defaultModelType,
      fileType: _defaultModelFileType,
    );
    if (_defaultModelType == ModelType.deepSeek) {
      cleaned = _stripDeepSeekThinking(cleaned);
    }
    cleaned = _stripMetaReasoning(cleaned);
    return cleaned.trim();
  }

  /// DeepSeek may emit reasoning before a lone closing thinking tag (no opener).
  static String _stripDeepSeekThinking(String text) {
    const String tagName = 'redacted_thinking';
    final String endTag = '</$tagName>';
    final String startTag = '<$tagName>';
    final int endIdx = text.indexOf(endTag);
    if (endIdx >= 0) {
      text = text.substring(endIdx + endTag.length);
    }
    return text
        .replaceAll(
          RegExp(
            '${RegExp.escape(startTag)}.*?${RegExp.escape(endTag)}',
            dotAll: true,
          ),
          '',
        )
        .trim();
  }

  void _logPrePrompt(String fullPrompt) {
    if (!kDebugMode) {
      return;
    }
    developer.log(
      'Pre-prompt (${fullPrompt.length} chars):\n$fullPrompt',
      name: _logName,
    );
  }

  void _logResponse(String response) {
    if (!kDebugMode) {
      return;
    }
    developer.log(
      'Response (${response.length} chars):\n$response',
      name: _logName,
    );
  }

  void _logParaphrase({
    required String original,
    required String local,
    required String modelRaw,
    required String result,
  }) {
    if (!kDebugMode) {
      return;
    }
    developer.log(
      'Paraphrase:\n'
      'Original: $original\n'
      'Local: $local\n'
      'Model raw (${modelRaw.length} chars): $modelRaw\n'
      'Result: $result',
      name: _logName,
    );
  }

  Future<void> initialize() {
    _initFuture ??= _initializeInternal();
    return _initFuture!;
  }

  /// Runs [body] after any in-flight inference (including cancel teardown) has
  /// finished. Use this to wrap a full user turn (paraphrase + reply).
  Future<T> withExclusiveInference<T>(Future<T> Function() body) async {
    final Completer<T> result = Completer<T>();
    _exclusiveInferenceChain = _exclusiveInferenceChain.then((_) async {
      try {
        result.complete(await body());
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }

  /// Waits until the serialized inference queue is idle (prior session closed).
  Future<void> awaitExclusiveInferenceIdle({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      await _exclusiveInferenceChain.timeout(timeout);
    } on TimeoutException {
      if (kDebugMode) {
        developer.log(
          'Timed out waiting for inference queue to drain',
          name: _logName,
        );
      }
    }
  }

  Future<void> _initializeInternal() async {
    await FlutterGemma.initialize();
    _log('LiteRT-LM runtime initialized');
  }

  Future<bool> checkModelExists() async {
    await initialize();
    return FlutterGemma.isModelInstalled(_defaultModelFilename);
  }

  Future<void> downloadModel({
    required void Function(int received, int? total) onProgress,
  }) async {
    _installProgressReporter = onProgress;
    try {
      await _ensureModelReady();
    } finally {
      if (identical(_installProgressReporter, onProgress)) {
        _installProgressReporter = null;
      }
    }
  }

  void _emitInstallProgress(int percent0to100) {
    final void Function(int received, int? total)? reporter =
        _installProgressReporter;
    if (reporter == null) {
      return;
    }
    final int pct = percent0to100.clamp(0, 100);
    reporter(pct, 100);
  }

  Future<void> warmUpModelSession() async {
    try {
      await withExclusiveInference(() async {
        await initialize();
        await _ensureModelReady();
        final InferenceModel model = await FlutterGemma.getActiveModel(
          maxTokens: _warmupMaxTokens,
        );
        try {
          await _runStreamingInference(
            model,
            'Hi',
            temperature: _retryTemperatures.first,
          );
        } finally {
          await model.close();
        }
      });
    } catch (e, st) {
      developer.log(
        'AI warm-up failed: $e',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Rewrites the user message for inference (typos, clarity). Original is kept in chat UI.
  Future<String> paraphraseUserMessage(String userMessage) async {
    final String trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final String local = AiPromptParaphraser.normalizeLocally(trimmed);
    if (!AiPromptParaphraser.shouldRunModelParaphrase(trimmed, local)) {
      return AiPromptParaphraser.resolveEffectivePrompt(trimmed, local);
    }

    if (_generationCancelRequested) {
      return AiPromptParaphraser.resolveEffectivePrompt(trimmed, local);
    }

    await initialize();
    await _ensureModelReady();

    final InferenceModel model = await FlutterGemma.getActiveModel(
      maxTokens: 256,
    );
    try {
      final String raw = await _runParaphraseInference(model, local);
      final String cleaned = AiPromptParaphraser.extractFromModelRaw(
        _normalizeModelReply(raw),
      );
      final String result = AiPromptParaphraser.finalize(
        trimmed,
        cleaned,
        local,
      );
      if (kDebugMode) {
        _logParaphrase(
          original: trimmed,
          local: local,
          modelRaw: raw,
          result: result,
        );
      }
      return result;
    } on AiGenerationCancelledException {
      rethrow;
    } catch (e, st) {
      if (kDebugMode) {
        developer.log(
          'Paraphrase failed; using local normalization: $e',
          name: _logName,
          error: e,
          stackTrace: st,
        );
      }
      return AiPromptParaphraser.resolveEffectivePrompt(trimmed, local);
    } finally {
      await model.close();
    }
  }

  /// Short, blocking inference pass to rewrite the user question.
  Future<String> _runParaphraseInference(
    InferenceModel model,
    String localNormalized,
  ) async {
    if (_generationCancelRequested) {
      throw const AiGenerationCancelledException();
    }

    final InferenceModelSession session = await model.createSession(
      temperature: 0.1,
      topK: 24,
      topP: 0.85,
      enableThinking: false,
      systemInstruction: AiPromptParaphraser.systemInstruction,
    );
    _activeInferenceSession = session;
    try {
      await session.addQueryChunk(
        Message.text(
          text: AiPromptParaphraser.buildParaphraseUserMessage(localNormalized),
          isUser: true,
        ),
      );

      if (_generationCancelRequested) {
        throw const AiGenerationCancelledException();
      }

      try {
        return await session.getResponse().timeout(const Duration(seconds: 25));
      } on TimeoutException {
        final StringBuffer buffer = StringBuffer();
        await for (final String token in session.getResponseAsync().timeout(
          const Duration(seconds: 15),
        )) {
          if (_generationCancelRequested) {
            await _haltSessionGeneration(session);
            throw const AiGenerationCancelledException();
          }
          if (token.isNotEmpty) {
            buffer.write(token);
          }
        }
        return buffer.toString();
      }
    } finally {
      if (identical(_activeInferenceSession, session)) {
        _activeInferenceSession = null;
      }
      await _closeSessionSafely(session);
    }
  }

  /// Runs the **planner** stage of Build mode. Returns `null` when the
  /// on-device model fails to produce a parseable plan (caller should fall
  /// back to the monolithic builder prompt). Reuses the same exclusive
  /// inference path as [generateResponse]'s build override.
  Future<AiBuildPlan?> generateBuildPlan({
    required AiBuildWorkspaceSnapshot snapshot,
    required String paraphrasedUserMessage,
    String? originalUserPrompt,
    String intentLine = '',
    String mentionsBlock = '',
    bool logDiagnostics = true,
  }) async {
    if (paraphrasedUserMessage.trim().isEmpty) {
      return null;
    }
    await initialize();
    await _ensureModelReady();
    _generationCancelRequested = false;

    final String systemInstruction =
        AiBuildPlannerPrompt.buildSystemInstruction();
    final String userTurn = AiBuildPlannerPrompt.buildUserTurn(
      userPrompt: paraphrasedUserMessage,
      snapshot: snapshot,
      intentLine: intentLine,
      mentionsBlock: mentionsBlock,
    );
    final String budgetedUserTurn = AiBuildPlannerPrompt.enforceInputBudget(
      systemInstruction: systemInstruction,
      userTurn: userTurn,
    );

    if (logDiagnostics) {
      _logPrePrompt(
        AiBuildPlannerPrompt.buildLoggablePrompt(
          userPrompt: paraphrasedUserMessage,
          snapshot: snapshot,
          originalUserPrompt: originalUserPrompt,
          intentLine: intentLine,
          mentionsBlock: mentionsBlock,
        ),
      );
    }

    final InferenceModel model = await FlutterGemma.getActiveModel(
      maxTokens: _plannerMaxTokens,
    );
    try {
      final String raw = await _runPlannerInferenceAttempt(
        model,
        systemInstruction: systemInstruction,
        userTurn: budgetedUserTurn,
      );
      if (logDiagnostics) {
        _logResponse(raw);
      }
      return AiBuildPlanParser.parse(raw);
    } on AiGenerationCancelledException {
      rethrow;
    } catch (e, st) {
      if (logDiagnostics && kDebugMode) {
        developer.log(
          'planner inference failed: $e',
          name: _logName,
          error: e,
          stackTrace: st,
        );
      }
      return null;
    } finally {
      await model.close();
    }
  }

  Future<String> _runPlannerInferenceAttempt(
    InferenceModel model, {
    required String systemInstruction,
    required String userTurn,
  }) async {
    final String raw = await _runStreamingInference(
      model,
      userTurn,
      temperature: _plannerTemperature,
      systemInstruction: systemInstruction,
      rawOutput: true,
      streamIdleTimeout: const Duration(seconds: 60),
      assistantPrefill: kAiBuildPlanJsonPrefill,
    );
    return AiBuildPlanParser.mergePrefillResponse(raw);
  }

  Future<String> generateResponse(
    String userMessage, {
    String? paraphrasedUserMessage,
    bool logDiagnostics = true,
    bool applyIntentShortcuts = true,
    String tableOutlineSnapshot = '',
    String workspaceConversationSummary = '',
    String workspaceMentionsBlock = '',
    String? systemInstructionOverride,
    String? userTurnOverride,
    String? loggablePromptOverride,
    bool expectJson = false,
  }) async {
    final String trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      final String fb = _fallbackReply(trimmed);
      if (logDiagnostics && kDebugMode) {
        _log('Skipped inference (empty input)', details: fb);
      }
      return fb;
    }

    await initialize();
    await _ensureModelReady();
    _generationCancelRequested = false;

    String effectivePrompt =
        (paraphrasedUserMessage ?? await paraphraseUserMessage(trimmed)).trim();
    if (!AiPromptParaphraser.isValidParaphrase(
      effectivePrompt,
      original: trimmed,
    )) {
      effectivePrompt = AiPromptParaphraser.resolveEffectivePrompt(
        trimmed,
        AiPromptParaphraser.normalizeLocally(trimmed),
      );
    }
    if (effectivePrompt.isEmpty) {
      return _fallbackReply(trimmed);
    }

    final bool useOverridePath =
        systemInstructionOverride != null && userTurnOverride != null;
    // DeepSeek ekv1280 build supports up to 1280 tokens; give Build mode the
    // full window so a long workspace context still leaves room for JSON.
    final int maxTokens = useOverridePath ? 1280 : 1024;
    final InferenceModel model = await FlutterGemma.getActiveModel(
      maxTokens: maxTokens,
    );
    try {
      // JSON / Build-mode path: caller supplies the prompt verbatim and we
      // bypass Ask-mode shortcuts (direct answers, reply validation, retries
      // on "unusable" replies) so the parser can see whatever JSON the model
      // produced.
      if (useOverridePath) {
        if (logDiagnostics) {
          _logPrePrompt(
            loggablePromptOverride ??
                '# SYSTEM\n$systemInstructionOverride\n\n# USER TURN\n$userTurnOverride',
          );
        }
        try {
          // Use raw output so the JSON parser sees the model's exact tokens
          // (including any `</think>` boundary). Cleaning is done by
          // AiBuildActionParser, not by the Ask-mode meta-reasoning stripper.
          //
          // DeepSeek R1 is fine-tuned to "think first" before answering, so
          // the stream sometimes idles briefly between the reasoning tail and
          // the JSON head. Give Build mode a generous idle timeout so we
          // actually reach the JSON instead of truncating mid-reasoning.
          //
          // We also prefill the assistant turn with `{"actions":[` so the
          // model continues JSON instead of opening a long reasoning block.
          final String budgetedUserTurn = AiBuildPrompt.enforceInputBudget(
            systemInstruction: systemInstructionOverride,
            userTurn: userTurnOverride,
          );
          String merged = await _runBuildInferenceAttempt(
            model,
            userTurn: budgetedUserTurn,
            systemInstruction: systemInstructionOverride,
            temperature: _buildTemperatures.first,
            useJsonPrefill: true,
          );
          if (!AiBuildActionParser.looksLikeJson(merged) &&
              _buildTemperatures.length > 1) {
            if (logDiagnostics && kDebugMode) {
              _log(
                'Build output was not JSON; retrying with lower temperature',
              );
            }
            final String strictUserTurn = AiBuildPrompt.enforceInputBudget(
              systemInstruction: systemInstructionOverride,
              userTurn:
                  '${budgetedUserTurn.trim()}\n${AiBuildPrompt.kJsonOnlyOutputSuffix}',
            );
            merged = await _runBuildInferenceAttempt(
              model,
              userTurn: strictUserTurn,
              systemInstruction: systemInstructionOverride,
              temperature: _buildTemperatures[1],
              useJsonPrefill: true,
            );
          }
          if (logDiagnostics) {
            _logResponse(merged);
          }
          return merged;
        } on AiGenerationCancelledException {
          rethrow;
        } catch (e, st) {
          if (logDiagnostics && kDebugMode) {
            developer.log(
              'override inference failed: $e',
              name: _logName,
              error: e,
              stackTrace: st,
            );
          }
          return '';
        }
      }

      final AiFormulaProcessor formulaProcessor = AiFormulaProcessor();
      final AiHiveContextPayload hiveContext = AiHiveJsonExtractor.build(
        processor: formulaProcessor,
      );
      formulaProcessor.clearCache();

      final String? directAnswer =
          expectJson
              ? null
              : AiPromptBuilder.tryDirectAnswerFromContext(
                effectivePrompt,
                hiveContext,
              );
      if (directAnswer != null) {
        if (logDiagnostics) {
          _logPrePrompt(
            AiPromptBuilder.buildFullPrompt(
              userPrompt: effectivePrompt,
              hiveContext: hiveContext,
              tableOutlineFallback: tableOutlineSnapshot,
              originalUserPrompt: trimmed,
            ),
          );
          _logResponse(directAnswer);
        }
        return directAnswer;
      }

      final String fullPrompt = AiPromptBuilder.buildFullPrompt(
        userPrompt: effectivePrompt,
        hiveContext: hiveContext,
        tableOutlineFallback: tableOutlineSnapshot,
        originalUserPrompt: trimmed,
      );
      final String userTurn = AiPromptBuilder.buildUserTurn(
        userPrompt: effectivePrompt,
        hiveContext: hiveContext,
        tableOutlineFallback: tableOutlineSnapshot,
        workspaceMentionsBlock: workspaceMentionsBlock,
      );
      final String systemInstruction = AiPromptBuilder.buildSystemInstruction();

      if (logDiagnostics) {
        _logPrePrompt(fullPrompt);
      }

      String response = '';
      for (var attempt = 0; attempt < _retryTemperatures.length; attempt++) {
        if (_generationCancelRequested) {
          throw const AiGenerationCancelledException();
        }
        final double temp = _retryTemperatures[attempt];
        try {
          final String raw = await _runStreamingInference(
            model,
            userTurn,
            temperature: temp,
            systemInstruction: systemInstruction,
          );
          if (logDiagnostics && kDebugMode && raw.trim().isEmpty) {
            _log(
              'Model returned empty raw output',
              details: 'attempt=${attempt + 1}',
            );
          }
          response = _normalizeModelReply(raw);
        } on AiGenerationCancelledException {
          rethrow;
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
        if (_isUsableModelReply(response, effectivePrompt)) {
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

      if (_isUsableModelReply(response, effectivePrompt)) {
        if (logDiagnostics) {
          _logResponse(response);
        }
        return response;
      }

      final String fallback = _fallbackReply(trimmed);
      if (logDiagnostics) {
        _logResponse(fallback);
      }
      return fallback;
    } finally {
      await model.close();
    }
  }

  String _normalizeModelReply(String raw) {
    String t = _cleanModelOutput(raw);
    if ((t.startsWith('"') && t.endsWith('"')) ||
        (t.startsWith("'") && t.endsWith("'"))) {
      t = t.substring(1, t.length - 1).trim();
    }
    return t;
  }

  /// Drops planning paragraphs ("Okay, so the user is asking…", JSON search, etc.).
  static String _stripMetaReasoning(String text) {
    final List<String> paragraphs = text.split(RegExp(r'\n\s*\n'));
    final List<String> kept = <String>[];
    for (final String paragraph in paragraphs) {
      final String trimmed = paragraph.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (_isMetaReasoningParagraph(trimmed)) {
        continue;
      }
      kept.add(_trimAnswerLeadIn(trimmed));
    }
    if (kept.isEmpty) {
      return text.trim();
    }
    return kept.join('\n\n');
  }

  bool _looksLikeTruncatedReply(String text) {
    final String t = text.trim();
    if (RegExp(r'\bin the context\s*$', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(
      r'\b(so|and|the|with|in the)\s*$',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    if (t.length > 100 &&
        !RegExp(r'[.!?]$').hasMatch(t) &&
        RegExp(
          r'\b(in the|let me|looking at|i need to)\b',
          caseSensitive: false,
        ).hasMatch(t)) {
      return true;
    }
    return false;
  }

  bool _looksLikeMetaOnlyReply(String text, String userQuestion) {
    if (AiPromptBuilder.isWorkspaceQuestion(userQuestion)) {
      return false;
    }
    final String stripped = _stripMetaReasoning(text).trim();
    if (stripped.length < 24) {
      return true;
    }
    if (_looksLikeTruncatedReply(stripped)) {
      return true;
    }
    return _isMetaReasoningParagraph(stripped);
  }

  static bool _isMetaReasoningParagraph(String paragraph) {
    final String lower = paragraph.toLowerCase();

    // Keep paragraphs that already contain a direct definition or answer.
    if (RegExp(
      r'\b(is|are|means|refers to)\s+(a|an|the)\s+\w',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return false;
    }

    if (RegExp(
      r'^(okay|ok|so|hmm|well|wait|first|let me|looking at|i need to|the user is)',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'^now,\s', caseSensitive: false).hasMatch(lower) &&
        !RegExp(r'\b(is|are|means)\b').hasMatch(lower)) {
      return true;
    }
    if (lower.contains('provided json') ||
        lower.contains('application data') ||
        lower.contains('workspace_tables') ||
        lower.contains('looking through') ||
        lower.contains('let me look') ||
        lower.contains('figure out what to say') ||
        lower.contains('"categories"') ||
        lower.contains('"products"')) {
      return true;
    }
    return false;
  }

  static String _trimAnswerLeadIn(String paragraph) {
    final RegExp leadIn = RegExp(
      r'^(?:okay|ok|so|hmm|well|wait|now|first)[,.]?\s+'
      r'(?:the user is asking[^.!?]*[.!?]\s*)?'
      r'(?:let me[^.!?]*[.!?]\s*)?'
      r'(?:i need to[^.!?]*[.!?]\s*)?'
      r'(?:looking at[^.!?]*[.!?]\s*)?'
      r'(?:now,\s*the question is about[^.!?]*[.!?]\s*)?',
      caseSensitive: false,
      dotAll: true,
    );
    final String trimmed = paragraph.trim();
    return trimmed.replaceFirst(leadIn, '').trim().isEmpty
        ? trimmed
        : trimmed.replaceFirst(leadIn, '').trim();
  }

  /// Shields users from scrambled Gemma decoding (dashes/newlines/low letters).
  bool _looksLikeDegenerateDecodedReply(String raw) {
    final String t = raw.trim();
    if (t.length < 60) {
      return false;
    }
    final int letters = RegExp(r'[A-Za-z]').allMatches(t).length;
    final int richWords = RegExp(r'[A-Za-z]{5,}').allMatches(t).length;
    if (letters < 36 && (t.contains('---') || t.contains('..'))) {
      return true;
    }
    final int lenDenom = t.isEmpty ? 1 : t.length;
    final double letterRatio = letters / lenDenom;
    if (letterRatio < 0.11 && richWords < 4) {
      return true;
    }
    final int lineBreaks = '\n'.allMatches(t).length + 1;
    if (lineBreaks >= 9 && letters < lineBreaks * 5) {
      return true;
    }
    final RegExp thinLine = RegExp(r'(^[ ]*--+[ ]*$)', multiLine: true);
    if (thinLine.allMatches(t).length >= 5 && letters < 50) {
      return true;
    }
    return false;
  }

  /// Turn markers + horizontal rules from garbled decoding that mimics chat logs.
  bool _looksLikeChatMarkupGarbage(String raw) {
    final String t = raw.trim();
    if (t.isEmpty) return false;

    final int assistantLabels =
        RegExp(r'\bassistant\s*:', caseSensitive: false).allMatches(t).length;
    final int userLabels =
        RegExp(
          r'(^|\n)\s*user\s*:',
          caseSensitive: false,
          multiLine: true,
        ).allMatches(t).length;

    if (assistantLabels >= 2) {
      return true;
    }
    if (RegExp(
      r'\bassistant\s*:\s*assistant\b',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    final int dashedRuleLines =
        RegExp(r'^[ \t]*-{3,}[ \t]*$', multiLine: true).allMatches(t).length;

    final bool fragmentedBackticks =
        t.contains('```') ||
        RegExp(r'`[^`\n]+\s*based\s+on\s+the\s+`').hasMatch(t) ||
        t.contains('``');

    if (assistantLabels >= 1 &&
        userLabels >= 1 &&
        (dashedRuleLines >= 2 || fragmentedBackticks)) {
      return true;
    }
    if (dashedRuleLines >= 8 && assistantLabels >= 1) {
      return true;
    }

    final String lower = t.toLowerCase();
    if (assistantLabels >= 1 &&
        userLabels >= 1 &&
        lower.contains('summary') &&
        lower.contains('transaction')) {
      return true;
    }

    return false;
  }

  bool _isUsableModelReply(String raw, String userQuestion) {
    final String t = raw.trim();
    if (t.isEmpty) {
      return false;
    }
    if (_looksLikeDegenerateDecodedReply(t)) {
      return false;
    }
    if (_looksLikeChatMarkupGarbage(t)) {
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
    if (_looksLikeTruncatedReply(t)) {
      return false;
    }
    if (_looksLikeMetaOnlyReply(t, userQuestion)) {
      return false;
    }
    return true;
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
    if (t == 'is there anything else i can help you with today?' ||
        t == 'is there anything else i can help you with today' ||
        t == 'how can i help you today?' ||
        t == 'how can i help you today' ||
        t == 'what would you like to do?' ||
        t == 'what would you like to do' ||
        t == 'can i help with anything else?' ||
        t == 'can i help with anything else') {
      return true;
    }

    // Some runs emit a "deferred" placeholder instead of a real answer.
    // Treat this as unusable so retries/fallback can continue immediately.
    if (t.contains('please wait while i check') ||
        t.contains('i need to look at the available database structure') ||
        t.contains('i can check the structure') ||
        t.contains('still checking') ||
        t.contains('let me check first')) {
      return true;
    }
    if (t.contains("i'm here to provide") ||
        t.contains('feel free to ask') ||
        t.contains('do my best to help')) {
      return true;
    }
    return false;
  }

  Future<String> _runBuildInferenceAttempt(
    InferenceModel model, {
    required String userTurn,
    required String systemInstruction,
    required double temperature,
    required bool useJsonPrefill,
  }) async {
    final String raw = await _runStreamingInference(
      model,
      userTurn,
      temperature: temperature,
      systemInstruction: systemInstruction,
      rawOutput: true,
      streamIdleTimeout: const Duration(seconds: 90),
      assistantPrefill: useJsonPrefill ? kAiBuildJsonPrefill : null,
    );
    return useJsonPrefill
        ? AiBuildActionParser.mergePrefillResponse(raw)
        : raw;
  }

  Future<String> _runStreamingInference(
    InferenceModel model,
    String userMessage, {
    required double temperature,
    String? systemInstruction,
    bool rawOutput = false,
    Duration streamIdleTimeout = const Duration(seconds: 45),
    String? assistantPrefill,
  }) async {
    final String? trimmedSystem = systemInstruction?.trim();
    final bool enableThinking = false;
    final bool useBlockingGetResponse =
        _defaultModelType == ModelType.gemma4 &&
        _defaultModelFileType == ModelFileType.litertlm;
    final int sessionTopK = _defaultModelType == ModelType.deepSeek ? 40 : 64;
    final double sessionTopP =
        _defaultModelType == ModelType.deepSeek ? 0.7 : 0.95;

    if (_generationCancelRequested) {
      throw const AiGenerationCancelledException();
    }

    final InferenceModelSession session = await model.createSession(
      temperature: temperature,
      topK: sessionTopK,
      topP: sessionTopP,
      enableThinking: enableThinking,
      systemInstruction:
          trimmedSystem == null || trimmedSystem.isEmpty ? null : trimmedSystem,
    );
    _activeInferenceSession = session;
    try {
      await session.addQueryChunk(
        Message.text(text: userMessage.trim(), isUser: true),
      );

      if (assistantPrefill != null && assistantPrefill.isNotEmpty) {
        await session.addQueryChunk(
          Message.text(text: assistantPrefill, isUser: false),
        );
      }

      if (_generationCancelRequested) {
        throw const AiGenerationCancelledException();
      }

      if (useBlockingGetResponse) {
        final String raw = await session.getResponse();
        return rawOutput ? raw : _cleanModelOutput(raw);
      }

      final StringBuffer buffer = StringBuffer();
      try {
        await for (final String token in session.getResponseAsync().timeout(
          streamIdleTimeout,
        )) {
          if (_generationCancelRequested) {
            await _haltSessionGeneration(session);
            throw const AiGenerationCancelledException();
          }
          if (token.isNotEmpty) {
            buffer.write(token);
          }
        }
      } on TimeoutException {
        // Use partial stream output if the stream stalls.
      }
      if (_generationCancelRequested) {
        await _haltSessionGeneration(session);
        throw const AiGenerationCancelledException();
      }
      final String raw = buffer.toString();
      return rawOutput ? raw : _cleanModelOutput(raw);
    } finally {
      if (identical(_activeInferenceSession, session)) {
        _activeInferenceSession = null;
      }
      await _closeSessionSafely(session);
    }
  }

  /// Stops an in-flight generation and gives MediaPipe a moment to flip
  /// `done=true` before we close the session (avoids IllegalStateException).
  Future<void> _haltSessionGeneration(InferenceModelSession session) async {
    try {
      await session.stopGeneration();
    } catch (_) {
      // Already stopped or platform detached.
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  /// MediaPipe's `LlmInferenceSession.close()` throws `IllegalStateException`
  /// when the underlying inference is still flagged as in-progress (e.g. when
  /// the model bailed out without setting `done=true`, which happens when the
  /// prompt almost saturates the KV cache or the user cancelled mid-stream).
  /// Always try [InferenceModelSession.stopGeneration] before [close] in those
  /// cases so the next `createSession` succeeds.
  Future<void> _closeSessionSafely(InferenceModelSession session) async {
    if (_generationCancelRequested) {
      await _haltSessionGeneration(session);
    }
    try {
      await session.close();
      return;
    } catch (e) {
      if (kDebugMode) {
        developer.log(
          'session.close() failed, attempting stopGeneration: $e',
          name: _logName,
        );
      }
    }
    await _haltSessionGeneration(session);
    try {
      await session.close();
    } catch (_) {
      // The platform side is in a bad state; the next createSession will
      // either re-use a clean session or surface the underlying problem.
    }
  }

  String _fallbackReply(String userMessage) {
    if (userMessage.trim().isEmpty) {
      return 'Please enter a message.';
    }
    return 'I could not generate a response. Please try again.';
  }

  Stream<String> streamResponse(
    String userMessage, {
    bool logDiagnostics = true,
    bool applyIntentShortcuts = true,
    String tableOutlineSnapshot = '',
    String workspaceConversationSummary = '',
  }) async* {
    final String reply = await generateResponse(
      userMessage,
      logDiagnostics: logDiagnostics,
      applyIntentShortcuts: applyIntentShortcuts,
      tableOutlineSnapshot: tableOutlineSnapshot,
      workspaceConversationSummary: workspaceConversationSummary,
    );
    yield reply;
  }

  Stream<String> generateResponseStream(String userMessage) =>
      streamResponse(userMessage);

  Future<void> stopGeneration() async {
    _generationCancelRequested = true;
    final InferenceModelSession? session = _activeInferenceSession;
    if (session != null) {
      await _haltSessionGeneration(session);
    }
    // Do not await [_exclusiveInferenceChain] here — [stopGeneration] is often
    // invoked from inside a [withExclusiveInference] turn; waiting would deadlock.
  }

  Future<void> _ensureModelReady({
    void Function(int received, int? total)? onProgress,
  }) async {
    if (onProgress != null) {
      _installProgressReporter = onProgress;
    }
    try {
      _defaultModelEnsureFuture ??= _installDefaultModel();
      await _defaultModelEnsureFuture!;
    } catch (_) {
      _defaultModelEnsureFuture = null;
      rethrow;
    }
  }

  Future<void> _installDefaultModel() async {
    _log('Installing DeepSeek R1 model');
    final String? token = _readHuggingFaceToken();
    try {
      await FlutterGemma.installModel(
            modelType: _defaultModelType,
            fileType: _defaultModelFileType,
          )
          .fromNetwork(_defaultDeepSeekModelUrl, token: token)
          .withProgress(_emitInstallProgress)
          .install();
    } catch (e) {
      final String message = e.toString();
      if (message.contains('401') || message.contains('restricted')) {
        throw StateError(
          'DeepSeek model download is gated on Hugging Face. '
          'Set HF_TOKEN in .env and make sure your account has access to '
          'litert-community/DeepSeek-R1-Distill-Qwen-1.5B.',
        );
      }
      rethrow;
    }
    _emitInstallProgress(100);
    _log('DeepSeek R1 model ready');
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
