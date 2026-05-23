import 'dart:async';

import 'package:antwise/core/constants/app_constants.dart';
import 'package:antwise/core/services/ai/ai_build_action.dart';
import 'package:antwise/core/services/ai/ai_build_action_executor.dart';
import 'package:antwise/core/services/ai/ai_build_action_parser.dart';
import 'package:antwise/core/services/ai/ai_build_heuristics.dart';
import 'package:antwise/core/services/ai/ai_build_intent_analyzer.dart';
import 'package:antwise/core/services/ai/ai_build_plan.dart';
import 'package:antwise/core/services/ai/ai_build_prompt.dart';
import 'package:antwise/core/services/ai/ai_build_system_architect.dart';
import 'package:antwise/core/services/ai/ai_build_workspace_snapshot.dart';
import 'package:antwise/core/services/ai/ai_workspace_mention.dart';
import 'package:antwise/core/services/ai/ai_formula_processor.dart';
import 'package:antwise/core/services/ai/ai_hive_json_extractor.dart';
import 'package:antwise/core/services/ai/ai_prompt_paraphraser.dart';
import 'package:antwise/core/services/ai_service.dart';
import 'package:antwise/core/services/ai_support_table_snapshot.dart';
import 'package:antwise/core/storage/ai_chat_history_repository.dart';
import 'package:antwise/core/storage/hive_boxes.dart';
import 'package:antwise/data/models/hive/app_settings_hive_model.dart';
import 'package:antwise/data/models/hive/ai_chat_message_hive_model.dart';
import 'package:antwise/presentation/models/ai_generation_phase.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'home_controller.dart';

/// Which interaction mode the AI chat is in.
enum AiChatMode {
  ask,
  build;

  String get displayLabel => switch (this) {
        AiChatMode.ask => 'Ask',
        AiChatMode.build => 'Build',
      };
}

/// In-memory chat bubble (backed by [AiChatHistoryRepository] for persistence).
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestampMillis,
    this.metadataJson = '',
    this.persistedToHive = true,
  });

  final String id;
  final String role;
  final String text;
  final int timestampMillis;
  final String metadataJson;

  /// Opening greeting-only rows are UI-only unless saved.
  final bool persistedToHive;

  AiChatMessageHiveModel toHiveModel() => AiChatMessageHiveModel(
        id: id,
        role: role,
        content: text,
        timestampMillis: timestampMillis,
        metadataJson: metadataJson,
      );

  factory ChatMessage.fromHive(AiChatMessageHiveModel m) {
    return ChatMessage(
      id: m.id,
      role: m.role,
      text: m.content,
      timestampMillis: m.timestampMillis,
      metadataJson: m.metadataJson,
    );
  }

  ChatMessage copyWith({
    String? text,
    String? metadataJson,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      timestampMillis: timestampMillis,
      metadataJson: metadataJson ?? this.metadataJson,
      persistedToHive: persistedToHive,
    );
  }

  /// Decoded Build-mode metadata if this message was produced in Build mode.
  AiBuildMessageMetadata? get buildMetadata =>
      AiBuildMessageMetadata.tryDecode(metadataJson);
}

class AiChatController extends GetxController {
  AiChatController(this._ai, this._history, this._buildExecutor);

  static const String _fallbackAccountSegment = '__default__';
  static const Uuid _uuid = Uuid();

  /// Cap UI load per open to avoid decoding huge snapshots in memory.
  static const int maxUiMessagesLoad = 500;

  final AIService _ai;
  final AiChatHistoryRepository _history;
  final AiBuildActionExecutor _buildExecutor;

  final TextEditingController inputController = TextEditingController();
  final FocusNode chatInputFocusNode = FocusNode();
  final ScrollController scrollController = ScrollController();
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxBool isGenerating = false.obs;

  /// Current sub-phase of the in-flight chat turn. `null` when idle.
  final Rxn<AiGenerationPhase> generationPhase = Rxn<AiGenerationPhase>();

  /// Build-mode planner output for the currently-running turn. Cleared when
  /// the turn ends. Used by the chat UI to preview the plan under the
  /// progress stepper while the builder stage is still running.
  final Rxn<AiBuildPlan> buildPlanPreview = Rxn<AiBuildPlan>();

  final RxString workspaceSubtitle = ''.obs;
  final RxBool historyReady = false.obs;
  final Rx<AiChatMode> chatMode = AiChatMode.ask.obs;

  /// Tracks the message whose Build plan is currently executing, so the UI
  /// can disable the primary action and show progress on that specific row.
  final RxString applyingPlanMessageId = ''.obs;

  int _generationEpoch = 0;

  void _setPhase(int epoch, AiGenerationPhase? phase) {
    if (_generationEpoch != epoch || !isGenerating.value) {
      return;
    }
    generationPhase.value = phase;
  }

  void _resetGenerationProgress() {
    generationPhase.value = null;
    buildPlanPreview.value = null;
  }

  void setChatMode(AiChatMode mode) {
    if (isGenerating.value) {
      return;
    }
    if (chatMode.value != mode) {
      chatMode.value = mode;
    }
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(_loadHistoryAndGreet());
  }

  @override
  void onClose() {
    unawaited(_ai.stopGeneration());
    inputController.dispose();
    chatInputFocusNode.dispose();
    scrollController.dispose();
    super.onClose();
  }

  String _prefsAccountSegment() => _effectiveAccountSegment();

  String _rawAccountId() => _effectiveAccountSegment();

  /// Per-account isolate; extend later if multiple workspace IDs per account ship.
  String _workspaceId() => AiChatHistoryKeys.defaultWorkspaceId;

  /// Same semantics as legacy SharedPreferences-backed chat key segment.
  String _effectiveAccountSegment() {
    if (Get.isRegistered<HomeController>()) {
      final String name =
          Get.find<HomeController>().activeAccountName.value.trim();
      if (name.isNotEmpty) {
        return name;
      }
    }
    if (Hive.isBoxOpen(HiveBoxes.settingsBox)) {
      final Box<AppSettingsHiveModel> box =
          Hive.box<AppSettingsHiveModel>(HiveBoxes.settingsBox);
      final AppSettingsHiveModel? settings = box.get(HiveKeys.appSettings);
      final String name = settings?.activeAccountName.trim() ?? '';
      if (name.isNotEmpty) {
        return name;
      }
    }
    return _fallbackAccountSegment;
  }

  String _displayAccountLabel() {
    final String segment = _effectiveAccountSegment();
    return segment == _fallbackAccountSegment ? '' : segment;
  }

  String _buildOpeningGreetingText() {
    final String label = _displayAccountLabel().trim();
    if (label.isEmpty) {
      return 'Hi! I help only with ${AppConstants.appName} features — navigation, '
          'pages, tables, settings, and in-app troubleshooting. What do you need?';
    }
    return 'Hi, $label! I help only with ${AppConstants.appName} in this app — '
        'navigation, tables, settings, and similar. How can I help?';
  }

  Future<void> _loadHistoryAndGreet() async {
    try {
      workspaceSubtitle.value = _displayAccountLabel();
      await _history.ensureBoxOpen();
      final List<AiChatMessageHiveModel> stored =
          await _history.fetchWorkspaceChatHistory(
        prefsAccountSegment: _prefsAccountSegment(),
        accountId: _rawAccountId(),
        workspaceId: _workspaceId(),
        limitLast: maxUiMessagesLoad,
      );
      if (stored.isEmpty) {
        messages.assignAll(<ChatMessage>[
          ChatMessage(
            id: 'local_opening_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant',
            text: _buildOpeningGreetingText(),
            timestampMillis: DateTime.now().millisecondsSinceEpoch,
            persistedToHive: false,
          ),
        ]);
      } else {
        messages.assignAll(
          stored.map(ChatMessage.fromHive).toList(growable: false),
        );
      }
      _scrollToBottom();
    } finally {
      historyReady.value = true;
    }
  }

  Future<void> cancelGeneration() async {
    if (!isGenerating.value) {
      return;
    }
    _generationEpoch++;
    await _ai.stopGeneration();
    // Wait for the cancelled turn to finish session teardown before accepting
    // another message (prevents "Previous invocation still processing").
    await _ai.awaitExclusiveInferenceIdle();
    _removeTrailingEmptyAssistant();
    _resetGenerationProgress();
    isGenerating.value = false;
  }

  void _removeTrailingEmptyAssistant() {
    if (messages.isEmpty) {
      return;
    }
    final ChatMessage last = messages.last;
    if (last.role == 'assistant' && last.text.isEmpty) {
      messages.removeLast();
      messages.refresh();
    }
  }

  Future<void> send() async {
    final String text = inputController.text.trim();
    if (text.isEmpty || isGenerating.value) {
      return;
    }

    final int epoch = ++_generationEpoch;

    await _history.ensureBoxOpen();

    final String prefsSeg = _prefsAccountSegment();
    final String accountId = _rawAccountId();
    final String workspaceId = _workspaceId();

    final String userMessageId = _uuid.v4();
    final int userTs = DateTime.now().millisecondsSinceEpoch;
    final ChatMessage userMsg = ChatMessage(
      id: userMessageId,
      role: 'user',
      text: text,
      timestampMillis: userTs,
    );

    await _history.insertMessage(
      accountId: accountId,
      workspaceId: workspaceId,
      message: userMsg.toHiveModel(),
    );

    inputController.clear();
    messages.removeWhere(
      (ChatMessage m) => m.persistedToHive == false && m.role == 'assistant',
    );
    messages.add(userMsg);
    messages.add(
      ChatMessage(
        id: _uuid.v4(),
        role: 'assistant',
        text: '',
        timestampMillis: userTs + 1,
        persistedToHive: false,
      ),
    );
    isGenerating.value = true;
    generationPhase.value = AiGenerationPhase.reasoning;
    buildPlanPreview.value = null;
    _scrollToBottom();

    await _ai.withExclusiveInference(() async {
    try {
      if (_generationEpoch != epoch) {
        return;
      }
      _setPhase(epoch, AiGenerationPhase.reasoning);
      String query = await _ai.paraphraseUserMessage(text);
      if (!AiPromptParaphraser.isValidParaphrase(query, original: text)) {
        query = AiPromptParaphraser.resolveEffectivePrompt(
          text,
          AiPromptParaphraser.normalizeLocally(text),
        );
      }

      final AiWorkspaceMentionCatalog mentionCatalog =
          AiWorkspaceMentionCatalog.load();
      final List<AiWorkspaceMention> mentions =
          mentionCatalog.resolveFromMessage(text);
      final String mentionsBlock = mentionCatalog.buildPromptBlock(mentions);

      if (chatMode.value == AiChatMode.build) {
        await _handleBuildMode(
          epoch: epoch,
          accountId: accountId,
          workspaceId: workspaceId,
          originalText: text,
          paraphrasedText: query,
          mentionsBlock: mentionsBlock,
        );
        return;
      }

      final String? profitReply = AiSupportTableSnapshot.tryBuildProfitReply(
        query,
      );
      if (profitReply != null) {
        if (_generationEpoch != epoch) {
          return;
        }
        final ChatMessage aiMsg = ChatMessage(
          id: _uuid.v4(),
          role: 'assistant',
          text: profitReply,
          timestampMillis: DateTime.now().millisecondsSinceEpoch,
        );
        await _history.insertMessage(
          accountId: accountId,
          workspaceId: workspaceId,
          message: aiMsg.toHiveModel(),
        );
        messages[messages.length - 1] = aiMsg;
        messages.refresh();
        return;
      }

      final String? aggregateReply =
          AiSupportTableSnapshot.tryBuildAggregateTotalReply(query);
      if (aggregateReply != null) {
        if (_generationEpoch != epoch) {
          return;
        }
        final ChatMessage aiMsg = ChatMessage(
          id: _uuid.v4(),
          role: 'assistant',
          text: aggregateReply,
          timestampMillis: DateTime.now().millisecondsSinceEpoch,
        );
        await _history.insertMessage(
          accountId: accountId,
          workspaceId: workspaceId,
          message: aiMsg.toHiveModel(),
        );
        messages[messages.length - 1] = aiMsg;
        messages.refresh();
        return;
      }

      final String? directDataReply = AiSupportTableSnapshot
          .tryBuildAllRecordsReply(query);
      if (directDataReply != null) {
        if (_generationEpoch != epoch) {
          return;
        }
        final ChatMessage aiMsg = ChatMessage(
          id: _uuid.v4(),
          role: 'assistant',
          text: directDataReply,
          timestampMillis: DateTime.now().millisecondsSinceEpoch,
        );
        await _history.insertMessage(
          accountId: accountId,
          workspaceId: workspaceId,
          message: aiMsg.toHiveModel(),
        );
        messages[messages.length - 1] = aiMsg;
        messages.refresh();
        return;
      }

      final List<AiChatMessageHiveModel> forContextAsc =
          await _history.fetchWorkspaceChatHistory(
        prefsAccountSegment: prefsSeg,
        accountId: accountId,
        workspaceId: workspaceId,
      );
      final List<AiChatMessageHiveModel> beforeCurrent = forContextAsc
          .where((AiChatMessageHiveModel m) => m.id != userMessageId)
          .toList(growable: false);
      final String workspaceConversationSummary =
          _history.buildConversationContextBlock(
        messagesAscending: beforeCurrent,
        maxMessages: AiChatHistoryLimits.defaultContextMessageCount,
      );

      final String outline = AiSupportTableSnapshot.tryBuild();
      _setPhase(epoch, AiGenerationPhase.responding);
      final String reply = await _ai.generateResponse(
        text,
        paraphrasedUserMessage: query,
        tableOutlineSnapshot: outline,
        workspaceConversationSummary: workspaceConversationSummary,
        workspaceMentionsBlock: mentionsBlock,
      );
      if (_generationEpoch != epoch) {
        return;
      }

      final ChatMessage aiMsg = ChatMessage(
        id: _uuid.v4(),
        role: 'assistant',
        text: reply,
        timestampMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await _history.insertMessage(
        accountId: accountId,
        workspaceId: workspaceId,
        message: aiMsg.toHiveModel(),
      );
      messages[messages.length - 1] = aiMsg;
      messages.refresh();
    } on AiGenerationCancelledException {
      if (_generationEpoch != epoch) {
        return;
      }
      _removeTrailingEmptyAssistant();
    } catch (e) {
      if (_generationEpoch != epoch) {
        return;
      }
      final ChatMessage errMsg = ChatMessage(
        id: _uuid.v4(),
        role: 'assistant',
        text: 'Error: $e',
        timestampMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await _history.insertMessage(
        accountId: accountId,
        workspaceId: workspaceId,
        message: errMsg.toHiveModel(),
      );
      messages[messages.length - 1] = errMsg;
      messages.refresh();
    } finally {
      if (_generationEpoch == epoch) {
        _resetGenerationProgress();
        isGenerating.value = false;
        _scrollToBottom();
      }
    }
    });
  }

  /// Two-stage Build pipeline:
  ///
  /// 1. **analyzing** — read pages/tables/widgets from Hive into a snapshot.
  /// 2. **planning** — ask the planner model for a compact plan JSON.
  /// 3. **finalizing** — ask the builder model for `{"actions":[...]}` JSON,
  ///    using a slim system prompt and a workspace context filtered to the
  ///    plan's references.
  ///
  /// If the planner fails (empty or unparseable output) we fall back to the
  /// monolithic builder prompt so the user still gets a result.
  Future<void> _handleBuildMode({
    required int epoch,
    required String accountId,
    required String workspaceId,
    required String originalText,
    required String paraphrasedText,
    required String mentionsBlock,
  }) async {
    _setPhase(epoch, AiGenerationPhase.analyzing);
    // Yield to the scheduler so Obx paints the "analyzing" step at least
    // once. Hive reads below are synchronous; without this, the stepper
    // would jump straight from reasoning to planning in a single frame.
    await Future<void>.delayed(Duration.zero);

    final AiBuildWorkspaceSnapshot snapshot = AiBuildWorkspaceSnapshot.build();
    final AiFormulaProcessor formulaProcessor = AiFormulaProcessor();
    final AiHiveContextPayload hiveContext = AiHiveJsonExtractor.build(
      processor: formulaProcessor,
    );
    formulaProcessor.clearCache();
    if (_generationEpoch != epoch) {
      return;
    }

    final AiBuildIntentAnalysis intent = AiBuildIntentAnalyzer.analyze(
      userPrompt: paraphrasedText,
      snapshot: snapshot,
    );
    final String intentLine = intent.toPromptLine();

    final AiBuildArchitectResult? architect = AiBuildSystemArchitect.tryExpand(
      userPrompt: paraphrasedText,
      analysis: intent,
      snapshot: snapshot,
    );

    AiBuildActionParseResult parsed;
    String fallbackReply = '';
    if (architect != null && architect.parseResult.hasActions) {
      _setPhase(epoch, AiGenerationPhase.finalizing);
      buildPlanPreview.value = architect.plan;
      parsed = architect.parseResult;
      fallbackReply = architect.analysis.domainLabel.isNotEmpty
          ? 'Designed ${architect.analysis.domainLabel} system (${parsed.actions.length} steps).'
          : 'Designed system (${parsed.actions.length} steps).';
    } else {
      _setPhase(epoch, AiGenerationPhase.planning);
      AiBuildPlan? plan;
      try {
        plan = await _ai.generateBuildPlan(
          snapshot: snapshot,
          paraphrasedUserMessage: paraphrasedText,
          originalUserPrompt: originalText,
          intentLine: intentLine,
          mentionsBlock: mentionsBlock,
        );
      } on AiGenerationCancelledException {
        rethrow;
      } catch (_) {
        plan = null;
      }
      if (_generationEpoch != epoch) {
        return;
      }
      if (plan != null && plan.hasSteps) {
        buildPlanPreview.value = plan;
      }

      _setPhase(epoch, AiGenerationPhase.finalizing);

      final bool hasPlan = plan != null && plan.hasSteps;
      final String systemInstruction = hasPlan
          ? AiBuildPrompt.buildBuilderSystemInstruction()
          : AiBuildPrompt.buildSystemInstruction();
      final String userTurn = hasPlan
          ? AiBuildPrompt.buildBuilderUserTurn(
              userPrompt: paraphrasedText,
              snapshot: snapshot,
              plan: plan,
              intentLine: intentLine,
              mentionsBlock: mentionsBlock,
            )
          : AiBuildPrompt.buildUserTurn(
              userPrompt: paraphrasedText,
              snapshot: snapshot,
              intentLine: intentLine,
              mentionsBlock: mentionsBlock,
            );
      final String loggable = AiBuildPrompt.buildLoggablePrompt(
        userPrompt: paraphrasedText,
        snapshot: snapshot,
        plan: hasPlan ? plan : null,
        originalUserPrompt: originalText,
        intentLine: intentLine,
        mentionsBlock: mentionsBlock,
      );

      final String rawReply = await _ai.generateResponse(
        originalText,
        paraphrasedUserMessage: paraphrasedText,
        systemInstructionOverride: systemInstruction,
        userTurnOverride: userTurn,
        loggablePromptOverride: loggable,
        expectJson: true,
      );
      if (_generationEpoch != epoch) {
        return;
      }

      parsed = AiBuildActionParser.parse(rawReply);
      fallbackReply = rawReply;

      if (!parsed.hasActions && intent.isGreenfieldSystem) {
        final AiBuildArchitectResult? fallbackArchitect =
            AiBuildSystemArchitect.tryExpand(
          userPrompt: paraphrasedText,
          analysis: intent,
          snapshot: snapshot,
        );
        if (fallbackArchitect != null && fallbackArchitect.parseResult.hasActions) {
          parsed = fallbackArchitect.parseResult;
          buildPlanPreview.value = fallbackArchitect.plan;
          fallbackReply = 'Designed ${intent.domainLabel} system '
              '(${parsed.actions.length} steps).';
        }
      }

      final AiBuildActionParseResult? inferred = AiBuildHeuristics.tryInfer(
        userPrompt: paraphrasedText,
        hiveContext: hiveContext,
      );
      if (inferred != null &&
          inferred.hasActions &&
          (!parsed.hasActions ||
              AiBuildHeuristics.shouldOverrideParsed(parsed, inferred))) {
        parsed = inferred;
      }
    }
    final ChatMessage aiMsg = _buildModeMessage(
      parsed: parsed,
      fallback: fallbackReply,
    );

    await _history.insertMessage(
      accountId: accountId,
      workspaceId: workspaceId,
      message: aiMsg.toHiveModel(),
    );
    messages[messages.length - 1] = aiMsg;
    messages.refresh();
  }

  ChatMessage _buildModeMessage({
    required AiBuildActionParseResult parsed,
    required String fallback,
  }) {
    final int ts = DateTime.now().millisecondsSinceEpoch;
    if (parsed.hasActions) {
      final AiBuildMessageMetadata metadata = AiBuildMessageMetadata(
        actions: parsed.actions,
        warnings: parsed.warnings,
      );
      final String summary = _buildSummaryText(parsed);
      return ChatMessage(
        id: _uuid.v4(),
        role: 'assistant',
        text: summary,
        timestampMillis: ts,
        metadataJson: metadata.encode(),
      );
    }
    final String text = fallback.trim().isEmpty
        ? "I couldn't turn that into a build action. Try rephrasing — e.g. "
            '"Create a Products page with a Products table (Name, Price, Stocks)."'
        : fallback.trim();
    return ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      text: text,
      timestampMillis: ts,
    );
  }

  String _buildSummaryText(AiBuildActionParseResult parsed) {
    final int total = parsed.actions.length;
    final int creates = parsed.actions
        .where(
          (AiBuildAction a) => a.intent == AiBuildActionIntent.create,
        )
        .length;
    final int updates = parsed.actions
        .where(
          (AiBuildAction a) => a.intent == AiBuildActionIntent.update,
        )
        .length;
    final int deletes = parsed.actions
        .where(
          (AiBuildAction a) => a.intent == AiBuildActionIntent.delete,
        )
        .length;
    final List<String> parts = <String>[
      if (creates > 0) '$creates create',
      if (updates > 0) '$updates update',
      if (deletes > 0) '$deletes delete',
    ];
    final String breakdown = parts.isEmpty ? '$total step' : parts.join(' · ');
    final String headline =
        "Here's the build plan ($breakdown). Tap Build Plan to apply.";
    if (parsed.warnings.isEmpty) {
      return headline;
    }
    return '$headline (${parsed.warnings.length} skipped)';
  }

  Future<void> applyBuildAction(String messageId, int actionIndex) async {
    final int idx = messages.indexWhere((ChatMessage m) => m.id == messageId);
    if (idx < 0) {
      return;
    }
    final ChatMessage current = messages[idx];
    final AiBuildMessageMetadata? metadata = current.buildMetadata;
    if (metadata == null ||
        actionIndex < 0 ||
        actionIndex >= metadata.actions.length) {
      return;
    }
    final AiBuildAction action = metadata.actions[actionIndex];
    if (action.status != AiBuildActionStatus.pending) {
      return;
    }
    final AiBuildActionExecutionResult result =
        await _buildExecutor.execute(action);
    final AiBuildAction updated = result.success
        ? action.copyWithStatus(
            AiBuildActionStatus.applied,
            resolvedName: result.resolvedName,
          )
        : action.copyWithStatus(
            AiBuildActionStatus.failed,
            failureReason: result.errorMessage,
          );
    await _replaceActionAt(idx, actionIndex, updated);
    if (result.success && Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().refreshBuilderPageContent();
    }
  }

  /// Cursor-style "Build Plan" — execute every pending action on this message
  /// sequentially, auto-resolving naming collisions. Discarded items stay
  /// discarded; failures don't abort the rest of the batch.
  Future<void> applyBuildPlan(String messageId) async {
    if (applyingPlanMessageId.value.isNotEmpty) {
      return;
    }
    final int idx = messages.indexWhere((ChatMessage m) => m.id == messageId);
    if (idx < 0) {
      return;
    }
    final AiBuildMessageMetadata? initialMeta = messages[idx].buildMetadata;
    if (initialMeta == null || !initialMeta.hasActions) {
      return;
    }
    applyingPlanMessageId.value = messageId;
    _buildExecutor.beginBatch(
      userPrompt: _findPrecedingUserMessage(idx),
    );
    try {
      for (int i = 0; i < initialMeta.actions.length; i++) {
        final ChatMessage current = messages[idx];
        final AiBuildMessageMetadata? freshMeta = current.buildMetadata;
        if (freshMeta == null || i >= freshMeta.actions.length) {
          break;
        }
        if (freshMeta.actions[i].status != AiBuildActionStatus.pending) {
          continue;
        }
        await applyBuildAction(messageId, i);
      }
    } finally {
      applyingPlanMessageId.value = '';
    }
  }

  /// Walks back from [assistantIdx] to the closest user message — used to give
  /// the executor a fuzzy ref-resolution hint (e.g. "in reports page" → the
  /// existing `Report` page).
  String _findPrecedingUserMessage(int assistantIdx) {
    for (int i = assistantIdx - 1; i >= 0; i--) {
      final ChatMessage m = messages[i];
      if (m.role == 'user' && m.text.trim().isNotEmpty) {
        return m.text;
      }
    }
    return '';
  }

  Future<void> discardBuildAction(String messageId, int actionIndex) async {
    final int idx = messages.indexWhere((ChatMessage m) => m.id == messageId);
    if (idx < 0) {
      return;
    }
    final ChatMessage current = messages[idx];
    final AiBuildMessageMetadata? metadata = current.buildMetadata;
    if (metadata == null ||
        actionIndex < 0 ||
        actionIndex >= metadata.actions.length) {
      return;
    }
    final AiBuildAction action = metadata.actions[actionIndex];
    if (action.status != AiBuildActionStatus.pending) {
      return;
    }
    final AiBuildAction updated =
        action.copyWithStatus(AiBuildActionStatus.discarded);
    await _replaceActionAt(idx, actionIndex, updated);
  }

  Future<void> _replaceActionAt(
    int messageIdx,
    int actionIdx,
    AiBuildAction next,
  ) async {
    final ChatMessage current = messages[messageIdx];
    final AiBuildMessageMetadata? metadata = current.buildMetadata;
    if (metadata == null) {
      return;
    }
    final AiBuildMessageMetadata updated =
        metadata.copyWithUpdatedAction(actionIdx, next);
    final ChatMessage updatedMsg = current.copyWith(
      metadataJson: updated.encode(),
    );
    messages[messageIdx] = updatedMsg;
    messages.refresh();
    if (current.persistedToHive) {
      await _history.updateMessageMetadata(
        accountId: _rawAccountId(),
        workspaceId: _workspaceId(),
        messageId: current.id,
        metadataJson: updatedMsg.metadataJson,
      );
    }
  }

  /// Deletes one stored message when [id] exists in Hive for this workspace.
  Future<void> deleteMessageById(String id) async {
    await _history.deleteMessage(
      accountId: _rawAccountId(),
      workspaceId: _workspaceId(),
      messageId: id,
    );
    messages.removeWhere((ChatMessage m) => m.id == id);
  }

  Future<void> clearWorkspaceHistory() async {
    await _history.clearWorkspaceChatHistory(
      accountId: _rawAccountId(),
      workspaceId: _workspaceId(),
    );
    await _loadHistoryAndGreet();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) {
        return;
      }
      scrollController.animateTo(
        scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }
}
