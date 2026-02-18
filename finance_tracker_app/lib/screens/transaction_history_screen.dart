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

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Transactions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
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
              Text('Error: $error', style: const TextStyle(color: Colors.white)),
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
                  Icon(Icons.receipt_long, size: 80, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions found',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18),
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
            backgroundColor: AppTheme.cardColor,
            title: const Text('Delete Transaction', style: TextStyle(color: Colors.white)),
            content: const Text('Are you sure you want to delete this transaction?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx.description.isNotEmpty ? tx.description : Formatters.formatDate(tx.date),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
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
                    const Text(
                      'Filter Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Type', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip('all', 'All', setModalState),
                    _buildFilterChip('income', 'Income', setModalState),
                    _buildFilterChip('expense', 'Expense', setModalState),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Category', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryChip(null, 'All', setModalState),
                    ...Constants.expenseCategories.map((c) => _buildCategoryChip(c, c, setModalState)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Date Range', style: TextStyle(color: Colors.white70)),
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
                colorScheme: const ColorScheme.dark(
                  primary: AppTheme.primaryColor,
                  onPrimary: Colors.white,
                  surface: AppTheme.cardColor,
                  onSurface: Colors.white,
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
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null ? AppTheme.primaryColor : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? Formatters.formatDate(date) : label,
                style: TextStyle(
                  color: date != null ? Colors.white : Colors.white54,
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
                child: const Icon(Icons.clear, size: 18, color: Colors.white54),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, StateSetter setModalState) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        setModalState(() => _filterType = value);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.white70),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String? value, String label, StateSetter setModalState) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () {
        setModalState(() => _selectedCategory = value);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}

