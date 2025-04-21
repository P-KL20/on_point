import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import '../models/overspent_alert.dart';
import 'notification_service.dart';

/// The HomeService class is responsible for managing the home screen data,
/// including fetching dashboard data, calculating balances, and managing
/// notifications related to overspending and budget warnings.
/// It interacts with the FirestoreService to retrieve data from Firestore
/// and the NotificationService to handle notifications.
/// It provides methods to get dashboard data, calculate total balances,
/// get recent transactions, and manage overspending alerts.
/// It also provides methods to get the number of days left in the current
/// month and to clean up old notifications.
class HomeService {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  Future<Map<String, dynamic>> getDashboardData() async {
    final results = await Future.wait([
      _firestoreService.calculateAccountBalances(),
      _firestoreService.getTransactions().first,
      _firestoreService.calculateCategoryExpenses(),
      _firestoreService.getBankBalancesOverTime(),
      getActualOverspentCategories(),
    ]);

    return {
      'balances': results[0] as Map<String, double>,
      'transactions': results[1] as QuerySnapshot,
      'expenses': results[2] as Map<String, double>,
      'sparklineData': results[3] as Map<String, List<double>>,
      'overspent': results[4] as List<OverspentAlert>,
    };
  }

  /// This method calculates the number of days left in the current month.
  int getRolloverDaysLeft() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1).difference(now).inDays;
  }

  /// This method calculates the total balance from the provided map of balances.
  double calculateTotalBalance(Map<String, double> balances) {
    return balances.values.fold(0.0, (a, b) => a + b);
  }

  /// This method retrieves the recent transactions from the Firestore snapshot.
  List<QueryDocumentSnapshot> getRecentTransactions(QuerySnapshot snapshot) {
    return snapshot.docs.take(5).toList();
  }

  /// This method retrieves the bank balances over time for the sparkline chart.
  Future<List<OverspentAlert>> getActualOverspentCategories() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final monthKey = '$year-${month.toString().padLeft(2, '0')}';

    final expenses = await _firestoreService.calculateCategoryExpensesByMonth(
      year,
      month,
    );
    final budgets = await _firestoreService.getSavedBudgetsByMonth(year, month);

    final List<OverspentAlert> overspent = [];

    for (var entry in expenses.entries) {
      final category = entry.key;
      final spent = entry.value;
      final limit = budgets[category] ?? 0.0;

      if (limit > 0 && spent > 0) {
        final percent = spent / limit;

        if (percent > 1.0) {
          overspent.add(
            OverspentAlert(
              category: category,
              spent: spent,
              limit: limit,
              percent: percent,
            ),
          );
          await _notificationService.addOverspentNotification(
            category: category,
            spent: spent,
            limit: limit,
            monthKey: monthKey,
          );
        }

        if (percent >= 0.8 && percent < 1.0) {
          await _notificationService.addBudgetWarningNotification(
            category: category,
            spent: spent,
            limit: limit,
            monthKey: monthKey,
          );
        }
      }
    }

    overspent.sort((a, b) => b.percent.compareTo(a.percent));
    return overspent;
  }

  /// This method retrieves the recent transactions from the Firestore snapshot.
  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    return await _notificationService.getNotificationHistory();
  }

  /// This method retrieves the number of days left in the current month.
  Future<void> cleanupOldNotifications({int days = 60}) async {
    return await _notificationService.cleanupOldNotifications(days: days);
  }
}
