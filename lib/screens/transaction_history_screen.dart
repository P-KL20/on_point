import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/dialog_helper.dart';
import '../services/firestore_service.dart';
import '../services/transaction_service.dart';
import '../services/budget_service.dart';

/// A screen that displays the transaction history and allows filtering by bank.
/// It also shows a summary of income, expenses, and net balance.
/// The screen can be accessed with an optional category filter.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TransactionService _transactionService = TransactionService();
  final BudgetService _budgetService = BudgetService();
  final ValueNotifier<String> selectedBankNotifier = ValueNotifier<String>(
    'All',
  );

  String? filterCategory;
  bool _initializedCategory = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedCategory) {
      _initializedCategory = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('category')) {
        Future.microtask(() {
          if (mounted) {
            setState(() {
              filterCategory = args['category'];
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.lightBlue[100],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.lightBlue[200],
          elevation: 0,
          title: Text(
            filterCategory != null
                ? '$filterCategory Transactions'
                : 'Transaction History',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
        body: Column(
          children: [
            if (filterCategory == null) _buildStickyFilterBar(),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: selectedBankNotifier,
                builder: (context, selectedBank, _) {
                  return _buildTransactionList(selectedBank);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a sticky filter bar for filtering transactions by bank.
  Widget _buildStickyFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: DropdownButtonHideUnderline(
          child: DropdownButtonFormField<String>(
            value: selectedBankNotifier.value,
            decoration: const InputDecoration(
              labelText: 'Filter by Bank',
              border: InputBorder.none,
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            isExpanded: true,
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            items:
                ['All', 'BOA', 'Chase'].map((bank) {
                  return DropdownMenuItem<String>(
                    value: bank,
                    child: Text(bank),
                  );
                }).toList(),
            onChanged: (val) {
              if (val != null) selectedBankNotifier.value = val;
            },
          ),
        ),
      ),
    );
  }

  /// Builds the transaction list based on the selected bank and category.
  Widget _buildTransactionList(String selectedBank) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading transactions'));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final filtered = _transactionService.filterTransactions(
          allDocs,
          selectedBank: selectedBank,
          category: filterCategory,
        );
        final summary = _transactionService.calculateSummary(filtered);
        final grouped = _transactionService.groupByMonth(filtered);

        return FutureBuilder<double>(
          future:
              filterCategory != null
                  ? _budgetService.getCategoryBudget(filterCategory!)
                  : Future.value(0.0),
          builder: (context, budgetSnap) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (filterCategory == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _summaryCard(
                      summary['income']!,
                      summary['expenses']!,
                      summary['net']!,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _budgetSummaryCard(
                      category: filterCategory!,
                      spent: summary['expenses']!,
                      budgetLimit: budgetSnap.data ?? 0,
                    ),
                  ),
                for (var entry in grouped.entries)
                  Card(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<String?>(
                            valueListenable:
                                _transactionService.highlightedTransferId,
                            builder: (context, highlightedId, _) {
                              return Column(
                                children:
                                    entry.value
                                        .map(
                                          (doc) => _transactionCard(
                                            doc.data() as Map<String, dynamic>,
                                            doc.id,
                                            highlightedId,
                                            _transactionService.toggleHighlight,
                                          ),
                                        )
                                        .toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds the summary card for income, expenses, and net balance.
  Widget _summaryCard(double income, double expenses, double net) =>
      _cardWrapper(
        title: '💰 Financial Summary',
        children: [
          _buildRow('🟢 Total Income:', '\$${income.toStringAsFixed(2)}'),
          _buildRow('🔴 Total Expenses:', '\$${expenses.toStringAsFixed(2)}'),
          _buildRow('⚫ Net Balance:', '\$${net.toStringAsFixed(2)}'),
        ],
      );

  /// Builds the budget summary card for a specific category.
  Widget _budgetSummaryCard({
    required String category,
    required double spent,
    required double budgetLimit,
  }) {
    final left = (budgetLimit - spent).clamp(0, double.infinity);
    return _cardWrapper(
      title: '📊 $category Budget Summary',
      children: [
        _buildRow('🎯 Set Budget:', '\$${budgetLimit.toStringAsFixed(2)}'),
        _buildRow('💸 Used Budget:', '\$${spent.toStringAsFixed(2)}'),
        _buildRow('🟢 Left:', '\$${left.toStringAsFixed(2)}'),
      ],
    );
  }

  /// A helper method to create a card wrapper with a title and children.
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  /// A helper method to create a row with two text widgets.
  Widget _buildRow(
    String left,
    String right, {
    bool isExpense = false,
    bool isIncome = false,
  }) {
    Color? amountColor;
    if (isExpense) amountColor = Colors.red[700];
    if (isIncome) amountColor = Colors.green[700];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            left,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (right.isNotEmpty)
          Text(
            right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: amountColor,
            ),
          ),
      ],
    );
  }

  /// Builds a transaction card with details and action buttons.
  Widget _transactionCard(
    Map<String, dynamic> data,
    String docId,
    String? highlightedId,
    void Function(String? transferId) onTapTransfer,
  ) {
    final isHighlighted =
        data['transferId'] != null && data['transferId'] == highlightedId;
    final isExpense = [
      'Withdrawal',
      'Expense',
      'Purchase',
      'Bill Payment',
      'Subscription',
      'Transfer Out',
    ].contains(data['transactionType']);
    final isIncome = [
      'Income',
      'Deposit',
      'Transfer In',
    ].contains(data['transactionType']);
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: GestureDetector(
        onTap: () {
          final transferId = data['transferId'];
          if (transferId != null) {
            onTapTransfer(transferId);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isHighlighted ? Colors.yellow[100] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRow(
                '💸 ${data['transactionType']}',
                '\$${data['amount']}',
                isExpense: isExpense,
                isIncome: isIncome,
              ),
              const SizedBox(height: 4),
              _buildRow('🏦 ${data['bank']} - ${data['accountType']}', ''),
              const SizedBox(height: 4),
              _buildRow('🗓️ ${data['date'].split("T")[0]}', ''),
              if (data['transferId'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: const [
                      Icon(Icons.link, size: 16, color: Colors.blueGrey),
                      SizedBox(width: 4),
                      Text(
                        'Linked Transfer',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              if ((data['comment'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '📝 ${data['comment']}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        () => _showDeleteDialog(docId, data['transferId']),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showEditDialog(data, docId),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a confirmation dialog for deleting a transaction.
  void _showDeleteDialog(String docId, String? transferId) {
    DialogHelper.showConfirmation(
      context: context,
      title: 'Delete Transaction',
      message:
          transferId != null
              ? 'This is part of a linked transfer. Delete both transactions?'
              : 'Are you sure you want to delete this transaction?',
      confirmText: 'Delete',
      onConfirmed: () async {
        if (transferId != null) {
          // 🔁 Delete both
          final snapshot =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .collection('transactions')
                  .where('transferId', isEqualTo: transferId)
                  .get();

          for (var doc in snapshot.docs) {
            await _firestoreService.deleteTransaction(doc.id);
          }
        } else {
          await _firestoreService.deleteTransaction(docId);
        }
      },
    );
  }

  /// Shows a dialog for editing a transaction's comment.
  void _showEditDialog(Map<String, dynamic> data, String docId) {
    DialogHelper.showEditComment(
      context: context,
      initialComment: data['comment'] ?? '',
      onSave: (newComment) async {
        await _firestoreService.updateTransaction(docId, {
          'comment': newComment,
        });
      },
    );
  }
}
