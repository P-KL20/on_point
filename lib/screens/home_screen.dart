import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/home_service.dart';
import '../../services/notification_service.dart';
import '../routes.dart';
import 'budget_input_screen.dart';
import 'transaction_history_screen.dart';
import 'budget_overview_screen.dart';
import '../models/overspent_alert.dart';

/// HomeScreen is the main screen of the app, displaying a dashboard with
/// account balances, recent transactions, and alerts.
/// It allows users to navigate to different sections of the app using a
/// bottom navigation bar.
/// It also fetches and displays notifications and alerts related to
/// overspending in different categories.
class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeService _homeService = HomeService();
  final NotificationService _notifService = NotificationService();

  bool showAllAlerts = false;
  int _selectedIndex = 0;
  int _unreadCount = 0;
  List<OverspentAlert> visibleAlerts(List<OverspentAlert> topOverspent) =>
      showAllAlerts ? topOverspent : topOverspent.take(3).toList();

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  /// Fetch the unread notification count when the screen is initialized
  void _loadUnreadCount() async {
    final count = await _notifService.fetchUnreadCount();
    setState(() {
      _unreadCount = count;
    });
  }

  /// Handle bottom navigation bar item taps
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Build the body of the screen based on the selected index
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _homeDashboard();
      case 1:
        return const BudgetInputScreen();
      case 2:
        return TransactionHistoryScreen();
      case 3:
        return const BudgetOverviewScreen();
      default:
        return _homeDashboard();
    }
  }

  /// Build the app bar with a title and action buttons
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.lightBlue[200],
      elevation: 0,
      title:
          _selectedIndex == 0
              ? Text(
                'Welcome, ${widget.user.displayName ?? "User"}!',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              )
              : const Text(''),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () async {
                final history = await _homeService.getNotificationHistory();
                Navigator.pushNamed(
                  context,
                  RouteNames.notifications,
                  arguments: history,
                );
                _loadUnreadCount();
              },
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            Navigator.pushNamed(context, RouteNames.settings);
          },
        ),
      ],
    );
  }

  /// Build the home dashboard with account balances, recent transactions,
  Widget _homeDashboard() {
    return FutureBuilder(
      future: _homeService.getDashboardData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data as Map<String, dynamic>;
        final balances = data['balances'] as Map<String, double>;
        final transactions = data['transactions'] as QuerySnapshot;
        final sparklineData =
            data['sparklineData'] as Map<String, List<double>>;
        final totalBalance = _homeService.calculateTotalBalance(balances);
        final sortedTransactions = _homeService.getRecentTransactions(
          transactions,
        );
        final topOverspent = data['overspent'] as List<OverspentAlert>;
        final daysLeft = _homeService.getRolloverDaysLeft();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader('Summary'),
            _totalBalanceCard(totalBalance),
            const SizedBox(height: 16),
            _sectionHeader('Accounts'),
            _groupedBankCards(balances, sparklineData),
            const SizedBox(height: 16),
            _sectionHeader('Recent Activity'),
            _recentTransactionCard(sortedTransactions),
            const SizedBox(height: 16),
            if (topOverspent.isNotEmpty) ...[
              _sectionHeader('Alerts'),
              for (final alert in visibleAlerts(topOverspent))
                _overBudgetAlert(alert),
              if (topOverspent.length > 3)
                TextButton(
                  onPressed:
                      () => setState(() => showAllAlerts = !showAllAlerts),
                  child: Text(
                    showAllAlerts ? 'Hide Extra Alerts' : 'View All Alerts',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            _rolloverBanner(daysLeft),
          ],
        );
      },
    );
  }

  /// Build the section header with a title
  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
      ),
    ),
  );

  /// Build the total balance card with the total balance amount
  Widget _totalBalanceCard(double balance) => _simpleCard(
    title: '🔢 Total Balance',
    content: '\$${balance.toStringAsFixed(2)}',
    textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
  );

  /// Build the grouped bank cards with account balances and sparkline charts
  Widget _groupedBankCards(
    Map<String, double> balances,
    Map<String, List<double>> sparklineData,
  ) => GridView.count(
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2,
    shrinkWrap: true,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    children:
        balances.entries.map((entry) {
          final sparkValues = sparklineData[entry.key] ?? [];
          return _simpleCard(
            title: entry.key,
            contentWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\$${entry.value.toStringAsFixed(2)}'),
                if (sparkValues.isNotEmpty) _sparkline(sparkValues),
              ],
            ),
          );
        }).toList(),
  );

  /// Build the sparkline chart for account balances
  Widget _sparkline(List<double> values) {
    return SizedBox(
      height: 30,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                values.length,
                (i) => FlSpot(i.toDouble(), values[i]),
              ),
              isCurved: true,
              color: Colors.teal,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
        ),
      ),
    );
  }

  /// Build the recent transactions card with a list of recent transactions
  Widget _recentTransactionCard(List<QueryDocumentSnapshot> docs) =>
      _simpleCard(
        title: '💸 Recent Transactions',
        contentWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var doc in docs)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${doc['transactionType']} - \$${doc['amount']}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            TextButton(
              onPressed:
                  () => Navigator.pushNamed(context, RouteNames.transactions),
              child: const Text('View All'),
            ),
          ],
        ),
      );

  /// Get the color based on the severity of overspending
  Color _getSeverityColor(double percent) {
    if (percent >= 2.0) {
      return Colors.red.shade700; // Critical
    } else if (percent >= 1.5) {
      return Colors.redAccent; // High
    } else if (percent >= 1.2) {
      return Colors.deepOrangeAccent; // Moderate
    } else {
      return Colors.orangeAccent; // Mild
    }
  }

  /// Get the label based on the severity of overspending
  String _getSeverityLabel(double percent) {
    if (percent >= 2.0) return 'Critical Overspending';
    if (percent >= 1.5) return 'High Overspending';
    if (percent >= 1.2) return 'Moderate Overspending';
    return 'Mild Overspending';
  }

  /// Build the overspending alert widget
  Widget _overBudgetAlert(OverspentAlert alert) {
    Color bgColor = _getSeverityColor(alert.percent);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You’ve overspent on ${alert.category}!',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${alert.spent.toStringAsFixed(2)} / \$${alert.limit.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  _getSeverityLabel(alert.percent), // 💡 This is the new line
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed:
                      () => Navigator.pushNamed(
                        context,
                        RouteNames.budgetOverview,
                      ),
                  child: const Text('View in Stats'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the rollover banner widget
  Widget _rolloverBanner(int daysLeft) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('🔁 Your categories will roll over in $daysLeft days'),
    );
  }

  /// Build a simple card widget with a title and content
  Widget _simpleCard({
    required String title,
    String? content,
    TextStyle? textStyle,
    Widget? contentWidget,
    Color color = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (contentWidget != null)
            contentWidget
          else if (content != null)
            Text(content, style: textStyle),
        ],
      ),
    );
  }

  /// Build the main widget tree
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: '',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: ''),
        ],
      ),
    );
  }
}
