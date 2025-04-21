import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/budget_service.dart';
import '../utils/dialog_helper.dart';

// A screen for creating a budget.
// It allows users to set a budget limit, add standard and custom categories,
// and save the budget for a specific month.
// The screen also provides a summary of the total budget and remaining amount.
class CreateBudgetScreen extends StatefulWidget {
  const CreateBudgetScreen({super.key});

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  final BudgetService _budgetService = BudgetService();
  final List<String> _standardCategories = [
    "Food",
    "Rent",
    "Utilities",
    "Transportation",
    "Healthcare",
    "Entertainment",
    "Savings",
  ];
  final List<TextEditingController> _customControllers = [];
  final List<TextEditingController> _amountControllers = [];
  double _totalBudget = 0.0;
  double _budgetLimit = 2000.0;
  bool _saving = false;
  late String targetMonth;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _standardCategories.length; i++) {
      final controller = TextEditingController();
      controller.addListener(_recalculateTotal);
      _amountControllers.add(controller);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      targetMonth = args;
    } else {
      final now = DateTime.now();
      targetMonth = DateFormat('yyyy-MM').format(now);
    }
  }

  // Recalculates the total budget based on the current values in the amount controllers.
  void _recalculateTotal() {
    final total = _budgetService.calculateCurrentTotal(
      amountControllers: _amountControllers,
    );
    setState(() {
      _totalBudget = total;
    });
  }

  // Shows a dialog to add a custom category.
  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController(text: "0");
    double sliderValue = 0;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Add Custom Category"),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Category Name",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Amount"),
                      onChanged: (val) {
                        final parsed = double.tryParse(val) ?? 0;
                        setDialogState(
                          () => sliderValue = parsed.clamp(0, 2000),
                        );
                      },
                    ),
                    Slider(
                      value: sliderValue,
                      min: 0,
                      max: 2000,
                      divisions: 200,
                      label: '\$${sliderValue.toStringAsFixed(0)}',
                      onChanged: (newValue) {
                        setDialogState(() {
                          sliderValue = newValue;
                          amountController.text = newValue.toStringAsFixed(0);
                        });
                      },
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  final error = _budgetService.validateCustomNameConflict(
                    input: nameController.text,
                    standardCategories: _standardCategories,
                    existingCustomControllers: _customControllers,
                  );
                  if (error != null) {
                    DialogHelper.showError(context, error);
                    return;
                  }

                  final name = nameController.text.trim();
                  final amount =
                      double.tryParse(amountController.text.trim()) ?? 0.0;

                  if (amount <= 0) {
                    DialogHelper.showError(
                      context,
                      "Please enter a valid amount.",
                    );
                    return;
                  }

                  final nameCtrl = TextEditingController(text: name);
                  final amountCtrl = TextEditingController(
                    text: amount.toStringAsFixed(0),
                  )..addListener(_recalculateTotal);

                  setState(() {
                    _customControllers.add(nameCtrl);
                    _amountControllers.add(amountCtrl);
                  });

                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  // Removes a custom category at the specified index.
  void _removeCustomCategory(int index) {
    setState(() {
      _customControllers.removeAt(index);
      _amountControllers.removeAt(_standardCategories.length + index);
    });
    _recalculateTotal();
  }

  // Saves the budget after validating the inputs.
  void _saveBudget() async {
    setState(() => _saving = true);

    final exists = await _budgetService.checkIfBudgetExists(targetMonth);
    if (exists) {
      DialogHelper.showError(
        context,
        "A budget already exists for $targetMonth. Please delete it before creating a new one.",
      );
      setState(() => _saving = false);
      return;
    }

    final error = await _budgetService.validateAndSaveBudget(
      standardCategories: _standardCategories,
      customControllers: _customControllers,
      amountControllers: _amountControllers,
      userDefinedCap: _budgetLimit,
      targetMonth: targetMonth,
    );

    setState(() => _saving = false);

    if (error != null) {
      DialogHelper.showError(context, error);
      return;
    }

    DialogHelper.showSuccess(context, "Budget created for $targetMonth!");

    Navigator.pop(context, targetMonth);
  }

  // Builds a budget input field with a slider for adjusting the amount.
  Widget _buildBudgetInputWithSlider(
    String label,
    TextEditingController controller,
  ) {
    double value = double.tryParse(controller.text) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        Slider(
          value: value.clamp(0, 2000),
          min: 0,
          max: 2000,
          divisions: 200,
          label: '\$${value.toStringAsFixed(0)}',
          onChanged: (newValue) {
            controller.text = newValue.toStringAsFixed(0);
          },
        ),
      ],
    );
  }

  // Builds a sticky footer summary showing the total budget and remaining amount.
  Widget _buildStickyFooterSummary() {
    final remaining = _budgetLimit - _totalBudget;
    final color =
        remaining >= 100
            ? Colors.green
            : (remaining >= 0 ? Colors.orange : Colors.red);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Total Budget: \$${_totalBudget.toStringAsFixed(2)} / \$${_budgetLimit.toStringAsFixed(0)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "Remaining: \$${remaining.toStringAsFixed(2)}",
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // Builds the main UI of the screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      appBar: AppBar(
        backgroundColor: Colors.lightBlue[200],
        elevation: 0,
        title: const Text("Create Budget"),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 120),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        "Set Budget Limit: ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _budgetLimit.toStringAsFixed(0),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "e.g. 2000",
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(val);
                            setState(() {
                              _budgetLimit = parsed ?? 0;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _standardCategories.length; i++)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _standardCategories[i],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _buildBudgetInputWithSlider(
                          "Amount",
                          _amountControllers[i],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  for (var i = 0; i < _customControllers.length; i++)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _customControllers[i],
                                decoration: const InputDecoration(
                                  labelText: "Custom Category Name",
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _removeCustomCategory(i),
                              icon: const Icon(Icons.close, color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildBudgetInputWithSlider(
                          "Amount",
                          _amountControllers[_standardCategories.length + i],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ElevatedButton(
                    onPressed:
                        _customControllers.length >= 3
                            ? null
                            : _showAddCategoryDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFE6FB),
                      foregroundColor: const Color(0xFF6A4AB1),
                      disabledBackgroundColor: const Color(0xFFE5E5E5),
                      disabledForegroundColor: const Color(0xFF9E9E9E),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text("+ Add Custom Category"),
                  ),
                  const SizedBox(height: 80),
                  _saving
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                        onPressed: _saveBudget,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text("Save Budget"),
                      ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyFooterSummary(),
          ),
        ],
      ),
    );
  }
}
