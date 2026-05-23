import 'package:antwise/core/services/ai/ai_build_workspace_snapshot.dart';

/// Business domain inferred from a Build-mode user message.
enum AiBuildDomain {
  finance,
  pos,
  inventory,
  crm,
  lending,
  gym,
  unknown,
}

/// How large a change the user is asking for.
enum AiBuildSystemScope {
  /// e.g. "create a finance system", "build me a POS app".
  greenfieldSystem,

  /// Single entity or edit (card formula, rename table, etc.).
  incremental,

  unknown,
}

/// Structured intent produced **before** planner / builder / architect runs.
final class AiBuildIntentAnalysis {
  const AiBuildIntentAnalysis({
    required this.domain,
    required this.scope,
    required this.modules,
    this.domainLabel = '',
  });

  final AiBuildDomain domain;
  final AiBuildSystemScope scope;
  final List<String> modules;
  final String domainLabel;

  bool get isGreenfieldSystem =>
      scope == AiBuildSystemScope.greenfieldSystem && domain != AiBuildDomain.unknown;

  bool get hasModules => modules.isNotEmpty;

  /// Compact line for planner / builder user turns.
  String toPromptLine() {
    if (domain == AiBuildDomain.unknown && scope == AiBuildSystemScope.unknown) {
      return '';
    }
    final StringBuffer b = StringBuffer('INTENT:');
    if (domain != AiBuildDomain.unknown) {
      b.write('domain=${domain.name}');
      if (domainLabel.isNotEmpty) {
        b.write('($domainLabel)');
      }
    }
    if (scope != AiBuildSystemScope.unknown) {
      if (b.length > 7) {
        b.write(';');
      }
      b.write('scope=${scope.name}');
    }
    if (modules.isNotEmpty) {
      b.write(';modules=${modules.join("|")}');
    }
    return b.toString();
  }
}

/// Step 1 — analyze user message for domain, scope, and inferred modules.
abstract final class AiBuildIntentAnalyzer {
  static AiBuildIntentAnalysis analyze({
    required String userPrompt,
    AiBuildWorkspaceSnapshot? snapshot,
  }) {
    final String lower = userPrompt.trim().toLowerCase();
    if (lower.isEmpty) {
      return const AiBuildIntentAnalysis(
        domain: AiBuildDomain.unknown,
        scope: AiBuildSystemScope.unknown,
        modules: <String>[],
      );
    }

    final AiBuildDomain domain = _detectDomain(lower);
    final AiBuildSystemScope scope = _detectScope(lower, domain, snapshot);
    final List<String> modules = _modulesForDomain(domain);

    return AiBuildIntentAnalysis(
      domain: domain,
      scope: scope,
      modules: modules,
      domainLabel: _domainLabel(domain),
    );
  }

  static AiBuildDomain _detectDomain(String lower) {
    if (_matchesAny(lower, <String>[
      'finance',
      'financial',
      'accounting',
      'bookkeeping',
      'budget',
      'expense tracker',
    ])) {
      return AiBuildDomain.finance;
    }
    if (_matchesAny(lower, <String>[
      'pos',
      'point of sale',
      'point-of-sale',
      'retail',
      'checkout',
      'cashier',
    ])) {
      return AiBuildDomain.pos;
    }
    if (_matchesAny(lower, <String>[
      'inventory',
      'stock',
      'warehouse',
      'supply chain',
    ])) {
      return AiBuildDomain.inventory;
    }
    if (_matchesAny(lower, <String>[
      'crm',
      'customer relationship',
      'sales pipeline',
      'leads',
    ])) {
      return AiBuildDomain.crm;
    }
    if (_matchesAny(lower, <String>[
      'lending',
      'loan',
      'mortgage',
      'borrower',
      'repayment',
    ])) {
      return AiBuildDomain.lending;
    }
    if (_matchesAny(lower, <String>[
      'gym',
      'fitness',
      'workout',
      'training',
      'membership',
    ])) {
      return AiBuildDomain.gym;
    }
    return AiBuildDomain.unknown;
  }

  static AiBuildSystemScope _detectScope(
    String lower,
    AiBuildDomain domain,
    AiBuildWorkspaceSnapshot? snapshot,
  ) {
    final bool wantsEditOnly = RegExp(
      r'\b(update|delete|remove|drop|rename|modify|change|fix|edit|convert)\b',
    ).hasMatch(lower);
    final bool wantsCreate = RegExp(
      r'\b(create|build|generate|make|setup|set up|design|scaffold|bootstrap)\b',
    ).hasMatch(lower);
    final bool wantsSystem = RegExp(
      r'\b(system|app|application|workspace|modules?|platform|tracker|tracking)\b',
    ).hasMatch(lower);

    if (wantsEditOnly && !wantsCreate) {
      return AiBuildSystemScope.incremental;
    }

    final bool implicitSystem = domain != AiBuildDomain.unknown &&
        RegExp(
          r'\b(basic|simple|minimal|full|complete|starter)\b',
        ).hasMatch(lower);

    if ((wantsCreate && wantsSystem) || implicitSystem) {
      if (_allowsGreenfield(snapshot)) {
        return AiBuildSystemScope.greenfieldSystem;
      }
    }

    if (wantsCreate && domain != AiBuildDomain.unknown && _allowsGreenfield(snapshot)) {
      return AiBuildSystemScope.greenfieldSystem;
    }

    if (wantsCreate || wantsEditOnly) {
      return AiBuildSystemScope.incremental;
    }

    return AiBuildSystemScope.unknown;
  }

  static bool _allowsGreenfield(AiBuildWorkspaceSnapshot? snapshot) {
    if (snapshot == null || snapshot.isEmpty) {
      return true;
    }
    return snapshot.pages.length <= 2 && snapshot.tables.length <= 3;
  }

  static bool _matchesAny(String lower, List<String> needles) {
    for (final String n in needles) {
      if (lower.contains(n)) {
        return true;
      }
    }
    return false;
  }

  static String _domainLabel(AiBuildDomain domain) => switch (domain) {
        AiBuildDomain.finance => 'finance/accounting',
        AiBuildDomain.pos => 'point of sale',
        AiBuildDomain.inventory => 'inventory/stock',
        AiBuildDomain.crm => 'CRM/sales',
        AiBuildDomain.lending => 'lending/loans',
        AiBuildDomain.gym => 'gym/fitness',
        AiBuildDomain.unknown => '',
      };

  static List<String> _modulesForDomain(AiBuildDomain domain) =>
      switch (domain) {
        AiBuildDomain.finance => <String>[
          'Finance Dashboard',
          'Accounts',
          'Transactions',
          'Expenses',
          'Assets',
          'Reports',
        ],
        AiBuildDomain.pos => <String>[
          'POS Dashboard',
          'Products',
          'Transactions',
          'Reports',
        ],
        AiBuildDomain.inventory => <String>[
          'Inventory Dashboard',
          'Products',
          'Stock Movements',
          'Suppliers',
          'Reports',
        ],
        AiBuildDomain.crm => <String>[
          'CRM Dashboard',
          'Customers',
          'Deals',
          'Activities',
          'Reports',
        ],
        AiBuildDomain.lending => <String>[
          'Lending Dashboard',
          'Borrowers',
          'Loans',
          'Payments',
          'Reports',
        ],
        AiBuildDomain.gym => <String>[
          'Gym Dashboard',
          'Members',
          'Workouts',
          'Attendance',
          'Subscriptions',
          'Trainers',
          'Reports',
        ],
        AiBuildDomain.unknown => const <String>[],
      };
}
