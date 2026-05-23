import 'package:antwise/core/services/ai/ai_build_action.dart';
import 'package:antwise/core/services/ai/ai_build_action_parser.dart';
import 'package:antwise/core/services/ai/ai_build_intent_analyzer.dart';
import 'package:antwise/core/services/ai/ai_build_plan.dart';
import 'package:antwise/core/services/ai/ai_build_workspace_snapshot.dart';

/// Deterministic "application architect" for greenfield Build requests.
///
/// When the user asks for a whole system (e.g. "basic finance system"), this
/// expands a domain blueprint into a full batch of [AiBuildAction]s without
/// waiting for the on-device model to invent structure.
abstract final class AiBuildSystemArchitect {
  static const String _architectWarning =
      'Generated a complete system blueprint from domain analysis (local architect).';

  /// Returns a full action plan when [analysis] is a greenfield system request
  /// with a known domain; otherwise `null` (caller falls back to model).
  static AiBuildArchitectResult? tryExpand({
    required String userPrompt,
    required AiBuildIntentAnalysis analysis,
    AiBuildWorkspaceSnapshot? snapshot,
  }) {
    if (!analysis.isGreenfieldSystem) {
      return null;
    }
    if (_domainAlreadyPresent(analysis.domain, snapshot)) {
      return null;
    }

    final List<AiBuildAction> actions = switch (analysis.domain) {
      AiBuildDomain.finance => _financeSystem(),
      AiBuildDomain.pos => _posSystem(),
      AiBuildDomain.inventory => _inventorySystem(),
      AiBuildDomain.crm => _crmSystem(),
      AiBuildDomain.lending => _lendingSystem(),
      AiBuildDomain.gym => _gymSystem(),
      AiBuildDomain.unknown => const <AiBuildAction>[],
    };
    if (actions.isEmpty) {
      return null;
    }

    final AiBuildPlan plan = _planFromActions(analysis, actions);
    return AiBuildArchitectResult(
      parseResult: AiBuildActionParseResult(
        actions: actions,
        warnings: <String>[_architectWarning],
        fallbackText: '',
      ),
      plan: plan,
      analysis: analysis,
    );
  }

  static bool _domainAlreadyPresent(
    AiBuildDomain domain,
    AiBuildWorkspaceSnapshot? snapshot,
  ) {
    if (snapshot == null || snapshot.isEmpty) {
      return false;
    }
    final Set<String> names = snapshot.pages
        .map((AiBuildSnapshotPage p) => p.name.toLowerCase())
        .toSet();
    final String marker = switch (domain) {
      AiBuildDomain.finance => 'finance dashboard',
      AiBuildDomain.pos => 'pos dashboard',
      AiBuildDomain.inventory => 'inventory dashboard',
      AiBuildDomain.crm => 'crm dashboard',
      AiBuildDomain.lending => 'lending dashboard',
      AiBuildDomain.gym => 'gym dashboard',
      AiBuildDomain.unknown => '',
    };
    return marker.isNotEmpty && names.contains(marker);
  }

  static AiBuildPlan _planFromActions(
    AiBuildIntentAnalysis analysis,
    List<AiBuildAction> actions,
  ) {
    final List<String> steps = <String>[
      'analyze domain ${analysis.domain.name}',
      for (final AiBuildAction a in actions) _stepHint(a),
    ];
    final Set<String> pages = <String>{};
    final Set<String> tables = <String>{};
    final Set<String> widgets = <String>{};
    for (final AiBuildAction a in actions) {
      switch (a) {
        case CreatePageAction(:final String name):
          pages.add(name);
        case CreateTableAction(:final String name, :final String pageRef):
          tables.add(name);
          pages.add(pageRef);
        case CreateCardWidgetAction(:final String title, :final String pageRef):
          widgets.add(title);
          pages.add(pageRef);
        case CreateChartWidgetAction(:final String title, :final String pageRef):
          widgets.add(title);
          pages.add(pageRef);
        default:
          break;
      }
    }
    return AiBuildPlan(
      steps: steps,
      pageRefs: pages,
      tableRefs: tables,
      widgetRefs: widgets,
      rawJson: '',
      domain: analysis.domain.name,
      modules: analysis.modules,
    );
  }

  static String _stepHint(AiBuildAction action) => switch (action) {
        CreatePageAction(:final String name) => 'create_page $name',
        CreateTableAction(:final String name) => 'create_table $name',
        CreateCardWidgetAction(:final String title) => 'create_card $title',
        CreateChartWidgetAction(:final String title) => 'create_chart $title',
        _ => action.kind,
      };

  // --- Finance ----------------------------------------------------------------

  static List<AiBuildAction> _financeSystem() {
    const String dashboard = 'Finance Dashboard';
    const String accountsPage = 'Accounts';
    const String transactionsPage = 'Transactions';
    const String expensesPage = 'Expenses';
    const String assetsPage = 'Assets';
    const String reportsPage = 'Reports';

    return <AiBuildAction>[
      _page(ref: 'page_dashboard', name: dashboard, icon: 'account_balance_wallet'),
      _page(ref: 'page_accounts', name: accountsPage, icon: 'account_balance'),
      _page(ref: 'page_transactions', name: transactionsPage, icon: 'receipt_long'),
      _page(ref: 'page_expenses', name: expensesPage, icon: 'payments'),
      _page(ref: 'page_assets', name: assetsPage, icon: 'savings', nav: AiBuildPageNavigation.drawer),
      _page(ref: 'page_reports', name: reportsPage, icon: 'assessment', nav: AiBuildPageNavigation.drawer),
      _table(
        ref: 'table_accounts',
        pageRef: accountsPage,
        name: 'Accounts',
        columns: <AiBuildColumnSpec>[
          _col('Account Name', 'text', required: true),
          _col('Account Type', 'dropdown'),
          _col('Balance', 'number'),
          _col('Notes', 'text'),
        ],
      ),
      _table(
        ref: 'table_transactions',
        pageRef: transactionsPage,
        name: 'Transactions',
        columns: <AiBuildColumnSpec>[
          _col('Date', 'date'),
          _col('Description', 'text'),
          _col('Amount', 'number'),
          _col('Type', 'dropdown'),
        ],
      ),
      _table(
        ref: 'table_expenses',
        pageRef: expensesPage,
        name: 'Expenses',
        columns: <AiBuildColumnSpec>[
          _col('Date', 'date'),
          _col('Category', 'text'),
          _col('Amount', 'number'),
          _col('Vendor', 'text'),
          _col('Notes', 'text'),
        ],
      ),
      _table(
        ref: 'table_assets',
        pageRef: assetsPage,
        name: 'Assets',
        columns: <AiBuildColumnSpec>[
          _col('Asset Name', 'text', required: true),
          _col('Type', 'text'),
          _col('Value', 'number'),
          _col('Purchase Date', 'date'),
        ],
      ),
      _summaryTable(
        ref: 'table_expense_summary',
        pageRef: reportsPage,
        name: 'Expenses Summary',
        sourceTable: 'Expenses',
        groupBy: 'Category',
        aggregate: 'Amount',
      ),
      _summaryTable(
        ref: 'table_tx_summary',
        pageRef: reportsPage,
        name: 'Transactions Summary',
        sourceTable: 'Transactions',
        groupBy: 'Type',
        aggregate: 'Amount',
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Accounts',
        title: 'Total Balance',
        formula: 'SUM(Accounts.Balance)',
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Expenses',
        title: 'Weekly Expenses',
        formula:
            'SUM(IF(Expenses.Date>=DAYS_AGO(7),IF(Expenses.Date<=TODAY(),Expenses.Amount,0),0))',
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Expenses',
        title: 'Monthly Expenses',
        formula:
            'SUM(IF(Expenses.Date>=DAYS_AGO(30),IF(Expenses.Date<=TODAY(),Expenses.Amount,0),0))',
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Transactions',
        title: 'Today Transactions',
        formula:
            'SUM(IF(Transactions.Date=TODAY(),Transactions.Amount,0))',
      ),
      _chart(
        pageRef: dashboard,
        tableRef: 'Transactions',
        title: 'Cash Flow',
        chartType: AiBuildChartType.line,
        xColumn: 'Date',
        yColumn: 'Amount',
      ),
      _chart(
        pageRef: dashboard,
        tableRef: 'Expenses',
        title: 'Expenses by Category',
        chartType: AiBuildChartType.pie,
        xColumn: 'Category',
        yColumn: 'Amount',
      ),
    ];
  }

  // --- POS --------------------------------------------------------------------

  static List<AiBuildAction> _posSystem() {
    const String dashboard = 'POS Dashboard';
    const String productsPage = 'Products';
    const String transactionsPage = 'Transactions';
    const String reportsPage = 'Reports';

    return <AiBuildAction>[
      _page(ref: 'page_dashboard', name: dashboard, icon: 'point_of_sale'),
      _page(ref: 'page_products', name: productsPage, icon: 'inventory_2'),
      _page(ref: 'page_transactions', name: transactionsPage, icon: 'receipt'),
      _page(ref: 'page_reports', name: reportsPage, icon: 'bar_chart', nav: AiBuildPageNavigation.drawer),
      _table(
        ref: 'table_products',
        pageRef: productsPage,
        name: 'Products',
        columns: <AiBuildColumnSpec>[
          _col('Product Name', 'text', required: true),
          _col('Price', 'number'),
          _col('Stocks', 'number'),
          _col('Category', 'text'),
        ],
      ),
      _table(
        ref: 'table_transactions',
        pageRef: transactionsPage,
        name: 'Transactions',
        columns: <AiBuildColumnSpec>[
          _col('Date', 'date'),
          _col('Product', 'text'),
          _col('Qty', 'number'),
          _col('Total Amount', 'number'),
        ],
      ),
      _summaryTable(
        ref: 'table_sales_summary',
        pageRef: reportsPage,
        name: 'Sales Summary',
        sourceTable: 'Transactions',
        groupBy: 'Product',
        aggregate: 'Total Amount',
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Transactions',
        title: 'Total Sales',
        formula: 'SUM(Transactions."Total Amount")',
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Transactions',
        title: 'Daily Sales',
        formula:
            'SUM(IF(Transactions.Date=TODAY(),Transactions."Total Amount",0))',
      ),
      _chart(
        pageRef: dashboard,
        tableRef: 'Transactions',
        title: 'Sales by Product',
        chartType: AiBuildChartType.pie,
        xColumn: 'Product',
        yColumn: 'Total Amount',
      ),
      _chart(
        pageRef: dashboard,
        tableRef: 'Transactions',
        title: 'Sales Trend',
        chartType: AiBuildChartType.line,
        xColumn: 'Date',
        yColumn: 'Total Amount',
      ),
    ];
  }

  // --- Inventory --------------------------------------------------------------

  static List<AiBuildAction> _inventorySystem() {
    const String dashboard = 'Inventory Dashboard';
    const String productsPage = 'Products';
    const String movementsPage = 'Stock Movements';
    const String suppliersPage = 'Suppliers';

    return <AiBuildAction>[
      _page(ref: 'page_dashboard', name: dashboard, icon: 'warehouse'),
      _page(ref: 'page_products', name: productsPage, icon: 'inventory'),
      _page(ref: 'page_movements', name: movementsPage, icon: 'swap_horiz'),
      _page(ref: 'page_suppliers', name: suppliersPage, icon: 'local_shipping', nav: AiBuildPageNavigation.drawer),
      _table(
        ref: 'table_products',
        pageRef: productsPage,
        name: 'Products',
        columns: <AiBuildColumnSpec>[
          _col('Product Name', 'text', required: true),
          _col('SKU', 'text'),
          _col('Stocks', 'number'),
          _col('Reorder Level', 'number'),
        ],
      ),
      _table(
        ref: 'table_movements',
        pageRef: movementsPage,
        name: 'Stock Movements',
        columns: <AiBuildColumnSpec>[
          _col('Date', 'date'),
          _col('Product', 'text'),
          _col('Qty', 'number'),
          _col('Type', 'dropdown'),
        ],
      ),
      _table(
        ref: 'table_suppliers',
        pageRef: suppliersPage,
        name: 'Suppliers',
        columns: <AiBuildColumnSpec>[
          _col('Supplier Name', 'text', required: true),
          _col('Contact', 'text'),
          _col('Phone', 'text'),
        ],
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Products',
        title: 'Total Stock Units',
        formula: 'SUM(Products.Stocks)',
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Stock Movements',
        title: 'Weekly Movements',
        formula:
            'SUM(IF("Stock Movements".Date>=DAYS_AGO(7),IF("Stock Movements".Date<=TODAY(),"Stock Movements".Qty,0),0))',
      ),
      _chart(
        pageRef: dashboard,
        tableRef: 'Products',
        title: 'Stock by Product',
        chartType: AiBuildChartType.bar,
        xColumn: 'Product Name',
        yColumn: 'Stocks',
      ),
    ];
  }

  // --- CRM --------------------------------------------------------------------

  static List<AiBuildAction> _crmSystem() {
    const String dashboard = 'CRM Dashboard';
    const String customersPage = 'Customers';
    const String dealsPage = 'Deals';
    const String activitiesPage = 'Activities';

    return <AiBuildAction>[
      _page(ref: 'page_dashboard', name: dashboard, icon: 'groups'),
      _page(ref: 'page_customers', name: customersPage, icon: 'person'),
      _page(ref: 'page_deals', name: dealsPage, icon: 'handshake'),
      _page(ref: 'page_activities', name: activitiesPage, icon: 'event', nav: AiBuildPageNavigation.drawer),
      _table(
        ref: 'table_customers',
        pageRef: customersPage,
        name: 'Customers',
        columns: <AiBuildColumnSpec>[
          _col('Customer Name', 'text', required: true),
          _col('Email', 'text'),
          _col('Phone', 'text'),
          _col('Status', 'dropdown'),
        ],
      ),
      _table(
        ref: 'table_deals',
        pageRef: dealsPage,
        name: 'Deals',
        columns: <AiBuildColumnSpec>[
          _col('Deal Name', 'text', required: true),
          _col('Customer', 'text'),
          _col('Amount', 'number'),
          _col('Stage', 'dropdown'),
          _col('Close Date', 'date'),
        ],
      ),
      _table(
        ref: 'table_activities',
        pageRef: activitiesPage,
        name: 'Activities',
        columns: <AiBuildColumnSpec>[
          _col('Date', 'date'),
          _col('Type', 'dropdown'),
          _col('Customer', 'text'),
          _col('Notes', 'text'),
        ],
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Deals',
        title: 'Pipeline Value',
        formula: 'SUM(Deals.Amount)',
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Customers',
        title: 'Total Customers',
        formula: 'COUNT(Customers."Customer Name")',
      ),
      _chart(
        pageRef: dashboard,
        tableRef: 'Deals',
        title: 'Deals by Stage',
        chartType: AiBuildChartType.pie,
        xColumn: 'Stage',
        yColumn: 'Amount',
      ),
    ];
  }

  // --- Gym / fitness ----------------------------------------------------------

  static List<AiBuildAction> _gymSystem() {
    const String dashboard = 'Gym Dashboard';
    const String membersPage = 'Members';
    const String workoutsPage = 'Workouts';
    const String attendancePage = 'Attendance';
    const String subscriptionsPage = 'Subscriptions';
    const String trainersPage = 'Trainers';
    const String reportsPage = 'Reports';

    return <AiBuildAction>[
      _page(ref: 'page_dashboard', name: dashboard, icon: 'fitness_center'),
      _page(ref: 'page_members', name: membersPage, icon: 'groups'),
      _page(ref: 'page_workouts', name: workoutsPage, icon: 'sports_gymnastics'),
      _page(ref: 'page_attendance', name: attendancePage, icon: 'event_available'),
      _page(
        ref: 'page_subscriptions',
        name: subscriptionsPage,
        icon: 'card_membership',
      ),
      _page(ref: 'page_trainers', name: trainersPage, icon: 'person', nav: AiBuildPageNavigation.drawer),
      _page(ref: 'page_reports', name: reportsPage, icon: 'assessment', nav: AiBuildPageNavigation.drawer),
      _table(
        ref: 'table_members',
        pageRef: membersPage,
        name: 'Members',
        columns: <AiBuildColumnSpec>[
          _col('Full Name', 'text', required: true),
          _col('Membership Type', 'dropdown'),
          _col('Start Date', 'date'),
          _col('Phone', 'text'),
        ],
      ),
      _table(
        ref: 'table_workouts',
        pageRef: workoutsPage,
        name: 'Workout Logs',
        columns: <AiBuildColumnSpec>[
          _col('Date', 'date'),
          _col('Member', 'text'),
          _col('Workout Type', 'text'),
          _col('Duration Min', 'number'),
          _col('Notes', 'text'),
        ],
      ),
      _table(
        ref: 'table_attendance',
        pageRef: attendancePage,
        name: 'Attendance Logs',
        columns: <AiBuildColumnSpec>[
          _col('Date', 'date'),
          _col('Member', 'text'),
          _col('Check In', 'text'),
          _col('Check Out', 'text'),
        ],
      ),
      _table(
        ref: 'table_plans',
        pageRef: subscriptionsPage,
        name: 'Membership Plans',
        columns: <AiBuildColumnSpec>[
          _col('Plan Name', 'text', required: true),
          _col('Monthly Fee', 'number'),
          _col('Duration Months', 'number'),
        ],
      ),
      _table(
        ref: 'table_payments',
        pageRef: subscriptionsPage,
        name: 'Payments',
        columns: <AiBuildColumnSpec>[
          _col('Date', 'date'),
          _col('Member', 'text'),
          _col('Amount', 'number'),
          _col('Plan', 'text'),
        ],
      ),
      _table(
        ref: 'table_trainers',
        pageRef: trainersPage,
        name: 'Trainers',
        columns: <AiBuildColumnSpec>[
          _col('Trainer Name', 'text', required: true),
          _col('Specialty', 'text'),
          _col('Phone', 'text'),
        ],
      ),
      _summaryTable(
        ref: 'table_attendance_summary',
        pageRef: reportsPage,
        name: 'Attendance Summary',
        sourceTable: 'Attendance Logs',
        groupBy: 'Date',
        aggregate: 'Member',
        operation: AiBuildSummaryOperation.count,
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Members',
        title: 'Total Members',
        formula: 'COUNT(Members."Full Name")',
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Payments',
        title: 'Monthly Revenue',
        formula:
            'SUM(IF(Payments.Date>=DAYS_AGO(30),IF(Payments.Date<=TODAY(),Payments.Amount,0),0))',
      ),
      _chart(
        pageRef: dashboard,
        tableRef: 'Attendance Logs',
        title: 'Attendance Chart',
        chartType: AiBuildChartType.bar,
        xColumn: 'Date',
        yColumn: 'Member',
      ),
      _chart(
        pageRef: dashboard,
        tableRef: 'Workout Logs',
        title: 'Workout Progress',
        chartType: AiBuildChartType.line,
        xColumn: 'Date',
        yColumn: 'Duration Min',
      ),
    ];
  }

  // --- Lending ----------------------------------------------------------------

  static List<AiBuildAction> _lendingSystem() {
    const String dashboard = 'Lending Dashboard';
    const String borrowersPage = 'Borrowers';
    const String loansPage = 'Loans';
    const String paymentsPage = 'Payments';

    return <AiBuildAction>[
      _page(ref: 'page_dashboard', name: dashboard, icon: 'account_balance'),
      _page(ref: 'page_borrowers', name: borrowersPage, icon: 'people'),
      _page(ref: 'page_loans', name: loansPage, icon: 'request_quote'),
      _page(ref: 'page_payments', name: paymentsPage, icon: 'paid'),
      _table(
        ref: 'table_borrowers',
        pageRef: borrowersPage,
        name: 'Borrowers',
        columns: <AiBuildColumnSpec>[
          _col('Borrower Name', 'text', required: true),
          _col('Phone', 'text'),
          _col('Email', 'text'),
        ],
      ),
      _table(
        ref: 'table_loans',
        pageRef: loansPage,
        name: 'Loans',
        columns: <AiBuildColumnSpec>[
          _col('Loan ID', 'text'),
          _col('Borrower', 'text'),
          _col('Principal', 'number'),
          _col('Interest Rate', 'number'),
          _col('Start Date', 'date'),
        ],
      ),
      _table(
        ref: 'table_payments',
        pageRef: paymentsPage,
        name: 'Payments',
        columns: <AiBuildColumnSpec>[
          _col('Date', 'date'),
          _col('Loan', 'text'),
          _col('Amount', 'number'),
          _col('Status', 'dropdown'),
        ],
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Loans',
        title: 'Outstanding Principal',
        formula: 'SUM(Loans.Principal)',
      ),
      _card(
        pageRef: dashboard,
        tableRef: 'Payments',
        title: 'Monthly Collections',
        formula:
            'SUM(IF(Payments.Date>=DAYS_AGO(30),IF(Payments.Date<=TODAY(),Payments.Amount,0),0))',
      ),
      _chart(
        pageRef: dashboard,
        tableRef: 'Payments',
        title: 'Payments Trend',
        chartType: AiBuildChartType.line,
        xColumn: 'Date',
        yColumn: 'Amount',
      ),
    ];
  }

  // --- Builders ---------------------------------------------------------------

  static CreatePageAction _page({
    required String ref,
    required String name,
    required String icon,
    AiBuildPageNavigation nav = AiBuildPageNavigation.bottom,
  }) =>
      CreatePageAction(
        ref: ref,
        name: name,
        icon: icon,
        navigation: nav,
      );

  static CreateTableAction _table({
    required String ref,
    required String pageRef,
    required String name,
    required List<AiBuildColumnSpec> columns,
  }) =>
      CreateTableAction(
        ref: ref,
        pageRef: pageRef,
        name: name,
        columns: columns,
      );

  static CreateTableAction _summaryTable({
    required String ref,
    required String pageRef,
    required String name,
    required String sourceTable,
    required String groupBy,
    required String aggregate,
    AiBuildSummaryOperation operation = AiBuildSummaryOperation.sum,
  }) =>
      CreateTableAction(
        ref: ref,
        pageRef: pageRef,
        name: name,
        columns: const <AiBuildColumnSpec>[],
        tableKind: AiBuildTableKind.summary,
        summary: AiBuildSummarySpec(
          sourceTable: sourceTable,
          groupBy: groupBy,
          aggregate: aggregate,
          operation: operation,
        ),
      );

  static CreateCardWidgetAction _card({
    required String pageRef,
    required String tableRef,
    required String title,
    required String formula,
  }) =>
      CreateCardWidgetAction(
        pageRef: pageRef,
        tableRef: tableRef,
        title: title,
        formula: formula,
      );

  static CreateChartWidgetAction _chart({
    required String pageRef,
    required String tableRef,
    required String title,
    required AiBuildChartType chartType,
    required String xColumn,
    required String yColumn,
  }) =>
      CreateChartWidgetAction(
        pageRef: pageRef,
        tableRef: tableRef,
        title: title,
        chartType: chartType,
        xColumn: xColumn,
        yColumn: yColumn,
      );

  static AiBuildColumnSpec _col(
    String name,
    String type, {
    bool required = false,
  }) =>
      AiBuildColumnSpec(name: name, type: type, required: required);
}

/// Output of [AiBuildSystemArchitect.tryExpand].
final class AiBuildArchitectResult {
  const AiBuildArchitectResult({
    required this.parseResult,
    required this.plan,
    required this.analysis,
  });

  final AiBuildActionParseResult parseResult;
  final AiBuildPlan plan;
  final AiBuildIntentAnalysis analysis;
}
