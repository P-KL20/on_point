import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The FirestoreService class is responsible for managing Firestore
/// interactions related to user transactions and budgets.
/// It provides methods to add, update, delete, and retrieve transactions,
/// as well as to calculate account balances and category expenses.
/// It also provides methods to manage budgets, including saving,
/// retrieving, and deleting budgets for specific months.
/// The class uses the FirebaseFirestore instance to perform
/// CRUD operations on the Firestore database.
/// It also provides methods to get bank balances over time and
/// to check if a budget exists for a specific month.
/// The class is designed to be used in conjunction with the
/// Firebase Authentication service to manage user-specific data.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  String buildMonthKey(int year, int month) {
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  // Add a new transaction under the authenticated user's subcollection
  Future<void> addTransaction({
    required String transactionType,
    required String accountType,
    required String bank,
    required double amount,
    required DateTime date,
    String? comment,
    String? category,
    String? transferId,
  }) async {
    await _db.collection('users').doc(uid).collection('transactions').add({
      'transactionType': transactionType,
      'accountType': accountType,
      'bank': bank,
      'amount': amount,
      'date': date.toIso8601String(),
      'comment': comment ?? '',
      'category': category ?? 'Uncategorized',
      'createdAt': DateTime.now().toIso8601String(),
      if (transferId != null) 'transferId': transferId,
    });
  }

  // Calculate account balances based on transactions
  Future<Map<String, double>> calculateAccountBalances() async {
    final Map<String, double> balances = {};
    final snapshot =
        await _db.collection('users').doc(uid).collection('transactions').get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String? transactionType = data['transactionType'];
      final double amount = (data['amount'] ?? 0).toDouble();
      final String accountType = data['accountType'];
      final String bank = data['bank'];
      final String key = '$bank - $accountType';

      switch (transactionType) {
        case 'Deposit':
        case 'Income':
        case 'Transfer In':
          balances[key] = (balances[key] ?? 0) + amount;
          break;
        case 'Withdrawal':
        case 'Expense':
        case 'Bill Payment':
        case 'Purchase':
        case 'Subscription':
        case 'Transfer Out':
          balances[key] = (balances[key] ?? 0) - amount;
          break;
      }
    }

    return balances;
  }

  // Calculate expenses grouped by user-defined budget category
  Future<Map<String, double>> calculateCategoryExpenses() async {
    final snapshot =
        await _db.collection('users').doc(uid).collection('transactions').get();

    final Map<String, double> totals = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String category = data['category'] ?? 'Uncategorized';
      final String type = data['transactionType'];
      final double amount = (data['amount'] ?? 0).toDouble();

      if ([
        'Withdrawal',
        'Expense',
        'Purchase',
        'Bill Payment',
        'Subscription',
      ].contains(type)) {
        totals[category] = (totals[category] ?? 0) + amount;
      }
    }
    return totals;
  }

  // Calculate category expenses by user-defined category (for a month)
  Future<Map<String, double>> calculateCategoryExpensesByMonth(
    int year,
    int month,
  ) async {
    final snapshot =
        await _db
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .where(
              'date',
              isGreaterThanOrEqualTo:
                  DateTime(year, month, 1).toIso8601String(),
            )
            .where(
              'date',
              isLessThan: DateTime(year, month + 1, 1).toIso8601String(),
            )
            .get();

    final Map<String, double> totals = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String category = data['category'] ?? 'Uncategorized';
      final String type = data['transactionType'];
      final double amount = (data['amount'] ?? 0).toDouble();

      if ([
        'Withdrawal',
        'Expense',
        'Purchase',
        'Bill Payment',
        'Subscription',
      ].contains(type)) {
        totals[category] = (totals[category] ?? 0) + amount;
      }
    }
    return totals;
  }

  // Calculate category expenses by user-defined category (for a month)
  Future<Map<String, double>> getSavedBudgets() async {
    final now = DateTime.now();
    final doc =
        await _db
            .collection('users')
            .doc(uid)
            .collection('budgets')
            .doc('${now.year}-${now.month}')
            .get();

    if (!doc.exists) return {};

    final data = doc.data()!;
    final Map<String, double> parsed = {};
    final Map<String, dynamic> raw = Map<String, dynamic>.from(
      data['categories'] ?? {},
    );
    for (var key in raw.keys) {
      parsed[key] = (raw[key] as num).toDouble();
    }
    return parsed;
  }

  // Save budget data for a specific month
  Future<void> saveBudget(
    Map<String, double> budgetData,
    String targetMonth,
  ) async {
    final parts = targetMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    await _db
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(targetMonth)
        .set({
          'categories': budgetData,
          'month': month,
          'year': year,
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  // Get saved budgets for a specific month
  Future<Map<String, double>> getSavedBudgetsByMonth(
    int year,
    int month,
  ) async {
    final docId = buildMonthKey(year, month);
    final doc =
        await _db
            .collection('users')
            .doc(uid)
            .collection('budgets')
            .doc(docId)
            .get();
    if (!doc.exists) return {};

    final data = doc.data()!;
    final Map<String, double> parsed = {};
    final Map<String, dynamic> raw = Map<String, dynamic>.from(
      data['categories'] ?? {},
    );
    for (var key in raw.keys) {
      parsed[key] = (raw[key] as num).toDouble();
    }
    return parsed;
  }

  // Check if a budget exists for a specific month
  Future<bool> isMonthBudgetSet(int year, int month) async {
    final docId = buildMonthKey(year, month);
    final doc =
        await _db
            .collection('users')
            .doc(uid)
            .collection('budgets')
            .doc(docId)
            .get();
    return doc.exists;
  }

  // Delete a budget for a specific month
  Future<void> deleteBudgetByMonth(int year, int month) async {
    final docId = buildMonthKey(year, month);
    await _db
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(docId)
        .delete();
  }

  // Get monthly spending trends
  Future<Map<String, double>> getMonthlySpendingTrends() async {
    final snapshot =
        await _db.collection('users').doc(uid).collection('transactions').get();

    final Map<String, double> monthlyTotals = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final date = DateTime.parse(data['date']);
      final String key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final double amount = (data['amount'] ?? 0).toDouble();
      final String type = data['transactionType'];

      if ([
        'Withdrawal',
        'Expense',
        'Purchase',
        'Bill Payment',
        'Subscription',
      ].contains(type)) {
        monthlyTotals[key] = (monthlyTotals[key] ?? 0) + amount;
      }
    }

    return monthlyTotals;
  }

  // Get monthly spending trends for a specific month
  Future<bool> isCurrentMonthBudgetSet() async {
    final now = DateTime.now();
    final docId = buildMonthKey(now.year, now.month);
    final doc =
        await _db
            .collection('users')
            .doc(uid)
            .collection('budgets')
            .doc(docId)
            .get();
    return doc.exists;
  }

  // Delete the current month's budget
  Future<void> deleteBudget() async {
    final now = DateTime.now();
    final docId = buildMonthKey(now.year, now.month);
    await _db
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(docId)
        .delete();
  }

  // Get all transactions for the authenticated user
  Stream<QuerySnapshot> getTransactions() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get a specific transaction by document ID
  Future<void> updateTransaction(
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(docId)
        .update(data);
  }

  // Delete a specific transaction by document ID
  Future<void> deleteTransaction(String docId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(docId)
        .delete();
  }

  // Get bank balances over time
  Future<Map<String, List<double>>> getBankBalancesOverTime() async {
    final snapshot =
        await _db
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .orderBy('date')
            .get();

    final Map<String, Map<String, double>> monthlyByBank = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String type = data['transactionType'];
      final String bank = data['bank'];
      final String account = data['accountType'];
      final double amount = (data['amount'] ?? 0).toDouble();
      final date = DateTime.tryParse(data['date']) ?? DateTime.now();
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final key = '$bank - $account';

      final isIncome = ['Income', 'Deposit'].contains(type);
      final isExpense = [
        'Expense',
        'Withdrawal',
        'Subscription',
        'Purchase',
        'Bill Payment',
      ].contains(type);

      monthlyByBank.putIfAbsent(key, () => {});
      final map = monthlyByBank[key]!;

      if (!map.containsKey(monthKey)) map[monthKey] = 0.0;

      if (isIncome) map[monthKey] = map[monthKey]! + amount;
      if (isExpense) map[monthKey] = map[monthKey]! - amount;
    }

    // Format as sorted double lists
    final Map<String, List<double>> sparkData = {};
    for (var entry in monthlyByBank.entries) {
      final sorted =
          entry.value.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      sparkData[entry.key] = sorted.map((e) => e.value).toList();
    }

    return sparkData;
  }
}
