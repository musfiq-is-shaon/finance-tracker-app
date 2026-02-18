import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import 'dashboard_provider.dart';
import 'transaction_provider.dart';
import 'loan_provider.dart';

// Use a simple provider that calls the auth service directly each time
final authStateProvider = Provider<bool>((ref) {
  // This will be called each time the provider is read
  // We use sync check for initial state
  return AuthService.isAuthChecked();
});

// Future provider for async auth check
final authCheckProvider = FutureProvider<bool>((ref) async {
  return await AuthService.isLoggedIn();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  
  AuthNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await AuthService.login(email, password);
      // Invalidate auth state to ensure fresh check
      _ref.invalidate(authCheckProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // Rethrow so UI can catch and display error
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await AuthService.signup(name, email, password);
      // Invalidate auth state to ensure fresh check
      _ref.invalidate(authCheckProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // Rethrow so UI can catch and display error
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    // Invalidate auth state to ensure fresh check on next login
    _ref.invalidate(authCheckProvider);
    // Invalidate all data providers to clear cached data for the new user
    _ref.invalidate(balanceProvider);
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(transactionsProvider);
    _ref.invalidate(loansProvider);
    state = const AsyncValue.data(null);
  }
}

