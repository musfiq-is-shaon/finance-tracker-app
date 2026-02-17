import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class DashboardData {
  final double totalBalance;
  final double totalIncome;
  final double totalExpenses;
  final double loanGiven;
  final double loanBorrowed;
  final List<MonthlyData> monthlyData;
  final List<dynamic> recentTransactions;

  DashboardData({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpenses,
    required this.loanGiven,
    required this.loanBorrowed,
    required this.monthlyData,
    required this.recentTransactions,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalBalance: (json['total_balance'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0.0,
      loanGiven: (json['loan_given'] as num?)?.toDouble() ?? 0.0,
      loanBorrowed: (json['loan_borrowed'] as num?)?.toDouble() ?? 0.0,
      monthlyData: (json['monthly_data'] as List<dynamic>?)
          ?.map((m) => MonthlyData.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      recentTransactions: json['recent_transactions'] as List<dynamic>? ?? [],
    );
  }
}

class MonthlyData {
  final String month;
  final double income;
  final double expense;

  MonthlyData({
    required this.month,
    required this.income,
    required this.expense,
  });

  factory MonthlyData.fromJson(Map<String, dynamic> json) {
    return MonthlyData(
      month: json['month'] as String,
      income: (json['income'] as num?)?.toDouble() ?? 0.0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, AsyncValue<DashboardData>>((ref) {
  return DashboardNotifier();
});

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardData>> {
  DashboardNotifier() : super(const AsyncValue.loading()) {
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiService.getDashboard();
      state = AsyncValue.data(DashboardData.fromJson(data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await loadDashboard();
  }
}

