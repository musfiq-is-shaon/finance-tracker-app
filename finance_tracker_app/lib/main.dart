import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize AuthService first
  await AuthService.init();
  
  // Run the app with a provider scope
  runApp(const ProviderScope(child: FinanceTrackerApp()));
}

class FinanceTrackerApp extends ConsumerStatefulWidget {
  const FinanceTrackerApp({super.key});

  @override
  ConsumerState<FinanceTrackerApp> createState() => _FinanceTrackerAppState();
}

class _FinanceTrackerAppState extends ConsumerState<FinanceTrackerApp> {
  bool _isAuthInitialized = false;
  bool _isAuthValid = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Disable auto login - always require manual login
    // Set auth as initialized but not valid (force login screen)
    if (mounted) {
      setState(() {
        _isAuthInitialized = true;
        _isAuthValid = false;
      });
      
      // Always navigate to login screen
      ref.read(routerProvider).go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // If auth is not yet initialized, show splash
    if (!_isAuthInitialized) {
      return MaterialApp(
        title: 'Finance Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _SplashScreen(),
      );
    }

    // After auth is initialized, use router
    return MaterialApp.router(
      title: 'Finance Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

// Simple splash screen widget for initial loading
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Finance Tracker',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

