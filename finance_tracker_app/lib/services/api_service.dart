import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class ApiService {
  // Use configurable base URL - update this for your network
  static String get baseUrl => '${Constants.baseUrl}/api';
  
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await AuthService.getPrefs();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Auth endpoints
  static Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to signup: $e');
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  // Transaction endpoints
  static Future<List<dynamic>> getTransactions({String? category, DateTime? startDate, DateTime? endDate}) async {
    try {
      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;
      if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();
      
      final uri = Uri.parse('$baseUrl/transactions').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: await _getHeaders());
      final data = _handleResponse(response);
      return data['transactions'] as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to get transactions: $e');
    }
  }

  static Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> transaction) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transactions'),
        headers: await _getHeaders(),
        body: jsonEncode(transaction),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to add transaction: $e');
    }
  }

  static Future<Map<String, dynamic>> updateTransaction(String id, Map<String, dynamic> transaction) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/transactions/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(transaction),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
    }
  }

  static Future<void> deleteTransaction(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/transactions/$id'),
        headers: await _getHeaders(),
      );
      _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // Loan endpoints
  static Future<List<dynamic>> getLoans() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/loans'),
        headers: await _getHeaders(),
      );
      final data = _handleResponse(response);
      return data['loans'] as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to get loans: $e');
    }
  }

  static Future<Map<String, dynamic>> addLoan(Map<String, dynamic> loan) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/loans'),
        headers: await _getHeaders(),
        body: jsonEncode(loan),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to add loan: $e');
    }
  }

  static Future<Map<String, dynamic>> updateLoan(String id, Map<String, dynamic> loan) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/loans/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(loan),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to update loan: $e');
    }
  }

  static Future<void> deleteLoan(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/loans/$id'),
        headers: await _getHeaders(),
      );
      _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to delete loan: $e');
    }
  }

  // Dashboard endpoints
  static Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to get dashboard: $e');
    }
  }

  // AI endpoints
  static Future<Map<String, dynamic>> getAIAdvice() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/advice'),
        headers: await _getHeaders(),
        body: jsonEncode({}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to get AI advice: $e');
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    // Check if response is empty
    if (response.body.isEmpty) {
      throw Exception('Empty response from server');
    }
    
    // Check if response is HTML (error page) instead of JSON
    if (response.body.trim().startsWith('<') || response.body.trim().startsWith('<!DOCTYPE')) {
      throw Exception('Server error: ${response.statusCode}');
    }
    
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Request failed');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to parse response: $e');
    }
  }
}

