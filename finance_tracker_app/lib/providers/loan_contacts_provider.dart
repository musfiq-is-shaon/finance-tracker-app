import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/loan_contact.dart';
import '../models/loan_activity.dart';

// Provider for loan contacts list
final loanContactsProvider = StateNotifierProvider<LoanContactsNotifier, AsyncValue<List<LoanContact>>>((ref) {
  return LoanContactsNotifier();
});

class LoanContactsNotifier extends StateNotifier<AsyncValue<List<LoanContact>>> {
  LoanContactsNotifier() : super(const AsyncValue.data([]));

  Future<void> loadContacts() async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiService.getLoanContacts();
      final contacts = data.map((c) => LoanContact.fromJson(c as Map<String, dynamic>)).toList();
      state = AsyncValue.data(contacts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<LoanContact?> createContact({
    required String name,
    String? phoneNumber,
    String? email,
    String? notes,
    double initialBalance = 0,
  }) async {
    try {
      final result = await ApiService.createLoanContact({
        'name': name,
        'phone_number': phoneNumber,
        'email': email,
        'notes': notes,
        'initial_balance': initialBalance,
      });
      await loadContacts();
      return LoanContact.fromJson(result['contact'] as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateContact(String id, Map<String, dynamic> data) async {
    try {
      await ApiService.updateLoanContact(id, data);
      await loadContacts();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      await ApiService.deleteLoanContact(id);
      await loadContacts();
    } catch (e) {
      rethrow;
    }
  }
}

// Provider for single contact details with activities
final loanContactDetailsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, contactId) async {
  final data = await ApiService.getLoanContactDetails(contactId);
  return data;
});

// Provider for loan contact activities
final loanActivitiesProvider = FutureProvider.family<List<LoanActivity>, String>((ref, contactId) async {
  final data = await ApiService.getLoanActivities(contactId);
  return data.map((a) => LoanActivity.fromJson(a as Map<String, dynamic>)).toList();
});

// Notifier for adding activities to a contact
class LoanActivityNotifier extends StateNotifier<AsyncValue<void>> {
  LoanActivityNotifier() : super(const AsyncValue.data(null));

  Future<void> addActivity({
    required String contactId,
    required String activityType,
    required double amount,
    String? description,
    DateTime? activityDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.addLoanActivity(contactId, {
        'activity_type': activityType,
        'amount': amount,
        'description': description,
        'activity_date': activityDate?.toIso8601String().split('T')[0] ?? DateTime.now().toIso8601String().split('T')[0],
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteActivity(String contactId, String activityId) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.deleteLoanActivity(contactId, activityId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final loanActivityProvider = StateNotifierProvider<LoanActivityNotifier, AsyncValue<void>>((ref) {
  return LoanActivityNotifier();
});

// Summary providers
final totalLoansGivenProvider = Provider<double>((ref) {
  final contactsAsync = ref.watch(loanContactsProvider);
  return contactsAsync.maybeWhen(
    data: (contacts) => contacts
        .where((c) => c.currentBalance > 0)
        .fold(0.0, (sum, c) => sum + c.currentBalance),
    orElse: () => 0.0,
  );
});

final totalLoansBorrowedProvider = Provider<double>((ref) {
  final contactsAsync = ref.watch(loanContactsProvider);
  return contactsAsync.maybeWhen(
    data: (contacts) => contacts
        .where((c) => c.currentBalance < 0)
        .fold(0.0, (sum, c) => sum + c.currentBalance.abs()),
    orElse: () => 0.0,
  );
});

final loanContactsCountProvider = Provider<int>((ref) {
  final contactsAsync = ref.watch(loanContactsProvider);
  return contactsAsync.maybeWhen(
    data: (contacts) => contacts.length,
    orElse: () => 0,
  );
});

