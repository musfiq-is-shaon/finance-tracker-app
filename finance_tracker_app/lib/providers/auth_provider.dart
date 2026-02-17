import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authStateProvider = FutureProvider<bool>((ref) async {
  return await AuthService.isLoggedIn();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncValue.data(null));

  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await AuthService.login(email, password);
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
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow; // Rethrow so UI can catch and display error
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = const AsyncValue.data(null);
  }
}

