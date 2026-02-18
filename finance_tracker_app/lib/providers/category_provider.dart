import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';

// Keys for SharedPreferences
const String _incomeCategoriesKey = 'custom_income_categories';
const String _expenseCategoriesKey = 'custom_expense_categories';

class CategoryNotifier extends StateNotifier<List<String>> {
  final SharedPreferences? _prefs;
  final String _key;
  final List<String> _defaultCategories;

  CategoryNotifier(this._prefs, this._key, this._defaultCategories) 
      : super(_defaultCategories) {
    _loadCategories();
  }

  void _loadCategories() {
    if (_prefs != null) {
      final saved = _prefs!.getStringList(_key);
      if (saved != null && saved.isNotEmpty) {
        state = [..._defaultCategories, ...saved];
      }
    }
  }

  Future<void> addCategory(String category) async {
    if (!state.contains(category)) {
      state = [...state, category];
      // Save custom categories (excluding defaults)
      final customCategories = state.where((c) => !_defaultCategories.contains(c)).toList();
      await _prefs?.setStringList(_key, customCategories);
    }
  }

  Future<void> removeCategory(String category) async {
    // Don't allow removing default categories
    if (_defaultCategories.contains(category)) return;
    
    state = state.where((c) => c != category).toList();
    // Save custom categories
    final customCategories = state.where((c) => !_defaultCategories.contains(c)).toList();
    await _prefs?.setStringList(_key, customCategories);
  }

  bool isCustomCategory(String category) {
    return !_defaultCategories.contains(category);
  }
}

// Default categories
const List<String> defaultIncomeCategories = [
  'Salary',
  'Business',
  'Investment',
  'Gift',
  'Other',
];

const List<String> defaultExpenseCategories = [
  'Food',
  'Transport',
  'Shopping',
  'Entertainment',
  'Bills',
  'Health',
  'Education',
  'Other',
];

// Providers for custom categories
final incomeCategoriesProvider = StateNotifierProvider<CategoryNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CategoryNotifier(prefs, _incomeCategoriesKey, defaultIncomeCategories);
});

final expenseCategoriesProvider = StateNotifierProvider<CategoryNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CategoryNotifier(prefs, _expenseCategoriesKey, defaultExpenseCategories);
});

