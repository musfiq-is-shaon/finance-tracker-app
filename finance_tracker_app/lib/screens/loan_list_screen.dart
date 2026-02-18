import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/loan_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/glass_card.dart';
import '../utils/formatters.dart';

class LoanListScreen extends ConsumerStatefulWidget {
  const LoanListScreen({super.key});

  @override
  ConsumerState<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends ConsumerState<LoanListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasLoadedData = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load loans after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (_hasLoadedData) return;
    _hasLoadedData = true;
    // Add a small delay to ensure auth is fully validated
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await ref.read(loansProvider.notifier).loadLoans();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Loans'),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Given'),
            Tab(text: 'Borrowed'),
          ],
        ),
      ),
      body: loansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error', style: const TextStyle(color: Colors.white)),
              ElevatedButton(
                onPressed: () => ref.read(loansProvider.notifier).loadLoans(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (loans) {
          // Apply date filters
          var filteredLoans = loans.where((l) {
            if (_startDate != null && l.date.isBefore(_startDate!)) return false;
            if (_endDate != null && l.date.isAfter(_endDate!)) return false;
            return true;
          }).toList();
          
          final givenLoans = filteredLoans.where((l) => l.type == 'given').toList();
          final borrowedLoans = filteredLoans.where((l) => l.type == 'borrowed').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLoanList(givenLoans, 'given'),
              _buildLoanList(borrowedLoans, 'borrowed'),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLoanOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoanList(List loans, String type) {
    if (loans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type == 'given' ? 'loans given' : 'loans borrowed'}',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/add-loan', extra: type),
              child: Text('Add ${type == 'given' ? 'Loan Given' : 'Loan Borrowed'}'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(loansProvider.notifier).loadLoans();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: loans.length,
        itemBuilder: (context, index) {
          return _buildLoanItem(loans[index]);
        },
      ),
    );
  }

  Widget _buildLoanItem(loan) {
    final isGiven = loan.type == 'given';
    final color = isGiven ? AppTheme.loanGivenColor : AppTheme.loanBorrowedColor;
    
    return Dismissible(
      key: Key(loan.id),
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
            title: const Text('Delete Loan', style: TextStyle(color: Colors.white)),
            content: const Text('Are you sure you want to delete this loan?', style: TextStyle(color: Colors.white70)),
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
        await ref.read(loansProvider.notifier).deleteLoan(loan.id);
        await ref.read(dashboardProvider.notifier).refresh();
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isGiven ? Icons.arrow_forward : Icons.arrow_back,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.personName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.formatDate(loan.date),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.formatCurrency(loan.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color,
                      ),
                    ),
                    if (loan.paidAmount != null && loan.paidAmount! > 0)
                      Text(
                        'Paid: ${Formatters.formatCurrency(loan.paidAmount!)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (!loan.isPaid) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Outstanding:',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                    Text(
                      Formatters.formatCurrency(loan.outstandingAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showPayDialog(context, loan),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: color),
                        foregroundColor: color,
                      ),
                      child: const Text('Mark as Paid'),
                    ),
                  ),
                ],
              ),
            ] else
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Paid',
                  style: TextStyle(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPayDialog(BuildContext context, loan) {
    final amountController = TextEditingController(text: loan.outstandingAmount.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Mark as Paid', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the amount paid:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                hintText: 'Amount',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                await ref.read(loansProvider.notifier).markAsPaid(loan.id, amount);
                await ref.read(dashboardProvider.notifier).refresh();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showAddLoanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.loanGivenColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_forward, color: AppTheme.loanGivenColor),
              ),
              title: const Text('Loan Given', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Money you lent to someone', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                context.push('/add-loan', extra: 'given');
              },
            ),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.loanBorrowedColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, color: AppTheme.loanBorrowedColor),
              ),
              title: const Text('Loan Borrowed', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Money you owe to someone', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                context.push('/add-loan', extra: 'borrowed');
              },
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
                      'Filter Loans',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
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
}

