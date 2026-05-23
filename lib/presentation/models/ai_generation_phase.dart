/// Progress phases reported by [AiChatController] while a chat turn runs.
///
/// Build mode walks through the first four in order (reasoning → analyzing →
/// planning → finalizing). Ask mode uses [reasoning] during paraphrase and
/// [responding] while the main reply streams.
enum AiGenerationPhase {
  reasoning,
  analyzing,
  planning,
  finalizing,
  responding,
}

extension AiGenerationPhaseLabels on AiGenerationPhase {
  String get label => switch (this) {
        AiGenerationPhase.reasoning => 'Reasoning…',
        AiGenerationPhase.analyzing => 'Analyzing workspace…',
        AiGenerationPhase.planning => 'Planning changes…',
        AiGenerationPhase.finalizing => 'Finalizing…',
        AiGenerationPhase.responding => 'Generating response…',
      };
}

/// Ordered stepper for Build mode (planning UI relies on this list to render
/// completed / active / pending states).
const List<AiGenerationPhase> kAiBuildGenerationStepper = <AiGenerationPhase>[
  AiGenerationPhase.reasoning,
  AiGenerationPhase.analyzing,
  AiGenerationPhase.planning,
  AiGenerationPhase.finalizing,
];
