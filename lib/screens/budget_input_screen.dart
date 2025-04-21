import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/transaction_service.dart';

class BudgetInputScreen extends StatefulWidget {
  const BudgetInputScreen({super.key});

  @override
  State<BudgetInputScreen> createState() => _BudgetInputScreenState();
}

class _BudgetInputScreenState extends State<BudgetInputScreen> {
  String? transactionType;
  String? accountType;
  String? selectedBank;
  String? transferFromBank;
  String? transferToBank;
  String? budgetCategory;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController commentController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  final TransactionService _transactionService = TransactionService();

  List<String> budgetCategories = [];
  bool isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final now = DateTime.now();
    final budget = await _firestoreService.getSavedBudgetsByMonth(
      now.year,
      now.month,
    );
    setState(() {
      budgetCategories = budget.keys.toList();
      isLoadingCategories = false;
    });
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      dateController.text = picked.toIso8601String().split('T').first;
    }
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items:
          items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildTransferSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Transfer Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'From Bank',
          transferFromBank,
          ['BOA', 'Chase'],
          (val) => setState(() => transferFromBank = val),
        ),
        const SizedBox(height: 12),
        _buildDropdown('To Bank', transferToBank, [
          'BOA',
          'Chase',
        ], (val) => setState(() => transferToBank = val)),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: () async {
        final errorMessage = await _transactionService
            .validateAndProcessTransaction(
              transactionType: transactionType,
              accountType: accountType,
              amountText: amountController.text,
              dateText: dateController.text,
              comment: commentController.text,
              selectedBank: selectedBank,
              transferFromBank: transferFromBank,
              transferToBank: transferToBank,
              budgetCategory: budgetCategory,
            );

        if (errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Transaction saved successfully!")),
          );
          setState(() {
            transactionType = null;
            accountType = null;
            selectedBank = null;
            transferFromBank = null;
            transferToBank = null;
            budgetCategory = null;
            amountController.clear();
            dateController.clear();
            commentController.clear();
          });
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text(
        'Log Information',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[200],
        elevation: 0,
        title: const Text(
          'Log a Transaction',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDropdown(
                      'Transaction Type',
                      transactionType,
                      [
                        'Deposit',
                        'Withdrawal',
                        'Transfer',
                        'Bill Payment',
                        'Purchase',
                        'Subscription',
                        'Income',
                        'Expense',
                      ],
                      (val) => setState(() => transactionType = val),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      'Account Type',
                      accountType,
                      ['Checking', 'Savings', 'Credit'],
                      (val) => setState(() => accountType = val),
                    ),
                    const SizedBox(height: 16),
                    if (transactionType == 'Transfer')
                      _buildTransferSection()
                    else
                      _buildDropdown(
                        'Bank',
                        selectedBank,
                        ['BOA', 'Chase'],
                        (val) => setState(() => selectedBank = val),
                      ),
                    const SizedBox(height: 16),
                    if ([
                      'Withdrawal',
                      'Purchase',
                      'Subscription',
                      'Bill Payment',
                      'Expense',
                    ].contains(transactionType))
                      isLoadingCategories
                          ? const CircularProgressIndicator()
                          : _buildDropdown(
                            'Budget Category',
                            budgetCategory,
                            budgetCategories,
                            (val) => setState(() => budgetCategory = val),
                          ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Amount',
                      amountController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Date',
                      dateController,
                      readOnly: true,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Comments', commentController, maxLines: 3),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
