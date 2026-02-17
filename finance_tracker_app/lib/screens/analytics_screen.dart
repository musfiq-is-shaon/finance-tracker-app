import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
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
  List<PieChartSectionData>? _pieSections;
  List<Widget>? _categoryLegend;
  List<LineChartBarData>? _lineChartBars;
  double _maxY = 0;

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error', style: const TextStyle(color: Colors.white)),
              ElevatedButton(
                onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (dashboard) {
          // Pre-compute line chart data once
          _computeLineChartData(dashboard.monthlyData);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(dashboard),
                const SizedBox(height: 24),
                _buildIncomeExpenseChart(dashboard),
                const SizedBox(height: 24),
                transactionsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (transactions) {
                    // Pre-compute pie chart data once
                    _computePieChartData(transactions);
                    return _buildCategoryPieChart();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _computeLineChartData(List<MonthlyData> monthlyData) {
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

  void _computePieChartData(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      _pieSections = null;
      _categoryLegend = null;
      return;
    }

    final expenseTransactions = transactions.where((t) => t.type == 'expense').toList();
    if (expenseTransactions.isEmpty) {
      _pieSections = null;
      _categoryLegend = null;
      return;
    }

    final categoryTotals = <String, double>{};
    for (var tx in expenseTransactions) {
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;
    }

    final total = categoryTotals.values.fold(0.0, (a, b) => a + b);
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.expenseColor,
      AppTheme.warningColor,
      AppTheme.successColor,
      Colors.purple,
      Colors.pink,
      Colors.teal,
    ];

    _pieSections = sortedCategories.asMap().entries.map((entry) {
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
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    _categoryLegend = sortedCategories.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value.key;
      final amount = entry.value.value;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(category, style: const TextStyle(color: Colors.white)),
            ),
            Text(
              Formatters.formatCurrency(amount),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSummaryCards(DashboardData dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildIncomeCard(dashboard.totalIncome)),
            const SizedBox(width: 12),
            Expanded(child: _buildExpenseCard(dashboard.totalExpenses)),
          ],
        ),
        const SizedBox(height: 12),
        _buildSavingsCard(dashboard.totalIncome, dashboard.totalExpenses),
      ],
    );
  }

  Widget _buildIncomeCard(double totalIncome) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.incomeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_downward, color: AppTheme.incomeColor),
          ),
          const SizedBox(height: 12),
          const Text('Total Income', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(Formatters.formatCurrency(totalIncome), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(double totalExpenses) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.expenseColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_upward, color: AppTheme.expenseColor),
          ),
          const SizedBox(height: 12),
          const Text('Total Expenses', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(Formatters.formatCurrency(totalExpenses), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSavingsCard(double totalIncome, double totalExpenses) {
    final netSavings = totalIncome - totalExpenses;
    final savingsRate = totalIncome == 0 ? 0.0 : ((totalIncome - totalExpenses) / totalIncome * 100);
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Net Savings', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getSavingsRateColor(savingsRate),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${savingsRate.toStringAsFixed(0)}% saved',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
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

  Widget _buildIncomeExpenseChart(DashboardData dashboard) {
    final monthlyData = dashboard.monthlyData;
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Income vs Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          if (monthlyData.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No data available', style: TextStyle(color: Colors.white70))))
          else
            SizedBox(
              height: 200,
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
                              child: Text(monthlyData[index].month.substring(5), style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
              _buildLegendItem('Income', AppTheme.incomeColor),
              const SizedBox(width: 24),
              _buildLegendItem('Expenses', AppTheme.expenseColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildCategoryPieChart() {
    if (_pieSections == null || _pieSections!.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text('No expense data available', style: TextStyle(color: Colors.white.withOpacity(0.7)))),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Expense by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                      if (_touchedPieIndex != -1) {
                        setState(() => _touchedPieIndex = -1);
                        _computePieChartData(ref.read(transactionsProvider).value ?? []);
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
                sections: _pieSections!,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...(_categoryLegend ?? []),
        ],
      ),
    );
  }
}

