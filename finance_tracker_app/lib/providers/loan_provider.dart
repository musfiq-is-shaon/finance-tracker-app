import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/loan.dart';

final loansProvider = StateNotifierProvider<LoansNotifier, AsyncValue<List<Loan>>>((ref) {
  return LoansNotifier();
});

class LoansNotifier extends StateNotifier<AsyncValue<List<Loan>>> {
  LoansNotifier() : super(const AsyncValue.data([]));

  Future<void> loadLoans() async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiService.getLoans();
      final loans = (data).map((l) => Loan.fromJson(l as Map<String, dynamic>)).toList();
      state = AsyncValue.data(loans);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addLoan({
    required String type,
    required String personName,
    String? phoneNumber,
    required double amount,
    String? description,
    required DateTime date,
  }) async {
    try {
      await ApiService.addLoan({
        'type': type,
        'person_name': personName,
        'phone_number': phoneNumber,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String(),
        'is_paid': false,
        'paid_amount': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      await loadLoans();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateLoan(String id, Map<String, dynamic> data) async {
    try {
      await ApiService.updateLoan(id, data);
      await loadLoans();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> markAsPaid(String id, double paidAmount) async {
    try {
      await ApiService.updateLoan(id, {
        'paid_amount': paidAmount,
        'is_paid': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await loadLoans();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteLoan(String id) async {
    try {
      await ApiService.deleteLoan(id);
      await loadLoans();
    } catch (e) {
      rethrow;
    }
  }
}

