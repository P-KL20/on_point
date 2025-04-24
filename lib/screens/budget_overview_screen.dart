import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../routes.dart';
import '../services/firestore_service.dart';
import '../main.dart';
import '../utils/dialog_helper.dart';
import 'budget_overview_components.dart';

/// This screen displays the budget overview, including the budget data,
/// spending trends, and category progress.
/// It allows users to select a month and view their budget and spending
/// information for that month.
/// It also provides options to create a new budget or delete an existing one.
class BudgetOverviewScreen extends StatefulWidget {
  const BudgetOverviewScreen({super.key});

  @override
  State<BudgetOverviewScreen> createState() => _BudgetOverviewScreenState();
}

class _BudgetOverviewScreenState extends State<BudgetOverviewScreen>
    with RouteAware {
  final FirestoreService _firestoreService = FirestoreService();
  int _loadSessionId = 0;

  Map<String, double> budgetData = {};
  Map<String, double> spentData = {};
  Map<String, double> monthlyTrends = {};
  bool loading = true;
  bool isCurrentMonth = false;
  bool hasBudget = false;
  String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        selectedMonth = args;
      }
      _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
  }

  /// This method is used to load the budget data for the selected month.
  Future<void> _loadData() async {
    final currentLoadId = ++_loadSessionId;

    final parts = selectedMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    setState(() {
      budgetData = {};
      spentData = {};
      monthlyTrends = {};
      loading = true;
    });

    final results = await Future.wait([
      _firestoreService.getSavedBudgetsByMonth(year, month),
      _firestoreService.calculateCategoryExpensesByMonth(year, month),
      _firestoreService.isMonthBudgetSet(year, month),
      _firestoreService.getMonthlySpendingTrends(),
    ]);

    if (!mounted || currentLoadId != _loadSessionId) return; // Outdated session

    final selected = DateTime.parse('$selectedMonth-01');
    final now = DateTime.now();

    setState(() {
      budgetData = results[0] as Map<String, double>;
      spentData = results[1] as Map<String, double>;
      monthlyTrends = results[3] as Map<String, double>;
      isCurrentMonth = selected.year == now.year && selected.month == now.month;
      hasBudget = results[2] as bool;
      loading = false;
    });
  }

  // This method is called when the user navigates to this screen.
  // It is used to update the selected month and reload the data.
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final selected = DateTime.parse('$selectedMonth-01');
    final isPastMonth = selected.isBefore(DateTime(now.year, now.month, 1));

    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[200],
        elevation: 0,
        title: const Text(
          'Budget Overview',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    MonthSelector(
                      selectedMonth: selectedMonth,
                      onChanged: (val) {
                        if (val == null) return;

                        final shouldReload = val != selectedMonth;

                        setState(() {
                          selectedMonth = val;
                          loading = true;
                        });

                        if (shouldReload) {
                          _loadData();
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _loadData(),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (!hasBudget)
                      const Text('No budget set. Please create one.')
                    else ...[
                      const SizedBox(height: 8),
                      if (DateTime.parse('$selectedMonth-01').isAfter(
                            DateTime(DateTime.now().year, DateTime.now().month),
                          ) &&
                          hasBudget)
                        const Text(
                          'This is not a locked budget.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      if (isCurrentMonth) const RolloverBanner(),
                      const SizedBox(height: 8),
                      TopCategoryCard(spentData: spentData),
                      const SizedBox(height: 12),
                      PieChartCard(spentData: spentData),
                      SpendingTrendCard(
                        trends: monthlyTrends,
                        spentData: spentData,
                      ),
                      CategoryProgressCard(
                        budgetData: budgetData,
                        spentData: spentData,
                        selectedMonth: selectedMonth,
                      ),
                      const SizedBox(height: 20),
                      if (!isPastMonth)
                        DeleteBudgetButton(
                          selectedMonth: selectedMonth,
                          onDelete: () {
                            Future.microtask(() {
                              if (context.mounted) {
                                DialogHelper.showSnackbar(
                                  context,
                                  'Budget deleted',
                                );
                                _loadData();
                              }
                            });
                          },
                        ),
                    ],
                  ],
                ),
              ),
      floatingActionButton:
          (!isPastMonth && !hasBudget)
              ? FloatingActionButton(
                backgroundColor: Colors.lightBlue[300],
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    RouteNames.createBudget,
                    arguments: selectedMonth,
                  );
                  if (result is String) {
                    setState(() {
                      selectedMonth = result;
                      loading = true;
                    });

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _loadData();
                    });
                  }
                },
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}
