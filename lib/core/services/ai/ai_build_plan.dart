import 'dart:convert';

/// Compact "what to build" sketch produced by the **planner** stage of Build
/// mode. It is *not* a final action JSON — the builder stage turns these
/// steps into concrete [AiBuildAction]s. Step strings are free-form hints
/// (e.g. `"create_page Sales bottom"`) used by the model to keep itself
/// consistent across the planner→builder boundary; the source of truth for
/// validation is the [refs] map.
class AiBuildPlan {
  const AiBuildPlan({
    required this.steps,
    this.pageRefs = const <String>{},
    this.tableRefs = const <String>{},
    this.widgetRefs = const <String>{},
    this.rawJson = '',
    this.domain = '',
    this.modules = const <String>[],
  });

  /// Ordered, short natural-language sketch of each step.
  final List<String> steps;

  /// Page names mentioned by the plan (exactly as they appear in the
  /// workspace name index). Used by [AiBuildWorkspaceSnapshot] to filter the
  /// builder context.
  final Set<String> pageRefs;

  /// Table names mentioned by the plan.
  final Set<String> tableRefs;

  /// Widget titles mentioned by the plan.
  final Set<String> widgetRefs;

  /// Raw planner output (cleaned of thinking tags) — handy for logging.
  final String rawJson;

  /// Optional domain tag from intent analysis (e.g. `finance`).
  final String domain;

  /// Inferred modules/pages for greenfield systems.
  final List<String> modules;

  bool get isEmpty =>
      steps.isEmpty &&
      pageRefs.isEmpty &&
      tableRefs.isEmpty &&
      widgetRefs.isEmpty;

  bool get hasSteps => steps.isNotEmpty;

  /// Compact JSON used as a `PLAN:` line inside the builder user turn.
  String toCompactJson() {
    return jsonEncode(<String, dynamic>{
      'steps': steps,
      if (domain.isNotEmpty) 'domain': domain,
      if (modules.isNotEmpty) 'modules': modules,
      if (pageRefs.isNotEmpty || tableRefs.isNotEmpty || widgetRefs.isNotEmpty)
        'refs': <String, dynamic>{
          if (pageRefs.isNotEmpty) 'pages': pageRefs.toList(growable: false),
          if (tableRefs.isNotEmpty) 'tables': tableRefs.toList(growable: false),
          if (widgetRefs.isNotEmpty) 'widgets': widgetRefs.toList(growable: false),
        },
    });
  }
}
