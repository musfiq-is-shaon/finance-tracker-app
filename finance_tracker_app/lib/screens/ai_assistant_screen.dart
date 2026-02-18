import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class AIAssistantScreen extends ConsumerStatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  ConsumerState<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends ConsumerState<AIAssistantScreen> {
  bool _isLoading = false;
  String? _advice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _getAIAdvice();
  }

  Future<void> _getAIAdvice() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getAIAdvice();
      setState(() {
        _advice = response['advice'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        title: Text('AI Financial Assistant', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.smart_toy,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Financial Advisor',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI-powered insights for your finances',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Analyzing your finances...',
                      style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
                    ),
                  ],
                ),
              )
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to get advice',
                      style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _getAIAdvice,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_advice != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Financial Insights',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lightbulb, color: AppTheme.warningColor),
                            const SizedBox(width: 8),
                            Text(
                              'Advice',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _advice!,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tips for Better Finances',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTipCard(
                    icon: Icons.savings,
                    title: 'Track Every Expense',
                    description: 'Keep track of all your expenses to understand your spending patterns.',
                    isDarkMode: isDarkMode,
                  ),
                  _buildTipCard(
                    icon: Icons.account_balance_wallet,
                    title: 'Set a Budget',
                    description: 'Create a monthly budget and stick to it for better financial health.',
                    isDarkMode: isDarkMode,
                  ),
                  _buildTipCard(
                    icon: Icons.trending_up,
                    title: 'Save Regularly',
                    description: 'Aim to save at least 20% of your income each month.',
                    isDarkMode: isDarkMode,
                  ),
                  _buildTipCard(
                    icon: Icons.insights,
                    title: 'Review Monthly',
                    description: 'Review your finances monthly to stay on track with your goals.',
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _getAIAdvice,
                icon: const Icon(Icons.refresh),
                label: const Text('Get New Advice'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isDarkMode,
  }) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

