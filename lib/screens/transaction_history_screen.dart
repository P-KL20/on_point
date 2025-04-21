import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/dialog_helper.dart';
import '../services/firestore_service.dart';
import '../services/transaction_service.dart';
import '../services/budget_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
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
                          ...entry.value
                              .map(
                                (doc) => _transactionCard(
                                  doc.data() as Map<String, dynamic>,
                                  doc.id,
                                ),
                              )
                              .toList(),
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

  Widget _summaryCard(double income, double expenses, double net) =>
      _cardWrapper(
        title: '💰 Financial Summary',
        children: [
          _buildRow('🟢 Total Income:', '\$${income.toStringAsFixed(2)}'),
          _buildRow('🔴 Total Expenses:', '\$${expenses.toStringAsFixed(2)}'),
          _buildRow('⚫ Net Balance:', '\$${net.toStringAsFixed(2)}'),
        ],
      );

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

  Widget _buildRow(String left, String right) => Row(
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
    ],
  );

  Widget _transactionCard(Map<String, dynamic> data, String docId) => Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow('💸 ${data['transactionType']}', '\$${data['amount']}'),
          const SizedBox(height: 4),
          _buildRow('🏦 ${data['bank']} - ${data['accountType']}', ''),
          const SizedBox(height: 4),
          _buildRow('🗓️ ${data['date'].split("T")[0]}', ''),
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
                onPressed: () => _showDeleteDialog(docId),
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
  );

  void _showDeleteDialog(String docId) {
    DialogHelper.showConfirmation(
      context: context,
      title: 'Delete Transaction',
      message: 'Are you sure you want to delete this transaction?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      onConfirmed: () async {
        await _firestoreService.deleteTransaction(docId);
      },
    );
  }

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
