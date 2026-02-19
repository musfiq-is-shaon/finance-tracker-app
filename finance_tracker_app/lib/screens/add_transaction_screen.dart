import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/glass_card.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String? transactionType;

  const AddTransactionScreen({super.key, this.transactionType});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  late String _type;
  String _selectedCategory = '';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _type = widget.transactionType ?? 'expense';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Get categories based on transaction type
    final categories = _type == 'income' 
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);
    
    // Set default category if not set
    if (_selectedCategory.isEmpty && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }

    // Watch the balance provider
    final balanceAsync = ref.watch(balanceProvider);

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Add ${_type == 'income' ? 'Income' : 'Expense'}',
          style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Balance Display
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Balance',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                          ),
                        ),
                        balanceAsync.when(
                          data: (balance) {
                            _currentBalance = balance;
                            return Text(
                              '৳${balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                              ),
                            );
                          },
                          loading: () => const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                          ),
                          error: (_, __) => Text(
                            '৳${_currentBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Type',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeButton('income', 'Income', AppTheme.incomeColor, isDarkMode),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTypeButton('expense', 'Expense', AppTheme.expenseColor, isDarkMode),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                      ),
                      decoration: InputDecoration(
                        prefixText: '৳ ',
                        prefixStyle: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _type == 'income' ? AppTheme.incomeColor : AppTheme.expenseColor,
                        ),
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                        ),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        if (_type == 'expense' && amount > _currentBalance) {
                          return 'Insufficient balance';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                          ),
                        ),
                        // Add new category button
                        GestureDetector(
                          onTap: () => _showAddCategoryDialog(context, isDarkMode),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
                                SizedBox(width: 4),
                                Text(
                                  'Add New',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        final isSelected = category == _selectedCategory;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = category),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? AppTheme.primaryColor 
                                  : (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected 
                                    ? AppTheme.primaryColor 
                                    : (isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.2)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                // Show delete icon for custom categories
                                if (_type == 'income' 
                                    ? ref.read(incomeCategoriesProvider.notifier).isCustomCategory(category)
                                    : ref.read(expenseCategoriesProvider.notifier).isCustomCategory(category))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: GestureDetector(
                                      onTap: () => _deleteCategory(category, isDarkMode),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: isSelected ? Colors.white : Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      ),
                      title: Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: isDarkMode ? Colors.white54 : Colors.grey),
                      onTap: () => _selectDate(isDarkMode),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                      decoration: InputDecoration(
                        hintText: 'Add a note...',
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'income' ? AppTheme.incomeColor : AppTheme.expenseColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save ${_type == 'income' ? 'Income' : 'Expense'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, Color color, bool isDarkMode) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = type;
          _selectedCategory = '';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.3)),
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isDarkMode) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showAddCategoryDialog(BuildContext context, bool isDarkMode) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
        title: Text(
          'Add New Category',
          style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
          decoration: InputDecoration(
            hintText: 'Category name',
            hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                if (_type == 'income') {
                  ref.read(incomeCategoriesProvider.notifier).addCategory(name);
                } else {
                  ref.read(expenseCategoriesProvider.notifier).addCategory(name);
                }
                setState(() => _selectedCategory = name);
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(String category, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
        title: Text(
          'Delete Category',
          style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
        ),
        content: Text(
          'Are you sure you want to delete "$category"?',
          style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_type == 'income') {
                ref.read(incomeCategoriesProvider.notifier).removeCategory(category);
              } else {
                ref.read(expenseCategoriesProvider.notifier).removeCategory(category);
              }
              if (_selectedCategory == category) {
                setState(() => _selectedCategory = '');
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    // Check balance for expenses
    if (_type == 'expense') {
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount > _currentBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient balance! You have ৳${_currentBalance.toStringAsFixed(2)}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(transactionsProvider.notifier).addTransaction(
        type: _type,
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        description: _descriptionController.text,
        date: _selectedDate,
      );
      
      ref.invalidate(dashboardProvider);
      await ref.read(dashboardProvider.notifier).refresh();
      ref.invalidate(balanceProvider);
      ref.invalidate(transactionsProvider);
      await ref.read(transactionsProvider.notifier).loadTransactions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction added successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error: $e';
        if (e.toString().contains('Insufficient balance')) {
          errorMessage = 'Insufficient balance! You have ৳${_currentBalance.toStringAsFixed(2)}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

