/// Normalizes user chat input before prompts and deterministic shortcuts.
abstract final class AiPromptParaphraser {
  static const String systemInstruction =
      'You rewrite short user chat messages into clear standard English.\n'
      'Fix spelling and typos. Keep the same meaning and intent.\n'
      'Rules:\n'
      '- Output exactly ONE rewritten sentence or question.\n'
      '- No labels, quotes, markdown, or explanation.\n'
      '- No reasoning or thinking tags.\n'
      '- Do not answer the question — only rewrite it.\n'
      '- Keep workspace nouns unchanged (products, transactions, categories, tables).';

  /// Fast typo fixes before an optional on-device model paraphrase pass.
  static String normalizeLocally(String input) {
    String q = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) {
      return q;
    }

    const List<(String pattern, String replacement)> replacements =
        <(String, String)>[
          (r'\btotl\b', 'total'),
          (r'\btotals\b', 'totals'),
          (r'\btrnsctions\b', 'transactions'),
          (r'\btrnsction\b', 'transaction'),
          (r'\btrnsctn\b', 'transaction'),
          (r'\btransacton\b', 'transaction'),
          (r'\btransactons\b', 'transactions'),
          (r'\bprodcts\b', 'products'),
          (r'\bprodct\b', 'product'),
          (r'\bprduct\b', 'product'),
          (r'\bhoww\b', 'how'),
          (r'\bmny\b', 'many'),
          (r'\bmanyy\b', 'many'),
          (r'\bmnay\b', 'many'),
          (r'\bproductss\b', 'products'),
          (r'\bhve\b', 'have'),
          (r'\bhaev\b', 'have'),
          (r'\bwht\b', 'what'),
          (r'\bwhats\b', "what's"),
          (r'\bctegory\b', 'category'),
          (r'\bctegories\b', 'categories'),
          (r'\bsummry\b', 'summary'),
          (r'\bwrkspace\b', 'workspace'),
          (r'\binventry\b', 'inventory'),
          (r'\bamnt\b', 'amount'),
          (r'\bqtys\b', 'quantities'),
          (r'\btody\b', 'today'),
          (r'\btodays\b', "today's"),
          (r'\btod\b', 'today'),
        ];

    for (final (String pattern, String replacement) in replacements) {
      q = q.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    }

    return q;
  }

  /// Skip model when local normalization already yields a valid rewrite.
  static bool shouldRunModelParaphrase(
    String original,
    String normalizedLocal,
  ) {
    if (original.trim().isEmpty) {
      return false;
    }
    final String polished = polishLocally(normalizedLocal);
    if (isValidParaphrase(polished, original: original) &&
        preservesWorkspaceIntent(original, polished)) {
      return false;
    }
    return true;
  }

  /// Reject paraphrases that swap workspace entities (e.g. products → items).
  static bool preservesWorkspaceIntent(String original, String candidate) {
    final String o = original.toLowerCase();
    final String c = candidate.toLowerCase();
    if (_mentionsProductIntent(o) && !_mentionsProductIntent(c)) {
      return false;
    }
    if (_mentionsTransactionIntent(o) && !_mentionsTransactionIntent(c)) {
      return false;
    }
    if (_mentionsCategoryIntent(o) && !_mentionsCategoryIntent(c)) {
      return false;
    }
    return true;
  }

  static bool _mentionsProductIntent(String text) {
    return RegExp(r'\b(prodct|product|products|item)\b', caseSensitive: false)
        .hasMatch(text);
  }

  static bool _mentionsTransactionIntent(String text) {
    return RegExp(
      r'\b(trnsction|transact|transaction|transactions|sale|sales)\b',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static bool _mentionsCategoryIntent(String text) {
    return RegExp(r'\b(ctegory|category|categories)\b', caseSensitive: false)
        .hasMatch(text);
  }

  /// User turn sent to the paraphrase model (local typos already fixed).
  static String buildParaphraseUserMessage(String localNormalized) {
    return 'Rewrite the user message below into one clear English question or '
        'request. Output only the rewritten text.\n\n'
        'User message: ${localNormalized.trim()}';
  }

  /// Best text to use after local normalization (and optional model pass).
  static String resolveEffectivePrompt(
    String original,
    String localNormalized,
  ) {
    final String polished = polishLocally(localNormalized);
    return isValidParaphrase(polished, original: original)
        ? polished
        : polishLocally(normalizeLocally(original));
  }

  /// Sentence-case + question mark for short chat questions.
  static String polishLocally(String text) {
    String q = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) {
      return q;
    }
    q = q[0].toUpperCase() + q.substring(1);
    if (!q.endsWith('?') && !q.endsWith('.') && !q.endsWith('!')) {
      if (RegExp(
        r'^(what|who|where|when|why|how|is|are|do|does|did|can|could|would)\b',
        caseSensitive: false,
      ).hasMatch(q)) {
        q = '$q?';
      }
    }
    return q;
  }

  static bool isValidParaphrase(String candidate, {String? original}) {
    final String t = candidate.trim();
    if (t.isEmpty || t.length > 120) {
      return false;
    }
    if (RegExp(r'redacted_thinking', caseSensitive: false).hasMatch(t)) {
      return false;
    }
    if (_looksLikeMetaParaphrase(t)) {
      return false;
    }
    if (RegExp(
      r"^(i'm here to|feel free to ask|how can i help|let me know)",
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }
    if (original != null && original.trim().isNotEmpty) {
      if (t.length > original.trim().length * 2 + 24) {
        return false;
      }
      if (!preservesWorkspaceIntent(original, t)) {
        return false;
      }
    }
    final int letters = RegExp(r'[A-Za-z]').allMatches(t).length;
    if (letters < 6) {
      return false;
    }
    final int sentences =
        t
            .split(RegExp(r'[.!?]+'))
            .where((String s) => s.trim().isNotEmpty)
            .length;
    return sentences <= 2;
  }

  static bool _looksLikeMetaParaphrase(String text) {
    final String lower = text.toLowerCase();
    const List<String> metaPhrases = <String>[
      'let me try',
      'let me figure',
      'figure out how',
      'approach this',
      'the user has sent',
      'the user is asking',
      'i need to rewrite',
      'rewrite this into',
      'clear english question',
      'output only',
      'user message:',
    ];
    for (final String phrase in metaPhrases) {
      if (lower.contains(phrase)) {
        return true;
      }
    }
    return false;
  }

  /// Extracts the rewritten question from raw model output (incl. thinking tags).
  static String extractFromModelRaw(String raw) {
    String t = raw.trim();
    const String tagName = 'redacted_thinking';
    final String endTag = '</$tagName>';
    final int lastEnd = t.lastIndexOf(endTag);
    if (lastEnd >= 0 && lastEnd + endTag.length < t.length) {
      final String afterThinking = t.substring(lastEnd + endTag.length).trim();
      if (afterThinking.isNotEmpty) {
        t = afterThinking;
      }
    }
    return _stripThinkingArtifacts(t);
  }

  /// Picks the best paraphrase candidate from model output.
  static String finalize(
    String original,
    String modelOutput,
    String localFallback,
  ) {
    final String? embeddedQuestion = _extractEmbeddedQuestion(modelOutput);
    String candidate = extractFromModelRaw(modelOutput);
    if (embeddedQuestion != null && embeddedQuestion.trim().isNotEmpty) {
      candidate = normalizeLocally(embeddedQuestion);
    }
    final String? questionLine = _extractQuestionLine(candidate);
    if (questionLine != null) {
      candidate = questionLine;
    }
    if ((candidate.startsWith('"') && candidate.endsWith('"')) ||
        (candidate.startsWith("'") && candidate.endsWith("'"))) {
      candidate = candidate.substring(1, candidate.length - 1).trim();
    }
    final int newline = candidate.indexOf('\n');
    if (newline > 0) {
      candidate = candidate.substring(0, newline).trim();
    }
    if (RegExp(
      r'^(paraphrased|rewritten|output)\s*:',
      caseSensitive: false,
    ).hasMatch(candidate)) {
      final int colon = candidate.indexOf(':');
      if (colon >= 0 && colon < candidate.length - 1) {
        candidate = candidate.substring(colon + 1).trim();
      }
    }
    candidate = _stripThinkingArtifacts(candidate);
    if (!isValidParaphrase(candidate, original: original)) {
      return resolveEffectivePrompt(original, localFallback);
    }
    return polishLocally(candidate);
  }

  static String? _extractEmbeddedQuestion(String text) {
    final Iterable<RegExpMatch> matches = RegExp(
      r'"([^"]+\?)"',
    ).allMatches(text);
    if (matches.isEmpty) {
      return null;
    }
    return matches.last.group(1)?.trim();
  }

  static String? _extractQuestionLine(String text) {
    for (final String line in text.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.endsWith('?') &&
          trimmed.length <= 120 &&
          !_looksLikeMetaParaphrase(trimmed)) {
        return trimmed;
      }
    }
    final RegExpMatch? match = RegExp(
      r'([A-Za-z][^.!?\n]{4,100}\?)',
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  static String _stripThinkingArtifacts(String text) {
    const String tagName = 'redacted_thinking';
    String t = text.trim();
    final String endTag = '</$tagName>';
    final String startTag = '<$tagName>';
    final int endIdx = t.indexOf(endTag);
    if (endIdx >= 0) {
      t = t.substring(endIdx + endTag.length);
    }
    t = t.replaceAll(
      RegExp(
        '${RegExp.escape(startTag)}.*?${RegExp.escape(endTag)}',
        dotAll: true,
      ),
      '',
    );
    return t.trim();
  }

  /// User-question block embedded in the logged pre-prompt (not sent to the model).
  static String buildLoggedUserQuestionSection({
    required String original,
    required String paraphrased,
  }) {
    if (original.trim() == paraphrased.trim()) {
      return '## USER QUESTION\n\n'
          '$paraphrased\n\n'
          '(Paraphrase unchanged.)';
    }
    return '## USER QUESTION\n\n'
        'Original:\n\n'
        '$original\n\n'
        'Paraphrased (internal only):\n\n'
        '$paraphrased\n\n'
        '👉 Use the paraphrased version for response generation.';
  }
}
