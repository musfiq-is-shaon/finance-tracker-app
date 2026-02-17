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
  static User? _currentUser;

  static Future<SharedPreferences> getPrefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    return _prefs!;
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<bool> isLoggedIn() async {
    final token = _prefs?.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  static Future<String?> getToken() async {
    return _prefs?.getString(_tokenKey);
  }

  static String? getCurrentUserId() {
    return _prefs?.getString(_userIdKey);
  }

  static String? getCurrentUserName() {
    return _prefs?.getString(_userNameKey);
  }

  static Future<User?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;
    final userData = _prefs?.getString(_userKey);
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
      
      await _prefs?.setString(_tokenKey, token);
      await _prefs?.setString(_userIdKey, userId);
      if (userName != null) {
        await _prefs?.setString(_userNameKey, userName);
      }
      
      _currentUser = User(
        id: userId,
        email: email,
        name: userName ?? name,
        createdAt: DateTime.now(),
      );
      await _prefs?.setString(_userKey, jsonEncode(_currentUser!.toJson()));
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
      
      await _prefs?.setString(_tokenKey, token);
      await _prefs?.setString(_userIdKey, userId);
      if (userName != null) {
        await _prefs?.setString(_userNameKey, userName);
      }
      
      _currentUser = User(
        id: userId,
        email: email,
        name: userName,
        createdAt: DateTime.now(),
      );
      await _prefs?.setString(_userKey, jsonEncode(_currentUser!.toJson()));
      return _currentUser!;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> logout() async {
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_userKey);
    await _prefs?.remove(_userIdKey);
    await _prefs?.remove(_userNameKey);
    _currentUser = null;
  }
}

