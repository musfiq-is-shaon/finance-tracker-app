import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/transaction_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/glass_card.dart';
import '../utils/formatters.dart';
import '../utils/constants.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    // Load transactions after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionsProvider.notifier).loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        title: Text('Transactions', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
              ElevatedButton(
                onPressed: () => ref.read(transactionsProvider.notifier).loadTransactions(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (transactions) {
          var filtered = transactions.where((t) {
            if (_filterType != 'all' && t.type != _filterType) return false;
            if (_selectedCategory != null && t.category != _selectedCategory) return false;
            if (_startDate != null && t.date.isBefore(_startDate!)) return false;
            if (_endDate != null && t.date.isAfter(_endDate!)) return false;
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions found',
                    style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.7) : AppTheme.lightSubTextColor, fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.push('/add-transaction'),
                    child: const Text('Add Transaction'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(transactionsProvider.notifier).loadTransactions();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final tx = filtered[index];
                return _buildTransactionItem(tx);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-transaction'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTransactionItem(tx) {
    final isIncome = tx.type == 'income';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.errorColor,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
            title: Text('Delete Transaction', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
            content: Text('Are you sure you want to delete this transaction?', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await ref.read(transactionsProvider.notifier).deleteTransaction(tx.id);
        await ref.read(dashboardProvider.notifier).refresh();
        ref.invalidate(balanceProvider);
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: (isIncome ? AppTheme.incomeColor : AppTheme.expenseColor).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.category,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (tx.description.isNotEmpty) ...[
                    Text(
                      tx.description,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white.withOpacity(0.7) : AppTheme.lightSubTextColor,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    Formatters.formatDate(tx.date),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white.withOpacity(0.5) : AppTheme.lightSubTextColor,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${isIncome ? '+' : '-'}${Formatters.formatCurrency(tx.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _filterType = 'all';
                          _selectedCategory = null;
                          _startDate = null;
                          _endDate = null;
                        });
                        setState(() {});
                        Navigator.pop(context);
                      },
                      child: Text('Clear', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Type', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip('all', 'All', setModalState, isDarkMode),
                    _buildFilterChip('income', 'Income', setModalState, isDarkMode),
                    _buildFilterChip('expense', 'Expense', setModalState, isDarkMode),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Category', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryChip(null, 'All', setModalState, isDarkMode),
                    ...Constants.expenseCategories.map((c) => _buildCategoryChip(c, c, setModalState, isDarkMode)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Date Range', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateButton(
                        context,
                        'Start Date',
                        _startDate,
                        (date) {
                          setModalState(() => _startDate = date);
                          setState(() {});
                        },
                        setModalState,
                        isDarkMode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateButton(
                        context,
                        'End Date',
                        _endDate,
                        (date) {
                          setModalState(() => _endDate = date);
                          setState(() {});
                        },
                        setModalState,
                        isDarkMode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: const Text('Apply Filter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton(
    BuildContext context,
    String label,
    DateTime? date,
    Function(DateTime?) onChanged,
    StateSetter setModalState,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDarkMode
                    ? const ColorScheme.dark(
                        primary: AppTheme.primaryColor,
                        onPrimary: Colors.white,
                        surface: AppTheme.darkCardColor,
                        onSurface: Colors.white,
                      )
                    : const ColorScheme.light(
                        primary: AppTheme.primaryColor,
                        onPrimary: Colors.white,
                        surface: AppTheme.lightCardColor,
                        onSurface: AppTheme.lightTextColor,
                      ),
              ),
              child: child!,
            );
          },
        );
        if (selectedDate != null) {
          onChanged(selectedDate);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null ? AppTheme.primaryColor : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? Formatters.formatDate(date) : label,
                style: TextStyle(
                  color: date != null ? (isDarkMode ? Colors.white : AppTheme.lightTextColor) : (isDarkMode ? Colors.white54 : Colors.grey),
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: () {
                  onChanged(null);
                  setModalState(() {});
                  setState(() {});
                },
                child: Icon(Icons.clear, size: 18, color: isDarkMode ? Colors.white54 : Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, StateSetter setModalState, bool isDarkMode) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        setModalState(() => _filterType = value);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor)),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String? value, String label, StateSetter setModalState, bool isDarkMode) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () {
        setModalState(() => _selectedCategory = value);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor), fontSize: 12),
        ),
      ),
    );
  }
}

