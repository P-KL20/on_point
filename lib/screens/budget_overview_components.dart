import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import 'dart:ui';

/// Colors for pie chart sections
final List<Color> _chartColors = [
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.pink,
  Colors.teal,
  Colors.cyan,
  Colors.indigo,
];

/// Widget to select a month for budget overview
/// and display a rollover banner.
class MonthSelector extends StatelessWidget {
  final String selectedMonth;
  final ValueChanged<String?> onChanged;

  const MonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
              onChanged: (value) {
                if (value != null) onChanged(value);
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
}

/// Widget to display a rollover banner
/// indicating the number of days left until the next month.
class RolloverBanner extends StatelessWidget {
  const RolloverBanner({super.key});

  @override
  Widget build(BuildContext context) {
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
}

/// Widget to display the top spending category
/// based on the provided spending data.
class TopCategoryCard extends StatelessWidget {
  final Map<String, double> spentData;

  const TopCategoryCard({super.key, required this.spentData});

  @override
  Widget build(BuildContext context) {
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
}

/// Widget to display a pie chart
/// representing the spending breakdown by category.
class PieChartCard extends StatelessWidget {
  final Map<String, double> spentData;

  const PieChartCard({super.key, required this.spentData});

  @override
  Widget build(BuildContext context) {
    final entries = spentData.entries.toList();
    if (entries.isEmpty) return const SizedBox();
    final total = spentData.values.fold(0.0, (a, b) => a + b);

    return InkWell(
      onTap: () => _showPieChartModal(context, entries, total),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Spending Breakdown',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Center(child: Text('Tap to expand pie chart')),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a modal with a pie chart
  /// representing the spending breakdown by category.
  void _showPieChartModal(
    BuildContext context,
    List<MapEntry<String, double>> entries,
    double total,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => Dialog(
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
                                  color: _chartColors[i % _chartColors.length],
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
}

/// Widget to display a button for deleting the budget
/// for the selected month.
class DeleteBudgetButton extends StatelessWidget {
  final String selectedMonth;
  final VoidCallback onDelete;

  const DeleteBudgetButton({
    super.key,
    required this.selectedMonth,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.delete),
      label: const Text('Delete Budget'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
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

          await FirestoreService().deleteBudgetByMonth(year, month);

          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Budget deleted')));
            onDelete();
          }
        }
      },
    );
  }
}

/// Widget to display a card with the monthly spending trend
/// and a button to expand the trend.
class SpendingTrendCard extends StatelessWidget {
  final Map<String, double> trends;
  final Map<String, double> spentData;

  const SpendingTrendCard({
    super.key,
    required this.trends,
    required this.spentData,
  });

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) return const SizedBox();
    final months = trends.keys.toList()..sort();
    final values = months.map((m) => trends[m]!).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showSpendingTrendModal(context, months, values),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    "📈 Monthly Spending Trend",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Center(child: Text("Tap to expand trend")),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Show a modal with a line chart
  /// representing the monthly spending trend.
  void _showSpendingTrendModal(
    BuildContext context,
    List<String> months,
    List<double> values,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => Dialog(
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
                          "Monthly Spending Trend",
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
}

/// Widget to display a card with the budget categories
/// and their spending progress.
class CategoryProgressCard extends StatelessWidget {
  final Map<String, double> budgetData;
  final Map<String, double> spentData;
  final String selectedMonth;

  const CategoryProgressCard({
    super.key,
    required this.budgetData,
    required this.spentData,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    if (budgetData.isEmpty) return const SizedBox();

    final monthDate = DateTime.parse('$selectedMonth-01');
    final label = DateFormat('MMMM yyyy').format(monthDate);

    return Container(
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
            '📘 Budget Categories for $label',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...budgetData.entries.map((entry) {
            final category = entry.key;
            final limit = entry.value;
            final spent = spentData[category] ?? 0;
            final percent = (spent / limit).clamp(0.0, 1.0);
            final overLimit = spent > limit;
            final categoryPercent = (spent / limit * 100).clamp(0, 999);

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: InkWell(
                onTap: () {},
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
                      LinearProgressIndicator(
                        value: percent,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overLimit ? Colors.redAccent : Colors.green,
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
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
