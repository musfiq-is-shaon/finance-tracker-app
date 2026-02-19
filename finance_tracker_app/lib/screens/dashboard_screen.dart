import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../utils/formatters.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  bool _hasLoadedData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (_hasLoadedData) return;
    _hasLoadedData = true;
    
    if (mounted) {
      await ref.read(dashboardProvider.notifier).loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $error', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
                ElevatedButton(
                  onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (dashboard) => RefreshIndicator(
            onRefresh: () async {
              await ref.read(dashboardProvider.notifier).refresh();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDarkMode),
                  const SizedBox(height: 24),
                  _buildBalanceCard(dashboard, isDarkMode),
                  const SizedBox(height: 24),
                  _buildQuickActions(isDarkMode),
                  const SizedBox(height: 24),
                  _buildStatsRow(dashboard, isDarkMode),
                  const SizedBox(height: 24),
                  _buildMonthlyChart(dashboard, isDarkMode),
                  const SizedBox(height: 24),
                  _buildRecentTransactions(dashboard, isDarkMode),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context, isDarkMode),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 0:
              break;
            case 1:
              context.push('/transactions');
              break;
            case 2:
              context.push('/loan-contacts');
              break;
            case 3:
              context.push('/analytics');
              break;
            case 4:
              context.push('/profile');
              break;
          }
        },
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: isDarkMode ? Colors.grey : Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Loans'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    final userName = AuthService.getCurrentUserName();
    final displayName = userName?.isNotEmpty == true ? userName! : 'User';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $displayName!',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white.withOpacity(0.7) : AppTheme.lightSubTextColor,
              ),
            ),
            Text(
              'Finance Tracker',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
              icon: Icon(
                isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => context.push('/ai-assistant'),
              icon: Icon(Icons.smart_toy, color: isDarkMode ? AppTheme.secondaryColor : AppTheme.primaryColor),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard(DashboardData dashboard, bool isDarkMode) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Balance',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.formatCurrency(dashboard.totalBalance),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildBalanceItem('Income', dashboard.totalIncome, AppTheme.incomeColor, Icons.arrow_downward, isDarkMode),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBalanceItem('Expense', dashboard.totalExpenses, AppTheme.expenseColor, Icons.arrow_upward, isDarkMode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, double amount, Color color, IconData icon, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Formatters.formatCurrency(amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton('Add Income', AppTheme.incomeColor, Icons.add_circle, () => context.push('/add-transaction', extra: 'income'), isDarkMode),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton('Add Expense', AppTheme.expenseColor, Icons.remove_circle, () => context.push('/add-transaction', extra: 'expense'), isDarkMode),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton('Add Loan', AppTheme.primaryColor, Icons.account_balance, () => context.push('/add-loan', extra: 'given'), isDarkMode),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, IconData icon, VoidCallback onTap, bool isDarkMode) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(DashboardData dashboard, bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_forward, color: AppTheme.loanGivenColor),
                const SizedBox(height: 8),
                Text('Loan Given', style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(Formatters.formatCurrency(dashboard.loanGiven), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_back, color: AppTheme.loanBorrowedColor),
                const SizedBox(height: 8),
                Text('Loan Borrowed', style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(Formatters.formatCurrency(dashboard.loanBorrowed), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyChart(DashboardData dashboard, bool isDarkMode) {
    final monthlyData = dashboard.monthlyData;
    if (monthlyData.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text('No data available', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor))),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxValue(monthlyData) * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < monthlyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(monthlyData[value.toInt()].month.substring(5), style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor, fontSize: 10)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: monthlyData.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(toY: entry.value.expense, color: AppTheme.expenseColor, width: 12, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                      BarChartRodData(toY: entry.value.income, color: AppTheme.incomeColor, width: 12, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Income', AppTheme.incomeColor, isDarkMode),
                const SizedBox(width: 24),
                _buildLegendItem('Expense', AppTheme.expenseColor, isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxValue(List<MonthlyData> monthlyData) {
    double max = 0;
    for (var data in monthlyData) {
      if (data.income > max) max = data.income;
      if (data.expense > max) max = data.expense;
    }
    return max > 0 ? max : 100;
  }

  Widget _buildLegendItem(String label, Color color, bool isDarkMode) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor, fontSize: 12)),
      ],
    );
  }

  Widget _buildRecentTransactions(DashboardData dashboard, bool isDarkMode) {
    final recentTx = dashboard.recentTransactions;
    
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
              TextButton(
                onPressed: () => context.push('/transactions'),
                child: const Text('See All', style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ],
          ),
          if (recentTx.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No transactions yet', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor))),
            )
          else
            ...recentTx.take(5).map((tx) => _buildTransactionItem(tx, isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, bool isDarkMode) {
    final isIncome = tx['type'] == 'income';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isIncome ? AppTheme.incomeColor : AppTheme.expenseColor).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['category'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : AppTheme.lightTextColor), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(tx['description'] ?? '', style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor), overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text('${isIncome ? '+' : '-'}${Formatters.formatCurrency((tx['amount'] as num).toDouble())}', style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddOptions(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Add New', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
            const SizedBox(height: 24),
            _buildOptionTile('Income', 'Add money received', AppTheme.incomeColor, Icons.arrow_downward, () { Navigator.pop(context); context.push('/add-transaction', extra: 'income'); }, isDarkMode),
            _buildOptionTile('Expense', 'Add money spent', AppTheme.expenseColor, Icons.arrow_upward, () { Navigator.pop(context); context.push('/add-transaction', extra: 'expense'); }, isDarkMode),
            _buildOptionTile('Loan Given', 'Money you lent', AppTheme.loanGivenColor, Icons.arrow_forward, () { Navigator.pop(context); context.push('/add-loan', extra: 'given'); }, isDarkMode),
            _buildOptionTile('Loan Borrowed', 'Money you owe', AppTheme.loanBorrowedColor, Icons.arrow_back, () { Navigator.pop(context); context.push('/add-loan', extra: 'borrowed'); }, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(String title, String subtitle, Color color, IconData icon, VoidCallback onTap, bool isDarkMode) {
    return ListTile(
      onTap: onTap,
      leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
      title: Text(title, style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor)),
      trailing: Icon(Icons.chevron_right, color: isDarkMode ? Colors.white54 : Colors.grey),
    );
  }
}

