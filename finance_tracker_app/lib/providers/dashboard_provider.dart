import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

class DashboardData {
  final double totalBalance;
  final double totalIncome;
  final double totalExpenses;
  final double loanGiven;
  final double loanBorrowed;
  final double totalLoanGiven;
  final double totalLoanBorrowed;
  final List<MonthlyData> monthlyData;
  final List<dynamic> recentTransactions;
  // Additional analytics data
  final Map<String, double> expenseByCategory;
  final Map<String, double> incomeByCategory;
  final int loanContactsCount;
  final int totalTransactions;
  final int totalIncomeCount;
  final int totalExpenseCount;
  final double avgIncome;
  final double avgExpense;
  final int totalLoanActivities;
  final int totalGivenCount;
  final int totalBorrowedCount;

  DashboardData({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpenses,
    required this.loanGiven,
    required this.loanBorrowed,
    required this.totalLoanGiven,
    required this.totalLoanBorrowed,
    required this.monthlyData,
    required this.recentTransactions,
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.loanContactsCount,
    required this.totalTransactions,
    required this.totalIncomeCount,
    required this.totalExpenseCount,
    required this.avgIncome,
    required this.avgExpense,
    required this.totalLoanActivities,
    required this.totalGivenCount,
    required this.totalBorrowedCount,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalBalance: (json['total_balance'] as num?)?.toDouble() ?? 0.0,
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0.0,
      loanGiven: (json['loan_given'] as num?)?.toDouble() ?? 0.0,
      loanBorrowed: (json['loan_borrowed'] as num?)?.toDouble() ?? 0.0,
      totalLoanGiven: (json['total_loan_given'] as num?)?.toDouble() ?? 0.0,
      totalLoanBorrowed: (json['total_loan_borrowed'] as num?)?.toDouble() ?? 0.0,
      monthlyData: (json['monthly_data'] as List<dynamic>?)
          ?.map((m) => MonthlyData.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      recentTransactions: json['recent_transactions'] as List<dynamic>? ?? [],
      expenseByCategory: (json['expense_by_category'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      incomeByCategory: (json['income_by_category'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      loanContactsCount: (json['loan_contacts_count'] as num?)?.toInt() ?? 0,
      totalTransactions: (json['total_transactions'] as num?)?.toInt() ?? 0,
      totalIncomeCount: (json['total_income_count'] as num?)?.toInt() ?? 0,
      totalExpenseCount: (json['total_expense_count'] as num?)?.toInt() ?? 0,
      avgIncome: (json['avg_income'] as num?)?.toDouble() ?? 0.0,
      avgExpense: (json['avg_expense'] as num?)?.toDouble() ?? 0.0,
      totalLoanActivities: (json['total_loan_activities'] as num?)?.toInt() ?? 0,
      totalGivenCount: (json['total_given_count'] as num?)?.toInt() ?? 0,
      totalBorrowedCount: (json['total_borrowed_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class MonthlyData {
  final String month;
  final double income;
  final double expense;
  final double loanGiven;
  final double loanBorrowed;

  MonthlyData({
    required this.month,
    required this.income,
    required this.expense,
    required this.loanGiven,
    required this.loanBorrowed,
  });

  factory MonthlyData.fromJson(Map<String, dynamic> json) {
    return MonthlyData(
      month: json['month'] as String,
      income: (json['income'] as num?)?.toDouble() ?? 0.0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
      loanGiven: (json['loan_given'] as num?)?.toDouble() ?? 0.0,
      loanBorrowed: (json['loan_borrowed'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, AsyncValue<DashboardData>>((ref) {
  return DashboardNotifier();
});

// Provider to get current balance for validation
final balanceProvider = StateNotifierProvider<BalanceNotifier, AsyncValue<double>>((ref) {
  return BalanceNotifier();
});

class BalanceNotifier extends StateNotifier<AsyncValue<double>> {
  BalanceNotifier() : super(const AsyncValue.data(0.0)) {
    // Auto-load balance on initialization
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiService.getBalance();
      final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
      state = AsyncValue.data(balance);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateBalance(double balance) {
    state = AsyncValue.data(balance);
  }
}

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardData>> {
  DashboardNotifier() : super(AsyncValue.data(DashboardData(
    totalBalance: 0,
    totalIncome: 0,
    totalExpenses: 0,
    loanGiven: 0,
    loanBorrowed: 0,
    totalLoanGiven: 0,
    totalLoanBorrowed: 0,
    monthlyData: [],
    recentTransactions: [],
    expenseByCategory: {},
    incomeByCategory: {},
    loanContactsCount: 0,
    totalTransactions: 0,
    totalIncomeCount: 0,
    totalExpenseCount: 0,
    avgIncome: 0,
    avgExpense: 0,
    totalLoanActivities: 0,
    totalGivenCount: 0,
    totalBorrowedCount: 0,
  )));

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

