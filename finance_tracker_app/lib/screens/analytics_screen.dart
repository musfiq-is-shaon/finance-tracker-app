import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/glass_card.dart';
import '../utils/formatters.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _touchedPieIndex = -1;

  // Pre-computed data for charts
  List<PieChartSectionData>? _expensePieSections;
  List<PieChartSectionData>? _incomePieSections;
  List<Map<String, dynamic>>? _expenseCategoryData;
  List<Map<String, dynamic>>? _incomeCategoryData;
  List<LineChartBarData>? _lineChartBars;
  List<LineChartBarData>? _loanLineChartBars;
  double _maxY = 0;
  double _loanMaxY = 0;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dashboardAsync = ref.watch(dashboardProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        title: Text('Analytics', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
          ),
        ],
      ),
      body: dashboardAsync.when(
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
        data: (dashboard) {
          _computeLineChartData(dashboard.monthlyData);
          _computeLoanLineChartData(dashboard.monthlyData);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalBalanceCard(dashboard, isDarkMode),
                const SizedBox(height: 20),
                _buildSummaryCards(dashboard, isDarkMode),
                const SizedBox(height: 24),
                _buildStatisticsSection(dashboard, isDarkMode),
                const SizedBox(height: 24),
                _buildIncomeExpenseChart(dashboard, isDarkMode),
                const SizedBox(height: 24),
                _buildLoanChart(dashboard, isDarkMode),
                const SizedBox(height: 24),
                transactionsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (transactions) {
                    _computeExpensePieChartData(dashboard.expenseByCategory);
                    _computeIncomePieChartData(dashboard.incomeByCategory);
                    return Column(
                      children: [
                        _buildExpensePieChart(isDarkMode),
                        const SizedBox(height: 24),
                        _buildIncomePieChart(isDarkMode),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalBalanceCard(dashboard, bool isDarkMode) {
    final isPositive = dashboard.totalBalance >= 0;
    
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Total Balance',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPositive ? Icons.account_balance_wallet : Icons.warning_amber,
                color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.formatCurrency(dashboard.totalBalance),
                style: TextStyle(
                  color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPositive ? 'You are doing great!' : 'Your balance is negative',
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : AppTheme.lightSubTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _computeLineChartData(List monthlyData) {
    if (monthlyData.isEmpty) {
      _lineChartBars = null;
      _maxY = 0;
      return;
    }

    final maxValue = monthlyData.fold<double>(0, (max, data) {
      final dataMax = data.income > data.expense ? data.income : data.expense;
      return dataMax > max ? dataMax : max;
    });
    
    _maxY = maxValue > 0 ? maxValue * 1.2 : 100;
    
    _lineChartBars = [
      LineChartBarData(
        spots: monthlyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.income)).toList(),
        isCurved: true,
        color: AppTheme.incomeColor,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: AppTheme.incomeColor.withOpacity(0.1)),
      ),
      LineChartBarData(
        spots: monthlyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.expense)).toList(),
        isCurved: true,
        color: AppTheme.expenseColor,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: AppTheme.expenseColor.withOpacity(0.1)),
      ),
    ];
  }

  void _computeLoanLineChartData(List monthlyData) {
    if (monthlyData.isEmpty) {
      _loanLineChartBars = null;
      _loanMaxY = 0;
      return;
    }

    final maxValue = monthlyData.fold<double>(0, (max, data) {
      final dataMax = data.loanGiven > data.loanBorrowed ? data.loanGiven : data.loanBorrowed;
      return dataMax > max ? dataMax : max;
    });
    
    _loanMaxY = maxValue > 0 ? maxValue * 1.2 : 100;
    
    _loanLineChartBars = [
      LineChartBarData(
        spots: monthlyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.loanGiven)).toList(),
        isCurved: true,
        color: AppTheme.loanGivenColor,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: AppTheme.loanGivenColor.withOpacity(0.1)),
      ),
      LineChartBarData(
        spots: monthlyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.loanBorrowed)).toList(),
        isCurved: true,
        color: AppTheme.loanBorrowedColor,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: AppTheme.loanBorrowedColor.withOpacity(0.1)),
      ),
    ];
  }

  void _computeExpensePieChartData(Map<String, double> expenseByCategory) {
    if (expenseByCategory.isEmpty) {
      _expensePieSections = null;
      _expenseCategoryData = null;
      return;
    }

    final total = expenseByCategory.values.fold(0.0, (a, b) => a + b);
    final sortedCategories = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      AppTheme.primaryColor,
      AppTheme.expenseColor,
      AppTheme.warningColor,
      AppTheme.secondaryColor,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.cyan,
    ];

    _expensePieSections = sortedCategories.asMap().entries.map((entry) {
      final index = entry.key;
      final amount = entry.value.value;
      final percentage = (amount / total * 100);
      final isTouched = index == _touchedPieIndex;
      final radius = isTouched ? 60.0 : 50.0;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: amount,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    _expenseCategoryData = sortedCategories.asMap().entries.map((entry) {
      final index = entry.key;
      return {
        'category': entry.value.key,
        'amount': entry.value.value,
        'color': colors[index % colors.length],
      };
    }).toList();
  }

  void _computeIncomePieChartData(Map<String, double> incomeByCategory) {
    if (incomeByCategory.isEmpty) {
      _incomePieSections = null;
      _incomeCategoryData = null;
      return;
    }

    final total = incomeByCategory.values.fold(0.0, (a, b) => a + b);
    final sortedCategories = incomeByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      AppTheme.successColor,
      AppTheme.incomeColor,
      Colors.green,
      Colors.lightGreen,
      Colors.teal,
      Colors.cyan,
      Colors.blue,
    ];

    _incomePieSections = sortedCategories.asMap().entries.map((entry) {
      final index = entry.key;
      final amount = entry.value.value;
      final percentage = (amount / total * 100);
      final isTouched = index == _touchedPieIndex;
      final radius = isTouched ? 60.0 : 50.0;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: amount,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    _incomeCategoryData = sortedCategories.asMap().entries.map((entry) {
      final index = entry.key;
      return {
        'category': entry.value.key,
        'amount': entry.value.value,
        'color': colors[index % colors.length],
      };
    }).toList();
  }

  Widget _buildSummaryCards(dashboard, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildIncomeCard(dashboard.totalIncome, dashboard.totalIncomeCount, dashboard.avgIncome, isDarkMode)),
            const SizedBox(width: 12),
            Expanded(child: _buildExpenseCard(dashboard.totalExpenses, dashboard.totalExpenseCount, dashboard.avgExpense, isDarkMode)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildLoanGivenCard(dashboard.totalLoanGiven, dashboard.loanGiven, dashboard.totalGivenCount, isDarkMode)),
            const SizedBox(width: 12),
            Expanded(child: _buildLoanBorrowedCard(dashboard.totalLoanBorrowed, dashboard.loanBorrowed, dashboard.totalBorrowedCount, isDarkMode)),
          ],
        ),
        const SizedBox(height: 12),
        _buildSavingsCard(dashboard.totalIncome, dashboard.totalExpenses, isDarkMode),
      ],
    );
  }

  Widget _buildIncomeCard(double totalIncome, int count, double avg, bool isDarkMode) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.incomeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_downward, color: AppTheme.incomeColor, size: 20),
              ),
              const SizedBox(width: 8),
              Text('Income', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(Formatters.formatCurrency(totalIncome), style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$count transactions', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(double totalExpenses, int count, double avg, bool isDarkMode) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.expenseColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_upward, color: AppTheme.expenseColor, size: 20),
              ),
              const SizedBox(width: 8),
              Text('Expenses', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(Formatters.formatCurrency(totalExpenses), style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$count transactions', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildLoanGivenCard(double totalLoanGiven, double outstanding, int count, bool isDarkMode) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.loanGivenColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_forward, color: AppTheme.loanGivenColor, size: 20),
              ),
              const SizedBox(width: 8),
              Text('Loan Given', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(Formatters.formatCurrency(totalLoanGiven), style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            outstanding > 0 ? 'Outstanding: ${Formatters.formatCurrency(outstanding)}' : '$count activities',
            style: const TextStyle(color: AppTheme.loanGivenColor, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanBorrowedCard(double totalLoanBorrowed, double outstanding, int count, bool isDarkMode) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.loanBorrowedColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back, color: AppTheme.loanBorrowedColor, size: 20),
              ),
              const SizedBox(width: 8),
              Text('Loan Borrowed', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(Formatters.formatCurrency(totalLoanBorrowed), style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            outstanding > 0 ? 'Outstanding: ${Formatters.formatCurrency(outstanding)}' : '$count activities',
            style: const TextStyle(color: AppTheme.loanBorrowedColor, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard(double totalIncome, double totalExpenses, bool isDarkMode) {
    final netSavings = totalIncome - totalExpenses;
    final savingsRate = totalIncome == 0 ? 0.0 : ((totalIncome - totalExpenses) / totalIncome * 100);
    
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Net Savings', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatCurrency(netSavings),
                  style: TextStyle(
                    color: netSavings >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getSavingsRateColor(savingsRate),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${savingsRate.toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(dashboard, bool isDarkMode) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem(Icons.receipt_long, 'Transactions', dashboard.totalTransactions.toString(), AppTheme.primaryColor, isDarkMode)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatItem(Icons.people, 'Loan Contacts', dashboard.loanContactsCount.toString(), AppTheme.loanGivenColor, isDarkMode)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatItem(Icons.trending_up, 'Expense Ratio', '${(dashboard.totalIncome > 0 ? dashboard.totalExpenses / dashboard.totalIncome : 0).toStringAsFixed(1)}x', dashboard.totalExpenses <= dashboard.totalIncome ? AppTheme.successColor : AppTheme.warningColor, isDarkMode)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatItem(Icons.account_balance, 'Loan Activities', dashboard.totalLoanActivities.toString(), AppTheme.loanBorrowedColor, isDarkMode)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSavingsRateColor(double rate) {
    if (rate >= 20) return AppTheme.successColor;
    if (rate >= 0) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  Widget _buildIncomeExpenseChart(dashboard, bool isDarkMode) {
    final monthlyData = dashboard.monthlyData;
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          const SizedBox(height: 24),
          if (monthlyData.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('No data available', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor))))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < monthlyData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(monthlyData[index].month.substring(5), style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor, fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (monthlyData.length - 1).toDouble(),
                  minY: 0,
                  maxY: _maxY,
                  lineBarsData: _lineChartBars ?? [],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Income', AppTheme.incomeColor, isDarkMode),
              const SizedBox(width: 24),
              _buildLegendItem('Expenses', AppTheme.expenseColor, isDarkMode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoanChart(dashboard, bool isDarkMode) {
    final monthlyData = dashboard.monthlyData;
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Loans Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          const SizedBox(height: 24),
          if (monthlyData.isEmpty || _loanLineChartBars == null)
            Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('No loan data available', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor))))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < monthlyData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(monthlyData[index].month.substring(5), style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor, fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (monthlyData.length - 1).toDouble(),
                  minY: 0,
                  maxY: _loanMaxY > 0 ? _loanMaxY : 100,
                  lineBarsData: _loanLineChartBars ?? [],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Loan Given', AppTheme.loanGivenColor, isDarkMode),
              const SizedBox(width: 24),
              _buildLegendItem('Loan Borrowed', AppTheme.loanBorrowedColor, isDarkMode),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildExpensePieChart(bool isDarkMode) {
    if (_expensePieSections == null || _expensePieSections!.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text('No expense data available', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor))),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expense by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                      if (_touchedPieIndex != -1) {
                        setState(() => _touchedPieIndex = -1);
                      }
                      return;
                    }
                    final newIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    if (_touchedPieIndex != newIndex) {
                      setState(() => _touchedPieIndex = newIndex);
                    }
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: _expensePieSections!,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_expenseCategoryData != null)
            ..._expenseCategoryData!.map((item) => _buildCategoryLegendItem(item['category'] as String, item['amount'] as double, item['color'] as Color, isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildIncomePieChart(bool isDarkMode) {
    if (_incomePieSections == null || _incomePieSections!.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text('No income data available', style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor))),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                      if (_touchedPieIndex != -1) {
                        setState(() => _touchedPieIndex = -1);
                      }
                      return;
                    }
                    final newIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    if (_touchedPieIndex != newIndex) {
                      setState(() => _touchedPieIndex = newIndex);
                    }
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: _incomePieSections!,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_incomeCategoryData != null)
            ..._incomeCategoryData!.map((item) => _buildCategoryLegendItem(item['category'] as String, item['amount'] as double, item['color'] as Color, isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildCategoryLegendItem(String category, double amount, Color color, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(category, style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor, fontSize: 12))),
          Text(Formatters.formatCurrency(amount), style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

