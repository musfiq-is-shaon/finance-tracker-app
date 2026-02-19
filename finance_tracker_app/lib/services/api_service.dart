import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class ApiService {
  // Use configurable base URL - update this for your network
  static String get baseUrl => '${Constants.baseUrl}/api';
  
  static Future<Map<String, String>> _getHeaders() async {
    // Ensure prefs is initialized and get the token properly
    await AuthService.init(); // Ensure AuthService is initialized
    final prefs = await AuthService.getPrefs();
    final token = prefs.getString('auth_token');
    
    // Handle null or empty token
    if (token == null || token.isEmpty) {
      return {
        'Content-Type': 'application/json',
      };
    }
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Auth endpoints
  static Future<Map<String, dynamic>> validateToken() async {
    // Add retry logic for network issues
    int maxRetries = 3;
    int retryDelayMs = 500;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final headers = await _getHeaders();
        
        final response = await http.post(
          Uri.parse('$baseUrl/auth/validate'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
        
        // Check for non-JSON responses
        if (response.body.isEmpty) {
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: retryDelayMs));
            continue;
          }
          throw Exception('Empty response from server');
        }
        
        if (response.body.trim().startsWith('<') || response.body.trim().startsWith('<!DOCTYPE')) {
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: retryDelayMs));
            continue;
          }
          throw Exception('Server error: ${response.statusCode} - HTML response');
        }
        
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Token validation failed');
        }
      } catch (e) {
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: retryDelayMs * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Failed to validate token after $maxRetries attempts');
  }

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

  // Loan Contacts endpoints (new person-centric system)
  static Future<List<dynamic>> getLoanContacts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/loan-contacts'),
        headers: await _getHeaders(),
      );
      final data = _handleResponse(response);
      return data['contacts'] as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to get loan contacts: $e');
    }
  }

  static Future<Map<String, dynamic>> createLoanContact(Map<String, dynamic> contact) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/loan-contacts'),
        headers: await _getHeaders(),
        body: jsonEncode(contact),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to create loan contact: $e');
    }
  }

  static Future<Map<String, dynamic>> getLoanContactDetails(String contactId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/loan-contacts/$contactId'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to get loan contact details: $e');
    }
  }

  static Future<Map<String, dynamic>> updateLoanContact(String contactId, Map<String, dynamic> contact) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/loan-contacts/$contactId'),
        headers: await _getHeaders(),
        body: jsonEncode(contact),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to update loan contact: $e');
    }
  }

  static Future<void> deleteLoanContact(String contactId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/loan-contacts/$contactId'),
        headers: await _getHeaders(),
      );
      _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to delete loan contact: $e');
    }
  }

  static Future<Map<String, dynamic>> addLoanActivity(String contactId, Map<String, dynamic> activity) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/loan-contacts/$contactId/activities'),
        headers: await _getHeaders(),
        body: jsonEncode(activity),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to add loan activity: $e');
    }
  }

  static Future<List<dynamic>> getLoanActivities(String contactId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/loan-contacts/$contactId/activities'),
        headers: await _getHeaders(),
      );
      final data = _handleResponse(response);
      return data['activities'] as List<dynamic>;
    } catch (e) {
      throw Exception('Failed to get loan activities: $e');
    }
  }

  static Future<void> deleteLoanActivity(String contactId, String activityId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/loan-contacts/$contactId/activities/$activityId'),
        headers: await _getHeaders(),
      );
      _handleResponse(response);
    } catch (e) {
      throw Exception('Failed to delete loan activity: $e');
    }
  }

  // Dashboard endpoints
  static Future<Map<String, dynamic>> getDashboard() async {
    // Add retry logic for server errors
    int maxRetries = 3;
    int retryDelayMs = 500;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/dashboard'),
          headers: await _getHeaders(),
        ).timeout(const Duration(seconds: 15));
        
        // Check for non-JSON responses
        if (response.body.isEmpty) {
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: retryDelayMs));
            continue;
          }
          throw Exception('Empty response from server');
        }
        
        if (response.body.trim().startsWith('<') || response.body.trim().startsWith('<!DOCTYPE')) {
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: retryDelayMs));
            continue;
          }
          throw Exception('Server error: ${response.statusCode}');
        }
        
        return _handleResponse(response);
      } catch (e) {
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: retryDelayMs * (attempt + 1)));
          continue;
        }
        throw Exception('Failed to get dashboard: $e');
      }
    }
    throw Exception('Failed to get dashboard after $maxRetries attempts');
  }

  // Get balance for validation
  static Future<Map<String, dynamic>> getBalance() async {
    // Add retry logic for server errors
    int maxRetries = 3;
    int retryDelayMs = 500;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/dashboard/balance'),
          headers: await _getHeaders(),
        ).timeout(const Duration(seconds: 15));
        
        // Check for non-JSON responses
        if (response.body.isEmpty) {
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: retryDelayMs));
            continue;
          }
          throw Exception('Empty response from server');
        }
        
        if (response.body.trim().startsWith('<') || response.body.trim().startsWith('<!DOCTYPE')) {
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: retryDelayMs));
            continue;
          }
          throw Exception('Server error: ${response.statusCode}');
        }
        
        return _handleResponse(response);
      } catch (e) {
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: retryDelayMs * (attempt + 1)));
          continue;
        }
        throw Exception('Failed to get balance: $e');
      }
    }
    throw Exception('Failed to get balance after $maxRetries attempts');
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

