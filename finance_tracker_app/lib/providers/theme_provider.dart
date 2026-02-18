import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme state notifier
class ThemeNotifier extends StateNotifier<bool> {
  static const String _themeKey = 'is_dark_mode';
  final SharedPreferences? _prefs;
  
  ThemeNotifier(this._prefs) : super(true) {
    _loadTheme();
  }
  
  void _loadTheme() {
    if (_prefs != null) {
      state = _prefs!.getBool(_themeKey) ?? true;
    }
  }
  
  Future<void> toggleTheme() async {
    state = !state;
    if (_prefs != null) {
      await _prefs!.setBool(_themeKey, state);
    }
  }
  
  Future<void> setDarkMode(bool isDark) async {
    state = isDark;
    if (_prefs != null) {
      await _prefs!.setBool(_themeKey, state);
    }
  }
}

// Provider for SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

// Provider for theme state (true = dark mode, false = light mode)
final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});

