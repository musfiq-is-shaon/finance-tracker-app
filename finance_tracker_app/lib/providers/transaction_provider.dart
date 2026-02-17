import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/transaction.dart';

final transactionsProvider = StateNotifierProvider<TransactionsNotifier, AsyncValue<List<Transaction>>>((ref) {
  return TransactionsNotifier();
});

class TransactionsNotifier extends StateNotifier<AsyncValue<List<Transaction>>> {
  TransactionsNotifier() : super(const AsyncValue.loading()) {
    loadTransactions();
  }

  Future<void> loadTransactions({String? category, DateTime? startDate, DateTime? endDate}) async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiService.getTransactions(
        category: category,
        startDate: startDate,
        endDate: endDate,
      );
      final transactions = (data).map((t) => Transaction.fromJson(t as Map<String, dynamic>)).toList();
      state = AsyncValue.data(transactions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTransaction({
    required String type,
    required double amount,
    required String category,
    required String description,
    required DateTime date,
  }) async {
    try {
      await ApiService.addTransaction({
        'type': type,
        'amount': amount,
        'category': category,
        'description': description,
        'date': date.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
      await loadTransactions();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTransaction(String id, Map<String, dynamic> data) async {
    try {
      await ApiService.updateTransaction(id, data);
      await loadTransactions();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await ApiService.deleteTransaction(id);
      await loadTransactions();
    } catch (e) {
      rethrow;
    }
  }
}

