import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firestore_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

/// This is a service class for managing transactions in a Flutter app.
/// It provides methods to filter transactions, calculate summaries,
/// group transactions by month, and validate and process transactions.
/// It uses Firestore to store and retrieve transaction data.
/// The class includes methods to filter transactions by bank and category,
/// calculate total income and expenses, and group transactions by month.
/// It also includes a method to validate and process transactions,
/// ensuring that all required fields are filled and that there are sufficient funds
/// for withdrawal or transfer transactions.
/// The class handles different transaction types, including deposits, withdrawals,
/// transfers, and various payment types.
/// It also includes error handling for invalid inputs and insufficient funds.
/// The class uses the FirestoreService to interact with Firestore for adding transactions
/// and calculating account balances.
class TransactionService {
  final FirestoreService _firestoreService = FirestoreService();
  final _uuid = Uuid();
  final ValueNotifier<String?> highlightedTransferId = ValueNotifier<String?>(
    null,
  );

  /// Filters a list of documents by selected bank and optional category
  List<QueryDocumentSnapshot> filterTransactions(
    List<QueryDocumentSnapshot> docs, {
    String selectedBank = 'All',
    String? category,
  }) {
    return docs.where((doc) {
      final bank = doc['bank'] ?? '';
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final docCategory =
          data.containsKey('category') ? data['category'] : 'Uncategorized';
      final matchesBank = selectedBank == 'All' || bank.contains(selectedBank);
      final matchesCategory = category == null || docCategory == category;
      return matchesBank && matchesCategory;
    }).toList();
  }

  /// Calculates income, expenses, and net from filtered transactions
  Map<String, double> calculateSummary(List<QueryDocumentSnapshot> docs) {
    double income = 0;
    double expenses = 0;

    for (var doc in docs) {
      final amount = (doc['amount'] ?? 0).toDouble();
      final type = doc['transactionType'];
      switch (type) {
        case 'Deposit':
        case 'Income':
          income += amount;
          break;
        case 'Withdrawal':
        case 'Expense':
        case 'Bill Payment':
        case 'Purchase':
        case 'Subscription':
          expenses += amount;
          break;
      }
    }

    return {'income': income, 'expenses': expenses, 'net': income - expenses};
  }

  /// Groups transactions by "Month Year" key for UI display
  Map<String, List<QueryDocumentSnapshot>> groupByMonth(
    List<QueryDocumentSnapshot> docs,
  ) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    for (var doc in docs) {
      final date = DateTime.tryParse(doc['date']) ?? DateTime.now();
      final key = DateFormat.yMMMM().format(date);
      grouped.putIfAbsent(key, () => []).add(doc);
    }
    return grouped;
  }

  /// Logic for processing and validating a transaction. Returns an error message or null on success.
  Future<String?> validateAndProcessTransaction({
    required String? transactionType,
    required String? accountType,
    required String amountText,
    required String dateText,
    required String comment,
    String? selectedBank,
    String? transferFromBank,
    String? transferToBank,
    String? budgetCategory,
  }) async {
    try {
      final amount = double.tryParse(amountText.trim());
      final date = DateTime.tryParse(dateText.trim());

      if (transactionType == null ||
          accountType == null ||
          amount == null ||
          date == null) {
        return "Please fill all required fields correctly.";
      }

      final deductionTypes = [
        'Withdrawal',
        'Purchase',
        'Expense',
        'Bill Payment',
        'Subscription',
      ];

      final isCredit = accountType.contains('Credit');

      if (transactionType == 'Transfer') {
        if (isCredit) return "Cannot transfer from a Credit account.";
        if (transferFromBank == null || transferToBank == null) {
          return "Please select both source and destination banks.";
        }
        final fromKey = '$transferFromBank - $accountType';
        final balances = await _firestoreService.calculateAccountBalances();
        final currentBalance = balances[fromKey] ?? 0;
        final transferId = _uuid.v4();
        if (!isCredit && currentBalance < amount) {
          return "Insufficient funds in $fromKey.";
        }
        // 1. Deduct from "from" bank
        await _firestoreService.addTransaction(
          transactionType: 'Transfer Out',
          accountType: accountType,
          bank: transferFromBank,
          amount: -amount,
          date: date,
          comment: 'Transferred to $transferToBank. $comment',
          transferId: transferId,
        );

        // 2. Add to "to" bank
        await _firestoreService.addTransaction(
          transactionType: 'Transfer In',
          accountType: accountType,
          bank: transferToBank,
          amount: amount,
          date: date,
          comment: 'Received from $transferFromBank. $comment',
          transferId: transferId,
        );
      } else {
        if (selectedBank == null) return "Please select a bank.";
        final key = '$selectedBank - $accountType';
        final balances = await _firestoreService.calculateAccountBalances();
        final currentBalance = balances[key] ?? 0;
        if (deductionTypes.contains(transactionType) &&
            !isCredit &&
            currentBalance < amount) {
          return "Insufficient funds in $key.";
        }
        await _firestoreService.addTransaction(
          transactionType: transactionType,
          accountType: accountType,
          bank: selectedBank,
          amount: amount,
          date: date,
          comment: comment.trim(),
          category: budgetCategory ?? 'Uncategorized',
        );
      }

      return null;
    } catch (e) {
      return "Error saving data: $e";
    }
  }

  void toggleHighlight(String? transferId) {
    if (highlightedTransferId.value == transferId) {
      highlightedTransferId.value = null;
    } else {
      highlightedTransferId.value = transferId;
    }
  }
}
