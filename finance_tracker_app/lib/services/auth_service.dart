import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/user.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  
  static SharedPreferences? _prefs;
  static bool _isInitialized = false;
  static bool _isAuthChecked = false; // Track if auth check is complete
  static User? _currentUser;

  static Future<SharedPreferences> getPrefs() async {
    if (_prefs == null || !_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    }
    return _prefs!;
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  /// Check if auth initialization check is complete
  static bool isAuthChecked() {
    return _isAuthChecked;
  }

  /// Wait for auth check to complete and trigger it if not started
  static Future<bool> waitForAuthCheck() async {
    // If auth is already checked, return immediately
    if (_isAuthChecked) {
      return true;
    }
    
    // Initialize SharedPreferences if needed first
    await init();
    
    // Now trigger the auth check
    return await isLoggedIn();
  }
  
  static Future<bool> isLoggedIn() async {
    // First check if token exists locally
    final prefs = await getPrefs();
    final token = prefs.getString(_tokenKey);
    
    if (token == null || token.isEmpty) {
      _isAuthChecked = true;
      return false;
    }
    
    // Validate token with backend to ensure it's still valid
    try {
      final response = await ApiService.validateToken();
      
      if (response['valid'] == true) {
        // Token is valid, update user info from server response
        final userId = response['user_id'] as String?;
        final userName = response['name'] as String?;
        
        if (userId != null) {
          await prefs.setString(_userIdKey, userId);
        }
        if (userName != null) {
          await prefs.setString(_userNameKey, userName);
        }
        
        // Also update stored user data if needed
        final currentUser = await getCurrentUser();
        if (currentUser != null) {
          final updatedUser = User(
            id: userId ?? currentUser.id,
            email: currentUser.email,
            name: userName ?? currentUser.name,
            createdAt: currentUser.createdAt,
          );
          _currentUser = updatedUser;
          await prefs.setString(_userKey, jsonEncode(updatedUser.toJson()));
        }
        
        _isAuthChecked = true;
        return true;
      } else {
        // Token is invalid/expired, clear local storage
        await logout();
        _isAuthChecked = true;
        return false;
      }
    } catch (e) {
      // Network error - try to use cached token, but let the dashboard handle errors
      // This allows the app to work when server is temporarily unavailable
      // We'll let the first API call determine if the token is actually valid
      _isAuthChecked = true;
      return true;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await getPrefs();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getUserId() async {
    final prefs = await getPrefs();
    return prefs.getString(_userIdKey);
  }

  static String? getCurrentUserId() {
    return _prefs?.getString(_userIdKey);
  }

  static String? getCurrentUserName() {
    return _prefs?.getString(_userNameKey);
  }

  static Future<User?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;
    final prefs = await getPrefs();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(userData);
        _currentUser = User.fromJson(json);
        return _currentUser;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<User> signup(String name, String email, String password) async {
    try {
      final response = await ApiService.signup(name, email, password);
      final token = response['token'] as String;
      final userId = response['user_id'] as String;
      final userName = response['name'] as String?;
      
      final prefs = await getPrefs();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userIdKey, userId);
      if (userName != null) {
        await prefs.setString(_userNameKey, userName);
      }
      
      _currentUser = User(
        id: userId,
        email: email,
        name: userName ?? name,
        createdAt: DateTime.now(),
      );
      await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
      _isAuthChecked = true; // Mark auth as checked after successful signup
      return _currentUser!;
    } catch (e) {
      rethrow;
    }
  }

  static Future<User> login(String email, String password) async {
    try {
      final response = await ApiService.login(email, password);
      final token = response['token'] as String;
      final userId = response['user_id'] as String;
      final userName = response['name'] as String?;
      
      final prefs = await getPrefs();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userIdKey, userId);
      if (userName != null) {
        await prefs.setString(_userNameKey, userName);
      }
      
      _currentUser = User(
        id: userId,
        email: email,
        name: userName,
        createdAt: DateTime.now(),
      );
      await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
      _isAuthChecked = true; // Mark auth as checked after successful login
      return _currentUser!;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> logout() async {
    final prefs = await getPrefs();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    _currentUser = null;
    _isAuthChecked = false; // Reset auth check flag for next login
  }
}

