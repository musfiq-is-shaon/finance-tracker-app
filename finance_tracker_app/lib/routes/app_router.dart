import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/add_transaction_screen.dart';
import '../screens/transaction_history_screen.dart';
import '../screens/add_loan_screen.dart';
import '../screens/loan_list_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/ai_assistant_screen.dart';
import '../services/auth_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final isAuthRoute = state.matchedLocation == '/login' || 
                          state.matchedLocation == '/signup' ||
                          state.matchedLocation == '/';
      
      if (isAuthRoute) {
        return null;
      }
      
      // For protected routes, check if user has a token
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        return '/login';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/add-transaction',
        builder: (context, state) {
          final type = state.extra as String?;
          return AddTransactionScreen(transactionType: type);
        },
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/add-loan',
        builder: (context, state) {
          final type = state.extra as String?;
          return AddLoanScreen(loanType: type);
        },
      ),
      GoRoute(
        path: '/loans',
        builder: (context, state) => const LoanListScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/ai-assistant',
        builder: (context, state) => const AIAssistantScreen(),
      ),
    ],
  );
});

