import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../routes.dart';
import '../services/firestore_service.dart';
import '../utils/dialog_helper.dart';

/// A screen that provides an overview of the user's budget.
/// It displays the budget categories, spending trends, and allows the user
/// to select a month to view the budget for that month.
/// The screen also provides options to create a new budget, delete an existing budget.
class BudgetOverviewScreen extends StatefulWidget {
  const BudgetOverviewScreen({super.key});

  @override
  State<BudgetOverviewScreen> createState() => _BudgetOverviewScreenState();
}

// The state for the BudgetOverviewScreen.
class _BudgetOverviewScreenState extends State<BudgetOverviewScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final List<Color> chartColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.cyan,
    Colors.indigo,
  ];

  Map<String, double> budgetData = {};
  Map<String, double> spentData = {};
  Map<String, double> monthlyTrends = {};
  bool loading = true;
  bool isCurrentMonth = false;
  String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  bool expandChart = false;
  bool expandTrend = false;
  final List<String> expandedCategories = [];

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

  Future<void> _loadData() async {
    final parts = selectedMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final results = await Future.wait([
      _firestoreService.getSavedBudgetsByMonth(year, month),
      _firestoreService.calculateCategoryExpensesByMonth(year, month),
      _firestoreService.isMonthBudgetSet(year, month),
      _firestoreService.getMonthlySpendingTrends(),
    ]);

    setState(() {
      budgetData = results[0] as Map<String, double>;
      spentData = results[1] as Map<String, double>;
      isCurrentMonth = results[2] as bool;
      monthlyTrends = results[3] as Map<String, double>;
      loading = false;
    });
  }

  // Check if the selected month is the current month
  bool _isCurrentMonth() {
    final now = DateTime.now();
    final selected = DateTime.parse('$selectedMonth-01');
    return selected.year == now.year && selected.month == now.month;
  }

  // Check if the selected month is in the past
  bool _isPastMonth() {
    final now = DateTime.now();
    final selected = DateTime.parse('$selectedMonth-01');
    return selected.isBefore(DateTime(now.year, now.month));
  }

  // Check if the selected month is in the future and has a budget set
  bool _isFutureMonthWithBudget() {
    final now = DateTime.now();
    final selected = DateTime.parse('$selectedMonth-01');
    return selected.isAfter(DateTime(now.year, now.month)) &&
        budgetData.isNotEmpty;
  }

  // Build the month selector dropdown
  Widget _buildMonthSelector() {
    final now = DateTime.now();
    final months = List.generate(
      12,
      (i) => DateFormat('yyyy-MM').format(DateTime(now.year, i + 1)),
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.blueAccent),
            const SizedBox(width: 12),
            const Text('Select Month:'),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: selectedMonth,
              underline: const SizedBox(),
              onChanged: (val) {
                setState(() {
                  selectedMonth = val!;
                  loading = true;
                });
                _loadData();
              },
              items:
                  months
                      .map(
                        (month) =>
                            DropdownMenuItem(value: month, child: Text(month)),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Build the top category card
  Widget _buildTopCategory() {
    if (spentData.isEmpty) return const SizedBox();
    final top = spentData.entries.reduce((a, b) => a.value > b.value ? a : b);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.deepPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "You spent most on: ${top.key} (\$${top.value.toStringAsFixed(2)})",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build the pie chart card
  Widget _buildPieChart() {
    final entries = spentData.entries.toList();
    if (entries.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showPieChartModal(context),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Spending Breakdown',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Center(child: Text('Tap to expand pie chart')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Show the pie chart modal
  void _showPieChartModal(BuildContext context) {
    final total = spentData.values.fold(0.0, (a, b) => a + b);
    final entries = spentData.entries.toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(color: Colors.black.withOpacity(0.4)),
                ),
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Spending Breakdown',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 280,
                          child: PieChart(
                            PieChartData(
                              sections: List.generate(entries.length, (i) {
                                final entry = entries[i];
                                final percent =
                                    total == 0
                                        ? 0
                                        : (entry.value / total * 100);
                                return PieChartSectionData(
                                  value: entry.value,
                                  title:
                                      '${entry.key} ${percent.toStringAsFixed(0)}%',
                                  color: chartColors[i % chartColors.length],
                                  radius: 60,
                                  titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Build the spending trend card
  Widget _buildSpendingTrend() {
    if (monthlyTrends.isEmpty) return const SizedBox();

    final months = monthlyTrends.keys.toList()..sort();
    final values = months.map((m) => monthlyTrends[m]!).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showSpendingTrendModal(context),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "📈 Monthly Spending Trend",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Center(child: Text('Tap to expand trend')),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
        if (expandTrend) _buildMonthlyTrendDetails(months, values),
      ],
    );
  }

  // Show the spending trend modal
  void _showSpendingTrendModal(BuildContext context) {
    final months = monthlyTrends.keys.toList()..sort();
    final values = months.map((m) => monthlyTrends[m]!).toList();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(color: Colors.black.withOpacity(0.4)),
                ),
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Monthly Spending Trend',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 280,
                          child: LineChart(
                            LineChartData(
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (val, meta) {
                                      final month =
                                          months[val.toInt()].split('-')[1];
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(month),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: true),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    months.length,
                                    (i) => FlSpot(i.toDouble(), values[i]),
                                  ),
                                  isCurved: true,
                                  color: Colors.lightBlue,
                                  barWidth: 3,
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.lightBlue.withOpacity(0.3),
                                  ),
                                  dotData: FlDotData(show: true),
                                ),
                              ],
                              gridData: FlGridData(show: false),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Build the monthly trend details
  Widget _buildMonthlyTrendDetails(List<String> months, List<double> values) {
    return Column(
      children: List.generate(months.length, (i) {
        final monthDate = DateTime.parse('${months[i]}-01');
        final monthLabel = DateFormat('MMMM yyyy').format(monthDate);
        final amount = values[i];
        final prev = i > 0 ? values[i - 1] : null;
        final change =
            prev != null && prev != 0 ? ((amount - prev) / prev * 100) : null;

        // Simulated top category — you can replace this with actual Firestore data later
        String? topCategory;
        if (i == months.length - 1 && spentData.isNotEmpty) {
          final top = spentData.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          topCategory = top.key;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monthLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (change != null)
                    Row(
                      children: [
                        Icon(
                          change > 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: change > 0 ? Colors.red : Colors.green,
                        ),
                        Text(
                          '${change.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: change > 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (topCategory != null && i == months.length - 1) ...[
                const SizedBox(height: 4),
                Text(
                  'Top category: $topCategory',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  // Build the single month category card
  Widget _buildSingleMonthCategoryCard() {
    if (budgetData.isEmpty) return const SizedBox();

    final monthDate = DateTime.parse('$selectedMonth-01');
    final monthLabel = DateFormat('MMMM yyyy').format(monthDate);

    return _cardWrapper(
      title: '📘 Budget Categories for $monthLabel',
      children:
          budgetData.entries.map((entry) {
            final category = entry.key;
            final limit = entry.value;
            final spent = spentData[category] ?? 0;
            return AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _buildExpandableCategory(category, spent, limit),
            );
          }).toList(),
    );
  }

  // Build the card wrapper
  Widget _cardWrapper({
    required String title,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  // Build the expandable category card
  Widget _buildExpandableCategory(String category, double spent, double limit) {
    final percent = (spent / limit).clamp(0.0, 1.0);
    final overLimit = spent > limit;
    final isExpanded = expandedCategories.contains(category);
    final totalBudget = budgetData.values.fold(0.0, (a, b) => a + b);
    final categoryPercent = totalBudget == 0 ? 0 : (spent / totalBudget) * 100;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 12),

      child: InkWell(
        onTap:
            () => setState(() {
              if (isExpanded) {
                expandedCategories.remove(category);
              } else {
                expandedCategories.add(category);
              }
            }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text('${categoryPercent.toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: percent),
                duration: const Duration(milliseconds: 800),
                builder:
                    (context, value, _) => LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        overLimit ? Colors.redAccent : Colors.green,
                      ),
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '\$${spent.toStringAsFixed(2)} / \$${limit.toStringAsFixed(2)}',
                style: TextStyle(
                  color: overLimit ? Colors.redAccent : Colors.black,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      overLimit ? 'Over Budget' : 'On Track',
                      style: TextStyle(
                        color: overLimit ? Colors.red : Colors.green,
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.pushNamed(
                            context,
                            RouteNames.transactions,
                            arguments: {'category': category},
                          ),
                      child: const Text('View Transactions'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Build the delete budget button
  Widget _buildDeleteButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Delete Budget'),
                content: const Text('This will delete your budget. Continue?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        );
        if (confirm == true) {
          final parts = selectedMonth.split('-');
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          await _firestoreService.deleteBudgetByMonth(year, month);
          DialogHelper.showSnackbar(context, 'Budget deleted');
          await _loadData();
        }
      },
      icon: const Icon(Icons.delete),
      label: const Text('Delete Budget'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // Build the rollover banner
  Widget _buildRolloverBanner() {
    final now = DateTime.now();
    final daysLeft =
        DateTime(now.year, now.month + 1, 1).difference(now).inDays;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '🔁 Your categories will roll over in $daysLeft days',
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  // Build the entire screen
  @override
  Widget build(BuildContext context) {
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
                    _buildMonthSelector(),
                    const SizedBox(height: 12),
                    if (budgetData.isEmpty)
                      const Text('No budget set. Please create one.')
                    else ...[
                      const SizedBox(height: 8),
                      if (_isFutureMonthWithBudget())
                        const Text(
                          'This is not a locked budget.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      if (_isCurrentMonth()) _buildRolloverBanner(),
                      const SizedBox(height: 8),
                      _buildTopCategory(),
                      const SizedBox(height: 12),
                      _buildPieChart(),
                      _buildSpendingTrend(),
                      _buildSingleMonthCategoryCard(),
                      const SizedBox(height: 20),
                      if (!_isPastMonth()) _buildDeleteButton(),
                    ],
                  ],
                ),
              ),
      floatingActionButton:
          (!_isPastMonth() && budgetData.isNotEmpty)
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
                    await _loadData();
                  }
                },
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}
